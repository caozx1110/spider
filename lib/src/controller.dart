import 'dart:async';
import 'dart:collection';
import 'dart:math';

import 'package:flutter/foundation.dart';

import 'meta_catalog.dart';
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
  final Queue<RogueDraft> _pendingRogueDrafts = Queue<RogueDraft>();

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
  bool get hasPendingRogueDraft => _pendingRogueDrafts.isNotEmpty;

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
    _queueRogueDraftIfNeeded();
    notifyListeners();
  }

  AchievementDefinition? consumeAchievement() {
    if (_pendingAchievements.isEmpty) {
      return null;
    }
    return _pendingAchievements.removeFirst();
  }

  RogueDraft? consumeRogueDraft() {
    if (_pendingRogueDrafts.isEmpty) {
      return null;
    }
    return _pendingRogueDrafts.removeFirst();
  }

  RogueDraft generateOpeningRogueDraft() {
    return _makeRogueDraft(
      milestone: 0,
      excluded: const <String>{},
      title: '织命远征',
      subtitle: '先挑一个初始遗物，决定这局肉鸽流派的起点。',
    );
  }

  Future<void> startNewGame({
    required GameMode mode,
    required SpiderDifficulty difficulty,
    List<String> rogueBoons = const <String>[],
  }) async {
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
    _state = SpiderEngine.newGame(
      difficulty,
      gameMode: mode,
      rogueBoonIds: rogueBoons,
      random: _random,
    );
    _undoStack.clear();
    _selection = null;
    _clearHint();
    _pendingRogueDrafts.clear();

    final status = mode == GameMode.classic
        ? '已进入经典模式 ${difficulty.label}。'
        : '已进入织命远征 ${difficulty.label}。初始遗物已就位。';
    _setStatus('$status 点击自动落位，长按手动选牌。');

    await _repository.saveProgress(_progress);
    await _repository.saveGame(_state);
    notifyListeners();
  }

  Future<void> applyRogueDraftChoice(String boonId, int milestone) async {
    if (!state.isRogue || state.rogueBoonIds.contains(boonId)) {
      return;
    }

    final updatedBoons = <String>[...state.rogueBoonIds, boonId];
    final updatedMilestones = <int>{...state.rogueMilestonesClaimed, milestone}
        .toList()
      ..sort();

    final boon = rogueBoonById[boonId];
    _state = state.copyWith(
      rogueBoonIds: updatedBoons,
      rogueMilestonesClaimed: updatedMilestones,
    );
    _setStatus('远征遗物已加入：${boon?.title ?? boonId}。');
    await _repository.saveGame(_state);
    notifyListeners();
  }

  Future<void> skipRogueDraft(int milestone) async {
    if (!state.isRogue) {
      return;
    }

    final updatedMilestones = <int>{...state.rogueMilestonesClaimed, milestone}
        .toList()
      ..sort();
    _state = state.copyWith(rogueMilestonesClaimed: updatedMilestones);
    _setStatus('你跳过了这次远征事件。');
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

  Future<void> requestHint({bool countUsage = true}) async {
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

    final shouldCountUsage =
        countUsage && !(state.isRogue && state.rogueBoonIds.contains('oracle_hush'));
    if (shouldCountUsage) {
      _state = state.copyWith(hintsUsed: state.hintsUsed + 1);
      await _repository.saveGame(_state);
    }

    _setStatus(_describeHint(nextHint));
    notifyListeners();
  }

  Future<void> useTool(String toolId) async {
    if (!_isReady || progress.toolChargesFor(toolId) <= 0) {
      return;
    }

    switch (toolId) {
      case 'scout_lens':
        await _useScoutLens();
        return;
      case 'auto_weave':
        await _useAutoWeave();
        return;
      case 'royal_polish':
        await _useRoyalPolish();
        return;
      case 'oracle_whisper':
        await _useOracleWhisper();
        return;
    }
  }

  Future<bool> purchaseTool(String toolId) async {
    final tool = toolById[toolId];
    if (tool == null) {
      return false;
    }
    if (_progress.level < tool.unlockLevel || _progress.coins < tool.cost) {
      return false;
    }

    final nextCharges = Map<String, int>.of(_progress.toolCharges);
    nextCharges[tool.id] = (nextCharges[tool.id] ?? 0) + 1;
    _progress = _progress.copyWith(
      coins: _progress.coins - tool.cost,
      toolCharges: nextCharges,
    );
    await _repository.saveProgress(_progress);
    _setStatus('已购入 ${tool.title}，库存 +1。');
    notifyListeners();
    return true;
  }

  Future<bool> purchaseBoardTheme(String id) async {
    final item = boardThemeById[id];
    if (item == null) {
      return false;
    }
    if (_progress.ownedBoardThemeIds.contains(id)) {
      return false;
    }
    if (_progress.level < item.unlockLevel || _progress.coins < item.cost) {
      return false;
    }
    final owned = <String>{..._progress.ownedBoardThemeIds, id};
    _progress = _progress.copyWith(
      coins: _progress.coins - item.cost,
      ownedBoardThemeIds: owned,
    );
    await _repository.saveProgress(_progress);
    _setStatus('已解锁主题 ${item.title}。');
    notifyListeners();
    return true;
  }

  Future<bool> purchaseCardSkin(String id) async {
    final item = cardSkinById[id];
    if (item == null) {
      return false;
    }
    if (_progress.ownedCardSkinIds.contains(id)) {
      return false;
    }
    if (_progress.level < item.unlockLevel || _progress.coins < item.cost) {
      return false;
    }
    final owned = <String>{..._progress.ownedCardSkinIds, id};
    _progress = _progress.copyWith(
      coins: _progress.coins - item.cost,
      ownedCardSkinIds: owned,
    );
    await _repository.saveProgress(_progress);
    _setStatus('已解锁卡牌皮肤 ${item.title}。');
    notifyListeners();
    return true;
  }

  Future<bool> purchaseMotionSkin(String id) async {
    final item = motionSkinById[id];
    if (item == null) {
      return false;
    }
    if (_progress.ownedMotionSkinIds.contains(id)) {
      return false;
    }
    if (_progress.level < item.unlockLevel || _progress.coins < item.cost) {
      return false;
    }
    final owned = <String>{..._progress.ownedMotionSkinIds, id};
    _progress = _progress.copyWith(
      coins: _progress.coins - item.cost,
      ownedMotionSkinIds: owned,
    );
    await _repository.saveProgress(_progress);
    _setStatus('已解锁动画风格 ${item.title}。');
    notifyListeners();
    return true;
  }

  Future<void> equipBoardTheme(String id) async {
    if (!_progress.ownedBoardThemeIds.contains(id)) {
      return;
    }
    _progress = _progress.copyWith(equippedBoardThemeId: id);
    await _repository.saveProgress(_progress);
    _setStatus('已装备主题 ${boardThemeById[id]?.title ?? id}。');
    notifyListeners();
  }

  Future<void> equipCardSkin(String id) async {
    if (!_progress.ownedCardSkinIds.contains(id)) {
      return;
    }
    _progress = _progress.copyWith(equippedCardSkinId: id);
    await _repository.saveProgress(_progress);
    _setStatus('已装备卡牌皮肤 ${cardSkinById[id]?.title ?? id}。');
    notifyListeners();
  }

  Future<void> equipMotionSkin(String id) async {
    if (!_progress.ownedMotionSkinIds.contains(id)) {
      return;
    }
    _progress = _progress.copyWith(equippedMotionSkinId: id);
    await _repository.saveProgress(_progress);
    _setStatus('已装备动画风格 ${motionSkinById[id]?.title ?? id}。');
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
    final outcome = _applyModeEffects(previous, next, baseStatus);
    _state = outcome.state;
    _selection = null;
    _clearHint();
    _setStatus(outcome.statusMessage);
    _queueRogueDraftIfNeeded();
    notifyListeners();
    await _persistAfterMutation();
  }

  _MutationOutcome _applyModeEffects(
    SpiderGameState previous,
    SpiderGameState next,
    String baseStatus,
  ) {
    var updated = next;
    final notes = <String>[baseStatus];

    if (updated.completedRuns > previous.completedRuns) {
      notes.add('完整顺子已自动收束');
    }

    if (updated.hiddenCardsRevealed > previous.hiddenCardsRevealed) {
      notes.add('翻开了一张暗牌');
    }

    if (updated.isRogue) {
      final boons = updated.rogueBoonIds.toSet();
      var bonusScore = 0;

      final runDelta = updated.completedRuns - previous.completedRuns;
      if (runDelta > 0 && boons.contains('golden_fang')) {
        bonusScore += 60 * runDelta;
        notes.add('金牙纺锤 +${60 * runDelta}');
      }

      final revealDelta = updated.hiddenCardsRevealed - previous.hiddenCardsRevealed;
      if (revealDelta > 0 && boons.contains('veil_lifter')) {
        bonusScore += 28 * revealDelta;
        notes.add('揭幕蛛丝 +${28 * revealDelta}');
      }

      final dealDelta = updated.stockDealsUsed - previous.stockDealsUsed;
      if (dealDelta > 0 && boons.contains('ember_glass')) {
        bonusScore += 18 * dealDelta;
        notes.add('余烬沙漏 +${18 * dealDelta}');
      }

      if (boons.contains('patient_web')) {
        final previousTier = previous.moves ~/ 12;
        final nextTier = updated.moves ~/ 12;
        final bonusTier = nextTier - previousTier;
        if (bonusTier > 0) {
          bonusScore += 24 * bonusTier;
          notes.add('耐心蛛网 +${24 * bonusTier}');
        }
      }

      if (bonusScore > 0) {
        updated = updated.copyWith(score: updated.score + bonusScore);
      }
    }

    return _MutationOutcome(updated, notes.join(' · '));
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

  void _queueRogueDraftIfNeeded() {
    if (!_isReady || _state == null || !state.isRogue || state.isWin) {
      return;
    }

    for (final milestone in const [2, 4, 6]) {
      if (state.completedRuns < milestone ||
          state.rogueMilestonesClaimed.contains(milestone) ||
          _pendingRogueDrafts.any((draft) => draft.milestone == milestone)) {
        continue;
      }

      final excluded = state.rogueBoonIds.toSet();
      if (excluded.length >= rogueBoonCatalog.length) {
        return;
      }
      _pendingRogueDrafts.add(
        _makeRogueDraft(
          milestone: milestone,
          excluded: excluded,
          title: '远征事件',
          subtitle: '你完成了 $milestone 组顺子，可以从新的遗物里再拿一个。',
        ),
      );
    }
  }

  RogueDraft _makeRogueDraft({
    required int milestone,
    required Set<String> excluded,
    required String title,
    required String subtitle,
  }) {
    final pool = rogueBoonCatalog
        .where((boon) => !excluded.contains(boon.id))
        .map((boon) => boon.id)
        .toList()
      ..shuffle(_random);
    final optionIds = pool.take(min(3, pool.length)).toList();
    return RogueDraft(
      milestone: milestone,
      optionIds: optionIds,
      title: title,
      subtitle: subtitle,
    );
  }

  Future<void> _useScoutLens() async {
    final targets = <int>[];
    for (var index = 0; index < state.tableau.length; index++) {
      final column = state.tableau[index];
      if (column.isNotEmpty && !column.last.faceUp) {
        targets.add(index);
      }
    }
    if (targets.isEmpty) {
      _setStatus('侦丝透镜没有找到可翻开的暗牌。');
      notifyListeners();
      return;
    }

    final targetColumn = targets[_random.nextInt(targets.length)];
    final tableau = state.tableau.map((column) => List<SpiderCard>.of(column)).toList();
    final flipped = tableau[targetColumn].removeLast();
    tableau[targetColumn].add(flipped.copyWith(faceUp: true));
    final next = state.copyWith(
      tableau: tableau,
      hiddenCardsRevealed: state.hiddenCardsRevealed + 1,
    );

    await _consumeToolCharge('scout_lens');
    await _applyToolMutation(
      next,
      baseStatus: '侦丝透镜翻开了第 ${targetColumn + 1} 列顶部的暗牌。',
    );
  }

  Future<void> _useAutoWeave() async {
    final hint = SpiderEngine.findHint(state);
    if (hint == null) {
      _setStatus('自动织线没有找到可执行的动作。');
      notifyListeners();
      return;
    }

    await _consumeToolCharge('auto_weave');

    if (hint.isDeal) {
      final next = SpiderEngine.dealFromStock(state);
      if (next == null) {
        _setStatus('自动织线未能执行库存发牌。');
        notifyListeners();
        return;
      }
      await _applyToolMutation(next, baseStatus: '自动织线为你补入了一轮新牌。');
      return;
    }

    final next = SpiderEngine.moveStack(
      state,
      hint.fromColumn!,
      hint.fromIndex!,
      hint.toColumn!,
    );
    if (next == null) {
      _setStatus('自动织线未能完成移动。');
      notifyListeners();
      return;
    }

    await _applyToolMutation(next, baseStatus: '自动织线执行了一次最佳移动。');
  }

  Future<void> _useRoyalPolish() async {
    await _consumeToolCharge('royal_polish');
    final next = state.copyWith(score: state.score + 100);
    await _applyToolMutation(next, baseStatus: '王庭抛光为本局追加了 100 分。');
  }

  Future<void> _useOracleWhisper() async {
    await _consumeToolCharge('oracle_whisper');
    await requestHint(countUsage: false);
  }

  Future<void> _consumeToolCharge(String toolId) async {
    final nextCharges = Map<String, int>.of(_progress.toolCharges);
    final current = nextCharges[toolId] ?? 0;
    if (current <= 1) {
      nextCharges.remove(toolId);
    } else {
      nextCharges[toolId] = current - 1;
    }
    _progress = _progress.copyWith(toolCharges: nextCharges);
    await _repository.saveProgress(_progress);
  }

  Future<void> _applyToolMutation(
    SpiderGameState next, {
    required String baseStatus,
  }) async {
    _state = next;
    _selection = null;
    _clearHint();
    _setStatus(baseStatus);
    _queueRogueDraftIfNeeded();
    await _repository.saveGame(_state);
    notifyListeners();
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

      final winsByMode = Map<String, int>.of(nextProgress.winsByMode);
      winsByMode[state.gameMode.name] =
          (winsByMode[state.gameMode.name] ?? 0) + 1;

      final rewards = _calculateWinRewards(state);
      nextProgress = nextProgress.copyWith(
        gamesWon: nextProgress.gamesWon + 1,
        winStreak: nextProgress.winStreak + 1,
        bestScore: max(nextProgress.bestScore, state.score),
        bestTimeSeconds: nextProgress.bestTimeSeconds == 0
            ? state.elapsedSeconds
            : min(nextProgress.bestTimeSeconds, state.elapsedSeconds),
        winsByDifficulty: winsByDifficulty,
        preferredDifficulty: state.difficulty,
        winsByMode: winsByMode,
        coins: nextProgress.coins + rewards.coins,
        xp: nextProgress.xp + rewards.xp,
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
      _setStatus(
        '结算完成：获得 ${rewards.coins} 积分 / ${rewards.xp} 经验。',
      );
      await _repository.saveProgress(_progress);
      notifyListeners();
      return;
    }

    if (_progress.preferredDifficulty != state.difficulty) {
      _progress = _progress.copyWith(preferredDifficulty: state.difficulty);
      await _repository.saveProgress(_progress);
    }
  }

  _RewardBundle _calculateWinRewards(SpiderGameState state) {
    final baseCoins = switch (state.difficulty) {
      SpiderDifficulty.oneSuit => 80,
      SpiderDifficulty.twoSuits => 120,
      SpiderDifficulty.fourSuits => 180,
    };
    final baseXp = switch (state.difficulty) {
      SpiderDifficulty.oneSuit => 60,
      SpiderDifficulty.twoSuits => 85,
      SpiderDifficulty.fourSuits => 120,
    };

    var coins = baseCoins + state.completedRuns * 10 + state.score ~/ 12;
    var xp = baseXp + state.completedRuns * 4;

    if (state.isRogue) {
      coins += 45 + state.rogueBoonIds.length * 18;
      xp += 25 + state.rogueBoonIds.length * 10;
      if (state.rogueBoonIds.contains('fortune_nest')) {
        coins = (coins * 1.35).round();
        xp = (xp * 1.35).round();
      }
    }

    return _RewardBundle(coins: coins, xp: xp);
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

class _MutationOutcome {
  const _MutationOutcome(this.state, this.statusMessage);

  final SpiderGameState state;
  final String statusMessage;
}

class _RewardBundle {
  const _RewardBundle({
    required this.coins,
    required this.xp,
  });

  final int coins;
  final int xp;
}
