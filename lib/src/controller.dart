import 'dart:async';
import 'dart:collection';
import 'dart:math';

import 'package:flutter/foundation.dart';

import 'models.dart';
import 'progress_repository.dart';
import 'spider_engine.dart';

class SpiderController extends ChangeNotifier {
  SpiderController(this._repository);

  final ProgressRepository _repository;
  final Random _random = Random();
  final List<SpiderGameState> _undoStack = <SpiderGameState>[];
  final Queue<AchievementDefinition> _pendingAchievements =
      Queue<AchievementDefinition>();

  SpiderGameState? _state;
  PlayerProgress _progress = PlayerProgress.initial();
  SpiderSelection? _selection;
  MoveHint? _hint;
  Timer? _timer;
  Timer? _hintTimer;
  bool _isReady = false;
  String _statusMessage = '点击自动落位，长按手动选牌。';
  int _hintPulseToken = 0;

  bool get isReady => _isReady;
  SpiderGameState get state => _state!;
  PlayerProgress get progress => _progress;
  SpiderSelection? get selection => _selection;
  MoveHint? get hint => _hint;
  String get statusMessage => _statusMessage;
  int get hintPulseToken => _hintPulseToken;
  bool get canUndo => _undoStack.isNotEmpty;
  bool get canDeal => SpiderEngine.canDealFromStock(state);
  bool get hasPendingAchievement => _pendingAchievements.isNotEmpty;

  Future<void> initialize() async {
    _progress = await _repository.loadProgress();
    final savedGame = await _repository.loadSavedGame();

    if (savedGame != null) {
      _state = savedGame;
      _setStatus('已恢复上次牌局。点击自动落位，长按手动选牌。');
    } else {
      _state = SpiderEngine.newGame(
        _progress.preferredDifficulty,
        random: _random,
      );
      _progress = _progress.copyWith(gamesStarted: _progress.gamesStarted + 1);
      await _repository.saveProgress(_progress);
      await _repository.saveGame(_state);
      _setStatus('新牌局已展开。点击牌会优先寻找同花色落点。');
    }

    _isReady = true;
    _startTimer();
    notifyListeners();
  }

  AchievementDefinition? consumeAchievement() {
    if (_pendingAchievements.isEmpty) {
      return null;
    }
    return _pendingAchievements.removeFirst();
  }

  Future<void> startNewGame(SpiderDifficulty difficulty) async {
    if (!_isReady) {
      return;
    }

    var nextProgress = _progress.copyWith(
      preferredDifficulty: difficulty,
      gamesStarted: _progress.gamesStarted + 1,
    );

    if (!state.isWin && state.moves > 0) {
      nextProgress = nextProgress.copyWith(winStreak: 0);
    }

    _progress = nextProgress;
    _state = SpiderEngine.newGame(difficulty, random: _random);
    _undoStack.clear();
    _selection = null;
    _clearHint();
    _setStatus('已切换到 ${difficulty.label}。点击自动落位，长按手动选牌。');

    await _repository.saveProgress(_progress);
    await _repository.saveGame(_state);
    notifyListeners();
  }

  void onCardTapped(int columnIndex, int cardIndex) {
    if (!_isReady) {
      return;
    }

    if (_selection == null) {
      if (SpiderEngine.canSelectStack(state, columnIndex, cardIndex)) {
        final autoMove = SpiderEngine.bestAutoMove(
          state,
          columnIndex,
          cardIndex,
        );
        if (autoMove != null) {
          unawaited(
            _applyMoveHint(
              autoMove,
              baseStatus: _describeMoveHint(autoMove, auto: true),
            ),
          );
          return;
        }

        _selection = SpiderSelection(column: columnIndex, index: cardIndex);
        _clearHint();
        _setStatus(
          '已手动锁定 ${state.tableau[columnIndex][cardIndex].spokenLabel} 起的一叠牌。',
        );
        notifyListeners();
      }
      return;
    }

    final currentSelection = _selection!;
    if (currentSelection.column == columnIndex &&
        currentSelection.index == cardIndex) {
      _selection = null;
      _setStatus('已取消手动选牌。');
      notifyListeners();
      return;
    }

    if (_tryMoveTo(columnIndex)) {
      return;
    }

    if (SpiderEngine.canSelectStack(state, columnIndex, cardIndex)) {
      _selection = SpiderSelection(column: columnIndex, index: cardIndex);
      _clearHint();
      _setStatus(
        '已切换为 ${state.tableau[columnIndex][cardIndex].spokenLabel} 起的一叠牌。',
      );
      notifyListeners();
    }
  }

