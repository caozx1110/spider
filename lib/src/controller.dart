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
  bool _isReady = false;

  bool get isReady => _isReady;
  SpiderGameState get state => _state!;
  PlayerProgress get progress => _progress;
  SpiderSelection? get selection => _selection;
  MoveHint? get hint => _hint;
  bool get canUndo => _undoStack.isNotEmpty;
  bool get canDeal => SpiderEngine.canDealFromStock(state);
  bool get hasPendingAchievement => _pendingAchievements.isNotEmpty;

  Future<void> initialize() async {
    _progress = await _repository.loadProgress();
    final savedGame = await _repository.loadSavedGame();

    if (savedGame != null) {
      _state = savedGame;
    } else {
      _state = SpiderEngine.newGame(
        _progress.preferredDifficulty,
        random: _random,
      );
      _progress = _progress.copyWith(gamesStarted: _progress.gamesStarted + 1);
      await _repository.saveProgress(_progress);
      await _repository.saveGame(_state);
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
    _hint = null;

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
        _selection = SpiderSelection(column: columnIndex, index: cardIndex);
        _hint = null;
        notifyListeners();
      }
      return;
    }

    final currentSelection = _selection!;
    if (currentSelection.column == columnIndex &&
        currentSelection.index == cardIndex) {
      _selection = null;
      notifyListeners();
      return;
    }

    if (_tryMoveTo(columnIndex)) {
      return;
    }

    if (SpiderEngine.canSelectStack(state, columnIndex, cardIndex)) {
      _selection = SpiderSelection(column: columnIndex, index: cardIndex);
      _hint = null;
      notifyListeners();
    }
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
      return;
    }

    _pushUndo();
    _state = next;
    _selection = null;
    _hint = null;
    notifyListeners();
    await _persistAfterMutation();
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
    _hint = null;
    await _repository.saveGame(_state);
    notifyListeners();
  }

  Future<void> requestHint() async {
    if (!_isReady) {
      return;
    }

    final nextHint = SpiderEngine.findHint(state);
    if (nextHint == null) {
      _hint = null;
      notifyListeners();
      return;
    }

    _hint = nextHint;
    _state = state.copyWith(hintsUsed: state.hintsUsed + 1);
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

    _pushUndo();
    _state = next;
    _selection = null;
    _hint = null;
    notifyListeners();
    unawaited(_persistAfterMutation());
    return true;
  }

  void _pushUndo() {
    _undoStack.add(state);
    if (_undoStack.length > 100) {
      _undoStack.removeAt(0);
    }
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
    _timer?.cancel();
    super.dispose();
  }
}