  void onCardLongPressed(int columnIndex, int cardIndex) {
    if (!_isReady ||
        !SpiderEngine.canSelectStack(state, columnIndex, cardIndex)) {
      return;
    }

    final currentSelection = _selection;
    if (currentSelection?.column == columnIndex &&
        currentSelection?.index == cardIndex) {
      _selection = null;
      _setStatus('已取消手动选牌。');
      notifyListeners();
      return;
    }

    _selection = SpiderSelection(column: columnIndex, index: cardIndex);
    _clearHint();
    _setStatus(
      '长按进入手动模式：${state.tableau[columnIndex][cardIndex].spokenLabel}。',
    );
    notifyListeners();
  }

  void onColumnTapped(int columnIndex) {
    if (_selection == null) {
      return;
    }
    _tryMoveTo(columnIndex);
  }

  Future<void> dealFromStock() async {
    if (!_isReady) {
      return;
    }

    final next = SpiderEngine.dealFromStock(state);
    if (next == null) {
      if (state.stockDealsRemaining == 0) {
        _setStatus('库存牌已经发完了。');
      } else if (state.tableau.any((column) => column.isEmpty)) {
        _setStatus('先把空列填满，才能从库存发牌。');
      } else {
        _setStatus('当前无法从库存发牌。');
      }
      notifyListeners();
      return;
    }

    await _applyStateMutation(next, previous: state, baseStatus: '从库存补入一轮新牌。');
  }

  Future<void> undo() async {
    if (_undoStack.isEmpty) {
      return;
    }

    final snapshot = _undoStack.removeLast();
    _state = snapshot.copyWith(
      undoCount: state.undoCount + 1,
      elapsedSeconds: state.elapsedSeconds,
    );
    _selection = null;
    _clearHint();
    _setStatus('已撤销上一步。');
    await _repository.saveGame(_state);
    notifyListeners();
  }

  Future<void> requestHint() async {
    if (!_isReady) {
      return;
    }

    final nextHint = SpiderEngine.findHint(state);
    if (nextHint == null) {
      _clearHint();
      _setStatus('暂时没有更优移动，先观察暗牌和空列。');
      notifyListeners();
      return;
    }

    _hint = nextHint;
    _hintPulseToken++;
    _armHintTimer();
    _state = state.copyWith(hintsUsed: state.hintsUsed + 1);
    _setStatus(_describeHint(nextHint));
    await _repository.saveGame(_state);
    notifyListeners();
  }

  bool _tryMoveTo(int targetColumn) {
    final currentSelection = _selection;
    if (currentSelection == null) {
      return false;
    }

    final next = SpiderEngine.moveStack(
      state,
      currentSelection.column,
      currentSelection.index,
      targetColumn,
    );
    if (next == null) {
      return false;
    }

    final previous = state;
    unawaited(
      _applyStateMutation(
        next,
        previous: previous,
        baseStatus: _describeMoveHint(
          MoveHint.move(
            fromColumn: currentSelection.column,
            fromIndex: currentSelection.index,
            toColumn: targetColumn,
          ),
        ),
      ),
    );
    return true;
  }

  void _pushUndo() {
    _undoStack.add(state);
    if (_undoStack.length > 100) {
      _undoStack.removeAt(0);
    }
  }

  Future<void> _applyMoveHint(
    MoveHint hint, {
    required String baseStatus,
  }) async {
    if (!hint.isMove) {
      return;
    }

    final next = SpiderEngine.moveStack(
      state,
      hint.fromColumn!,
      hint.fromIndex!,
      hint.toColumn!,
    );
    if (next == null) {
      return;
    }

    await _applyStateMutation(next, previous: state, baseStatus: baseStatus);
  }

  Future<void> _applyStateMutation(
    SpiderGameState next, {
    required SpiderGameState previous,
    required String baseStatus,
  }) async {
    _pushUndo();
    _state = next;
    _selection = null;
    _clearHint();
    _setStatus(_decorateStatus(previous, next, baseStatus));
    notifyListeners();
    await _persistAfterMutation();
  }

  String _decorateStatus(
    SpiderGameState previous,
    SpiderGameState next,
    String baseStatus,
  ) {
    final notes = <String>[baseStatus];

    if (next.completedRuns > previous.completedRuns) {
      notes.add('完整顺子已自动收束');
    }

    if (next.hiddenCardsRevealed > previous.hiddenCardsRevealed) {
      notes.add('翻开了一张暗牌');
    }

    return notes.join(' · ');
  }

  String _describeMoveHint(MoveHint hint, {bool auto = false}) {
    final movingCard = state.tableau[hint.fromColumn!][hint.fromIndex!];
    final targetColumn = state.tableau[hint.toColumn!];
    final prefix = auto ? '自动落位' : '已移动';

    if (targetColumn.isEmpty) {
      return '$prefix：${movingCard.spokenLabel} 移入空列。';
    }

    final targetCard = targetColumn.last;
    if (targetCard.suit == movingCard.suit) {
      return '$prefix：${movingCard.spokenLabel} 接到 ${targetCard.spokenLabel} 下，保留同花色。';
    }

    return '$prefix：${movingCard.spokenLabel} 接到 ${targetCard.spokenLabel} 下。';
  }

  String _describeHint(MoveHint hint) {
    if (hint.isDeal) {
      return '提示：现在适合从库存再发一轮。';
    }

    final movingCard = state.tableau[hint.fromColumn!][hint.fromIndex!];
    final targetColumn = state.tableau[hint.toColumn!];

    if (targetColumn.isEmpty) {
      return '提示：把 ${movingCard.spokenLabel} 移到空列，先腾出空间。';
    }

    final targetCard = targetColumn.last;
    if (targetCard.suit == movingCard.suit) {
      return '提示：把 ${movingCard.spokenLabel} 接到 ${targetCard.spokenLabel} 下，优先保持同花色。';
    }

    return '提示：把 ${movingCard.spokenLabel} 接到 ${targetCard.spokenLabel} 下。';
  }

  void _clearHint() {
    _hintTimer?.cancel();
    _hint = null;
  }

  void _armHintTimer() {
    _hintTimer?.cancel();
    _hintTimer = Timer(const Duration(seconds: 4), () {
      if (_hint == null) {
        return;
      }
      _hint = null;
      notifyListeners();
    });
  }

  void _setStatus(String message) {
    _statusMessage = message;
  }

  Future<void> _persistAfterMutation() async {
    await _repository.saveGame(_state);

    if (state.isWin) {
      var nextProgress = _progress;
      final winsByDifficulty = Map<String, int>.of(
        nextProgress.winsByDifficulty,
      );
      winsByDifficulty[state.difficulty.name] =
          (winsByDifficulty[state.difficulty.name] ?? 0) + 1;

      nextProgress = nextProgress.copyWith(
        gamesWon: nextProgress.gamesWon + 1,
        winStreak: nextProgress.winStreak + 1,
        bestScore: max(nextProgress.bestScore, state.score),
        bestTimeSeconds: nextProgress.bestTimeSeconds == 0
            ? state.elapsedSeconds
            : min(nextProgress.bestTimeSeconds, state.elapsedSeconds),
        winsByDifficulty: winsByDifficulty,
        preferredDifficulty: state.difficulty,
      );

      final newlyUnlockedIds = _evaluateAchievements(nextProgress, state);
      if (newlyUnlockedIds.isNotEmpty) {
        final merged = <String>{
          ...nextProgress.unlockedAchievementIds,
          ...newlyUnlockedIds,
        };
        nextProgress = nextProgress.copyWith(unlockedAchievementIds: merged);

        for (final id in newlyUnlockedIds) {
          final achievement = achievementById[id];
          if (achievement != null) {
            _pendingAchievements.add(achievement);
          }
        }
      }

      _progress = nextProgress;
      await _repository.saveProgress(_progress);
      notifyListeners();
      return;
    }

    if (_progress.preferredDifficulty != state.difficulty) {
      _progress = _progress.copyWith(preferredDifficulty: state.difficulty);
      await _repository.saveProgress(_progress);
    }
  }

  Set<String> _evaluateAchievements(
    PlayerProgress progress,
    SpiderGameState wonState,
  ) {
    final unlocked = <String>{};
    final alreadyUnlocked = progress.unlockedAchievementIds;

    void unlock(String id, bool condition) {
      if (condition && !alreadyUnlocked.contains(id)) {
        unlocked.add(id);
      }
    }

    unlock('first_win', progress.gamesWon >= 1);
    unlock('clean_hands', wonState.undoCount == 0);
    unlock('blind_oracle', wonState.hintsUsed == 0);
    unlock(
      'speedrunner',
      wonState.elapsedSeconds > 0 && wonState.elapsedSeconds <= 600,
    );
    unlock('triple_thread', wonState.sequencesCompletedThisGame >= 3);
    unlock('one_suit_master', wonState.difficulty == SpiderDifficulty.oneSuit);
    unlock('two_suit_master', wonState.difficulty == SpiderDifficulty.twoSuits);
    unlock(
      'four_suit_master',
      wonState.difficulty == SpiderDifficulty.fourSuits,
    );
    unlock('streak_three', progress.winStreak >= 3);

    return unlocked;
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!_isReady || _state == null || state.isWin) {
        return;
      }

      _state = state.copyWith(elapsedSeconds: state.elapsedSeconds + 1);
      if (state.elapsedSeconds % 5 == 0) {
        unawaited(_repository.saveGame(_state));
      }
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _hintTimer?.cancel();
    _timer?.cancel();
    super.dispose();
  }
}
