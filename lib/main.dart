import 'dart:math' as math;
import 'dart:async';

import 'package:flutter/material.dart';

import 'src/controller.dart';
import 'src/models.dart';
import 'src/progress_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final repository = await ProgressRepository.create();
  runApp(SpiderApp(repository: repository));
}

class SpiderApp extends StatelessWidget {
  const SpiderApp({super.key, required this.repository});

  final ProgressRepository repository;

  @override
  Widget build(BuildContext context) {
    final base = ThemeData(
      useMaterial3: true,
      fontFamily: 'Outfit',
      colorScheme: ColorScheme.fromSeed(
        seedColor: _Palette.brass,
        primary: _Palette.brass,
        surface: _Palette.paper,
      ),
    );

    return MaterialApp(
      title: 'Silken Spider',
      debugShowCheckedModeBanner: false,
      theme: base.copyWith(
        scaffoldBackgroundColor: Colors.transparent,
        textTheme: base.textTheme.copyWith(
          displayLarge: const TextStyle(
            fontFamily: 'CormorantGaramond',
            fontWeight: FontWeight.w600,
            color: _Palette.paper,
          ),
          headlineLarge: const TextStyle(
            fontFamily: 'CormorantGaramond',
            fontWeight: FontWeight.w600,
            color: _Palette.paper,
          ),
          bodyLarge: const TextStyle(color: _Palette.paper),
          bodyMedium: const TextStyle(color: _Palette.paper),
        ),
      ),
      home: SpiderHome(repository: repository),
    );
  }
}

class SpiderHome extends StatefulWidget {
  const SpiderHome({super.key, required this.repository});

  final ProgressRepository repository;

  @override
  State<SpiderHome> createState() => _SpiderHomeState();
}

class _SpiderHomeState extends State<SpiderHome> {
  late final SpiderController _controller;
  bool _showingAchievement = false;
  Timer? _titleComboTimer;
  Timer? _secretRunTimer;
  int _titleTapCount = 0;
  int _secretRunToken = 0;
  String? _secretStatus;

  @override
  void initState() {
    super.initState();
    _controller = SpiderController(widget.repository);
    _controller.addListener(_handleControllerAnnouncements);
    _controller.initialize();
  }

  @override
  void dispose() {
    _titleComboTimer?.cancel();
    _secretRunTimer?.cancel();
    _controller.removeListener(_handleControllerAnnouncements);
    _controller.dispose();
    super.dispose();
  }

  void _handleTitleTap() {
    _titleComboTimer?.cancel();
    _titleTapCount++;

    if (_titleTapCount >= 3) {
      _titleTapCount = 0;
      _secretRunTimer?.cancel();
      setState(() {
        _secretRunToken++;
        _secretStatus = '彩蛋：夜织者沿着牌桌巡游了一圈。';
      });
      _secretRunTimer = Timer(const Duration(seconds: 6), () {
        if (!mounted) {
          return;
        }
        setState(() {
          _secretStatus = null;
        });
      });
      return;
    }

    _titleComboTimer = Timer(const Duration(milliseconds: 900), () {
      _titleTapCount = 0;
    });
  }

  Future<void> _handleControllerAnnouncements() async {
    if (!mounted || _showingAchievement || !_controller.hasPendingAchievement) {
      return;
    }

    final achievement = _controller.consumeAchievement();
    if (achievement == null) {
      return;
    }

    _showingAchievement = true;
    final messenger = ScaffoldMessenger.of(context);
    await messenger
        .showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            backgroundColor: _Palette.ink.withValues(alpha: 0.92),
            duration: const Duration(seconds: 3),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '成就解锁: ${achievement.title}',
                  style: const TextStyle(
                    color: _Palette.paper,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  achievement.description,
                  style: const TextStyle(color: _Palette.paperSoft),
                ),
              ],
            ),
          ),
        )
        .closed;

    _showingAchievement = false;
    if (_controller.hasPendingAchievement) {
      _handleControllerAnnouncements();
    }
  }

  Future<void> _showDifficultyPicker() async {
    final selected = await showModalBottomSheet<SpiderDifficulty>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final currentDifficulty = _controller.isReady
            ? _controller.state.difficulty
            : SpiderDifficulty.oneSuit;

        return _SheetFrame(
          title: '开始新局',
          subtitle: '选择一个难度，重新洗牌并开启下一张网。',
          child: Column(
            children: [
              for (final difficulty in SpiderDifficulty.values)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _DifficultyTile(
                    difficulty: difficulty,
                    selected: difficulty == currentDifficulty,
                    onTap: () => Navigator.of(context).pop(difficulty),
                  ),
                ),
            ],
          ),
        );
      },
    );

    if (selected != null) {
      await _controller.startNewGame(selected);
    }
  }

  Future<void> _showAchievementSheet() {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final progress = _controller.progress;
        return _SheetFrame(
          title: '成就陈列室',
          subtitle:
              '${progress.unlockedAchievementIds.length}/${achievementCatalog.length} 已解锁',
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 560),
            child: ListView.separated(
              shrinkWrap: true,
              itemBuilder: (context, index) {
                final achievement = achievementCatalog[index];
                final unlocked = progress.unlockedAchievementIds.contains(
                  achievement.id,
                );
                return _AchievementTile(
                  achievement: achievement,
                  unlocked: unlocked,
                );
              },
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemCount: achievementCatalog.length,
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [_Palette.feltBright, _Palette.felt, _Palette.feltDeep],
          ),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: IgnorePointer(child: CustomPaint(painter: _FeltPainter())),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
                child: AnimatedBuilder(
                  animation: _controller,
                  builder: (context, _) {
                    if (!_controller.isReady) {
                      return const _LoadingState();
                    }

                    return LayoutBuilder(
                      builder: (context, constraints) {
                        final compact = constraints.maxWidth < 1120;
                        final state = _controller.state;
                        final progress = _controller.progress;

                        final board = _GameBoard(
                          state: state,
                          selection: _controller.selection,
                          hint: _controller.hint,
                          hintPulseToken: _controller.hintPulseToken,
                          onCardTap: _controller.onCardTapped,
                          onCardLongPress: _controller.onCardLongPressed,
                          onColumnTap: _controller.onColumnTapped,
                          onDealFromStock: _controller.dealFromStock,
                        );

                        final header = _HeaderBar(
                          state: state,
                          progress: progress,
                          canUndo: _controller.canUndo,
                          canDeal: _controller.canDeal,
                          onNewGame: _showDifficultyPicker,
                          onUndo: _controller.undo,
                          onHint: _controller.requestHint,
                          onDeal: _controller.dealFromStock,
                          onAchievements: _showAchievementSheet,
                          statusText: _controller.statusMessage,
                          secretStatus: _secretStatus,
                          onTitleTap: _handleTitleTap,
                        );

                        final sidePanel = _SidePanel(
                          state: state,
                          progress: progress,
                          onAchievements: _showAchievementSheet,
                          statusText:
                              _secretStatus ?? _controller.statusMessage,
                        );

                        return Stack(
                          children: [
                            if (compact)
                              Column(
                                children: [
                                  header,
                                  const SizedBox(height: 16),
                                  Expanded(child: board),
                                  const SizedBox(height: 16),
                                  sidePanel,
                                ],
                              )
                            else
                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      children: [
                                        header,
                                        const SizedBox(height: 18),
                                        Expanded(child: board),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 18),
                                  SizedBox(width: 320, child: sidePanel),
                                ],
                              ),
                            if (state.isWin)
                              Positioned.fill(
                                child: _WinOverlay(
                                  state: state,
                                  onPlayAgain: _showDifficultyPicker,
                                  onShowAchievements: _showAchievementSheet,
                                ),
                              ),
                            if (_secretStatus != null)
                              Positioned(
                                left: 0,
                                right: 0,
                                top: compact ? 94 : 110,
                                child: IgnorePointer(
                                  child: _SpiderMascotRun(
                                    runToken: _secretRunToken,
                                  ),
                                ),
                              ),
                          ],
                        );
                      },
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderBar extends StatelessWidget {
  const _HeaderBar({
    required this.state,
    required this.progress,
    required this.canUndo,
    required this.canDeal,
    required this.onNewGame,
    required this.onUndo,
    required this.onHint,
    required this.onDeal,
    required this.onAchievements,
    required this.statusText,
    required this.secretStatus,
    required this.onTitleTap,
  });

  final SpiderGameState state;
  final PlayerProgress progress;
  final bool canUndo;
  final bool canDeal;
  final Future<void> Function() onNewGame;
  final Future<void> Function() onUndo;
  final Future<void> Function() onHint;
  final Future<void> Function() onDeal;
  final Future<void> Function() onAchievements;
  final String statusText;
  final String? secretStatus;
  final VoidCallback onTitleTap;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 20,
            runSpacing: 16,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              GestureDetector(
                onTap: onTitleTap,
                behavior: HitTestBehavior.opaque,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Silken Spider',
                      style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        letterSpacing: 0.4,
                        height: 0.95,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '经典蜘蛛纸牌，带成就、断点续局和跨平台界面。',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: _Palette.paperSoft,
                      ),
                    ),
                  ],
                ),
              ),
              _InfoPill(label: '当前难度', value: state.difficulty.label),
              _InfoPill(label: '总胜场', value: '${progress.gamesWon}'),
              _InfoPill(label: '连胜', value: '${progress.winStreak}'),
            ],
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _ActionButton(
                label: '新游戏',
                icon: Icons.autorenew_rounded,
                onPressed: onNewGame,
              ),
              _ActionButton(
                label: '撤销',
                icon: Icons.undo_rounded,
                onPressed: canUndo ? onUndo : null,
              ),
              _ActionButton(
                label: '提示',
                icon: Icons.lightbulb_rounded,
                onPressed: onHint,
              ),
              _ActionButton(
                label: '发牌',
                icon: Icons.view_stream_rounded,
                onPressed: canDeal ? onDeal : null,
              ),
              _ActionButton(
                label: '成就',
                icon: Icons.workspace_premium_rounded,
                onPressed: onAchievements,
              ),
            ],
          ),
          const SizedBox(height: 14),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 260),
            child: _StatusStrip(
              key: ValueKey(secretStatus ?? statusText),
              text: secretStatus ?? statusText,
              secret: secretStatus != null,
            ),
          ),
        ],
      ),
    );
  }
}

class _SidePanel extends StatelessWidget {
  const _SidePanel({
    required this.state,
    required this.progress,
    required this.onAchievements,
    required this.statusText,
  });

  final SpiderGameState state;
  final PlayerProgress progress;
  final Future<void> Function() onAchievements;
  final String statusText;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      padding: const EdgeInsets.all(18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle(title: '本局状态', subtitle: '计时、得分和当前局势一眼看清'),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _MetricTile(label: '得分', value: '${state.score}'),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MetricTile(
                  label: '用时',
                  value: _formatDuration(state.elapsedSeconds),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _MetricTile(label: '移动', value: '${state.moves}'),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MetricTile(
                  label: '收束',
                  value: '${state.completedRuns}/8',
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const _SectionTitle(
            title: '局面提示',
            subtitle: '单击会自动尝试最佳落点，长按进入手动选牌模式',
          ),
          const SizedBox(height: 10),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 260),
            child: Text(
              statusText,
              key: ValueKey(statusText),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: _Palette.paperSoft,
                height: 1.45,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _MiniBadge(label: '隐藏牌 ${state.hiddenCardCount}'),
              _MiniBadge(label: '库存轮次 ${state.stockDealsUsed}/5'),
              _MiniBadge(label: '撤销 ${state.undoCount}'),
              _MiniBadge(label: '提示 ${state.hintsUsed}'),
            ],
          ),
          const SizedBox(height: 18),
          const _SectionTitle(title: '成就进度', subtitle: '这套存档会记住已解锁成就和各难度胜场'),
          const SizedBox(height: 10),
          Text(
            '${progress.unlockedAchievementIds.length}/${achievementCatalog.length} 已解锁',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: _Palette.paper,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '单花色 ${progress.winsFor(SpiderDifficulty.oneSuit)} 胜  ·  双花色 ${progress.winsFor(SpiderDifficulty.twoSuits)} 胜  ·  四色 ${progress.winsFor(SpiderDifficulty.fourSuits)} 胜',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: _Palette.paperSoft,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.tonalIcon(
              onPressed: onAchievements,
              icon: const Icon(Icons.visibility_rounded),
              label: const Text('查看全部成就'),
            ),
          ),
        ],
      ),
    );
  }
}

class _GameBoard extends StatelessWidget {
  const _GameBoard({
    required this.state,
    required this.selection,
    required this.hint,
    required this.hintPulseToken,
    required this.onCardTap,
    required this.onCardLongPress,
    required this.onColumnTap,
    required this.onDealFromStock,
  });

  final SpiderGameState state;
  final SpiderSelection? selection;
  final MoveHint? hint;
  final int hintPulseToken;
  final void Function(int columnIndex, int cardIndex) onCardTap;
  final void Function(int columnIndex, int cardIndex) onCardLongPress;
  final void Function(int columnIndex) onColumnTap;
  final Future<void> Function() onDealFromStock;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      padding: const EdgeInsets.all(14),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final gap = width < 460
              ? 4.0
              : width < 900
              ? 8.0
              : 12.0;
          final cardWidth = ((width - gap * 9) / 10).clamp(32.0, 98.0);
          final cardHeight = cardWidth * 1.42;
          final faceUpOffset = math.max(cardHeight * 0.28, 18.0);
          final faceDownOffset = math.max(cardHeight * 0.16, 10.0);

          double stackOffset(List<SpiderCard> cards, int index) {
            var offset = 0.0;
            for (var cursor = 1; cursor <= index; cursor++) {
              offset += cards[cursor - 1].faceUp
                  ? faceUpOffset
                  : faceDownOffset;
            }
            return offset;
          }

          double columnHeight(List<SpiderCard> cards) {
            if (cards.isEmpty) {
              return cardHeight * 1.4;
            }

            var height = cardHeight;
            for (var index = 1; index < cards.length; index++) {
              height += cards[index - 1].faceUp ? faceUpOffset : faceDownOffset;
            }
            return height;
          }

          double maxColumnHeight = cardHeight * 1.4;
          for (final column in state.tableau) {
            maxColumnHeight = math.max(maxColumnHeight, columnHeight(column));
          }

          Rect? hintSourceRect;
          Rect? hintTargetRect;
          if (hint?.isMove ?? false) {
            final sourceCards = state.tableau[hint!.fromColumn!];
            final targetCards = state.tableau[hint!.toColumn!];
            hintSourceRect = Rect.fromLTWH(
              hint!.fromColumn! * (cardWidth + gap),
              stackOffset(sourceCards, hint!.fromIndex!),
              cardWidth,
              cardHeight,
            );
            hintTargetRect = Rect.fromLTWH(
              hint!.toColumn! * (cardWidth + gap),
              targetCards.isEmpty
                  ? cardHeight * 0.16
                  : stackOffset(targetCards, targetCards.length - 1),
              cardWidth,
              cardHeight,
            );
          }

          return Column(
            children: [
              Wrap(
                spacing: 16,
                runSpacing: 12,
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _StockPile(
                    width: cardWidth,
                    height: cardHeight,
                    groupsRemaining: state.stockDealsRemaining,
                    highlighted: hint?.kind == HintKind.deal,
                    pulseToken: hintPulseToken,
                    enabled: state.stockDealsRemaining > 0,
                    onTap: state.stockDealsRemaining > 0
                        ? onDealFromStock
                        : null,
                  ),
                  _CompletedRunsRow(
                    completedRuns: state.completedRuns,
                    width: cardWidth,
                    height: cardHeight,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: Scrollbar(
                  thumbVisibility: true,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.only(right: 6),
                    child: SizedBox(
                      height: maxColumnHeight + 8,
                      child: Stack(
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              for (
                                var columnIndex = 0;
                                columnIndex < state.tableau.length;
                                columnIndex++
                              ) ...[
                                _TableauColumn(
                                  cards: state.tableau[columnIndex],
                                  columnIndex: columnIndex,
                                  width: cardWidth,
                                  height: maxColumnHeight,
                                  faceUpOffset: faceUpOffset,
                                  faceDownOffset: faceDownOffset,
                                  selection: selection,
                                  hint: hint,
                                  hintPulseToken: hintPulseToken,
                                  onCardTap: onCardTap,
                                  onCardLongPress: onCardLongPress,
                                  onColumnTap: onColumnTap,
                                ),
                                if (columnIndex < state.tableau.length - 1)
                                  SizedBox(width: gap),
                              ],
                            ],
                          ),
                          if (hint?.isMove ?? false)
                            Positioned.fill(
                              child: IgnorePointer(
                                child: TweenAnimationBuilder<double>(
                                  key: ValueKey('hint-thread-$hintPulseToken'),
                                  tween: Tween(begin: 0, end: 1),
                                  duration: const Duration(milliseconds: 1400),
                                  curve: Curves.easeInOutCubic,
                                  builder: (context, value, _) {
                                    return CustomPaint(
                                      painter: _HintThreadPainter(
                                        sourceRect: hintSourceRect!,
                                        targetRect: hintTargetRect!,
                                        progress: value,
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _TableauColumn extends StatelessWidget {
  const _TableauColumn({
    required this.cards,
    required this.columnIndex,
    required this.width,
    required this.height,
    required this.faceUpOffset,
    required this.faceDownOffset,
    required this.selection,
    required this.hint,
    required this.hintPulseToken,
    required this.onCardTap,
    required this.onCardLongPress,
    required this.onColumnTap,
  });

  final List<SpiderCard> cards;
  final int columnIndex;
  final double width;
  final double height;
  final double faceUpOffset;
  final double faceDownOffset;
  final SpiderSelection? selection;
  final MoveHint? hint;
  final int hintPulseToken;
  final void Function(int columnIndex, int cardIndex) onCardTap;
  final void Function(int columnIndex, int cardIndex) onCardLongPress;
  final void Function(int columnIndex) onColumnTap;

  double _cardOffset(int index) {
    var offset = 0.0;
    for (var cursor = 1; cursor <= index; cursor++) {
      offset += cards[cursor - 1].faceUp ? faceUpOffset : faceDownOffset;
    }
    return offset;
  }

  @override
  Widget build(BuildContext context) {
    final targetHint =
        hint?.kind == HintKind.move && hint?.toColumn == columnIndex;

    return TweenAnimationBuilder<double>(
      key: ValueKey('column-$columnIndex-$hintPulseToken-$targetHint'),
      tween: Tween(begin: 0, end: 1),
      duration: targetHint
          ? const Duration(milliseconds: 1200)
          : const Duration(milliseconds: 1),
      builder: (context, value, _) {
        final pulse = targetHint ? math.sin(value * math.pi) : 0.0;
        return Transform.scale(
          scale: 1 + pulse * 0.012,
          child: GestureDetector(
            onTap: () => onColumnTap(columnIndex),
            child: Container(
              width: width,
              height: height,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: targetHint
                      ? Color.lerp(
                          _Palette.brass,
                          _Palette.paper,
                          pulse * 0.35,
                        )!
                      : Colors.white.withValues(
                          alpha: cards.isEmpty ? 0.18 : 0.08,
                        ),
                  width: targetHint ? 2.2 : 1.2,
                ),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white.withValues(alpha: 0.06 + pulse * 0.06),
                    Colors.white.withValues(alpha: 0.02),
                  ],
                ),
                boxShadow: targetHint
                    ? [
                        BoxShadow(
                          color: _Palette.brass.withValues(
                            alpha: 0.12 + pulse * 0.12,
                          ),
                          blurRadius: 18,
                          offset: const Offset(0, 10),
                        ),
                      ]
                    : null,
              ),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  if (cards.isEmpty)
                    Align(
                      child: Icon(
                        Icons.add_rounded,
                        color: Colors.white.withValues(alpha: 0.28),
                        size: width * 0.58,
                      ),
                    ),
                  for (var index = 0; index < cards.length; index++)
                    Positioned(
                      top: _cardOffset(index),
                      left: 0,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: cards[index].faceUp
                            ? () => onCardTap(columnIndex, index)
                            : null,
                        onLongPress: cards[index].faceUp
                            ? () => onCardLongPress(columnIndex, index)
                            : null,
                        child: _PlayingCard(
                          card: cards[index],
                          width: width,
                          selected:
                              selection?.column == columnIndex &&
                              index >= (selection?.index ?? 999),
                          hintSource:
                              hint?.kind == HintKind.move &&
                              hint?.fromColumn == columnIndex &&
                              index >= (hint?.fromIndex ?? 999),
                          hintPulseToken: hintPulseToken,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _PlayingCard extends StatelessWidget {
  const _PlayingCard({
    required this.card,
    required this.width,
    required this.selected,
    required this.hintSource,
    required this.hintPulseToken,
  });

  final SpiderCard card;
  final double width;
  final bool selected;
  final bool hintSource;
  final int hintPulseToken;

  @override
  Widget build(BuildContext context) {
    final height = width * 1.42;
    final radius = BorderRadius.circular(width * 0.16);
    final accent = selected
        ? _Palette.brass
        : hintSource
        ? _Palette.paper
        : null;

    return TweenAnimationBuilder<double>(
      key: ValueKey('card-${card.id}-$hintPulseToken-$hintSource-$selected'),
      tween: Tween(begin: 0, end: 1),
      duration: hintSource
          ? const Duration(milliseconds: 1100)
          : const Duration(milliseconds: 1),
      builder: (context, value, _) {
        final pulse = hintSource ? math.sin(value * math.pi) : 0.0;
        return Transform.translate(
          offset: Offset(0, -6 * pulse),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            width: width,
            height: height,
            decoration: BoxDecoration(
              borderRadius: radius,
              border: Border.all(
                color: accent ?? Colors.black.withValues(alpha: 0.08),
                width: accent != null ? 2.2 : 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: (accent ?? Colors.black).withValues(
                    alpha: accent != null ? 0.28 + pulse * 0.1 : 0.18,
                  ),
                  blurRadius: selected ? 20 : 12 + pulse * 10,
                  offset: const Offset(0, 8),
                ),
              ],
              gradient: card.faceUp
                  ? const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFFFFFCF4), Color(0xFFF2E6C9)],
                    )
                  : const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF183631), Color(0xFF0A1A18)],
                    ),
            ),
            child: card.faceUp
                ? _FaceUpCard(card: card)
                : _FaceDownCard(width: width, accent: accent != null),
          ),
        );
      },
    );
  }
}

class _FaceUpCard extends StatelessWidget {
  const _FaceUpCard({required this.card});

  final SpiderCard card;

  @override
  Widget build(BuildContext context) {
    final color = card.suit.isRed ? _Palette.berry : _Palette.ink;
    final rankStyle = TextStyle(
      color: color,
      fontWeight: FontWeight.w700,
      fontSize: 18,
      height: 1,
    );

    return Padding(
      padding: const EdgeInsets.all(8),
      child: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(card.rankLabel, style: rankStyle),
                Text(
                  card.suit.symbol,
                  style: TextStyle(color: color, fontSize: 16, height: 1),
                ),
              ],
            ),
          ),
          Align(
            child: Text(
              card.suit.symbol,
              style: TextStyle(
                color: color.withValues(alpha: 0.86),
                fontSize: 34,
                fontWeight: FontWeight.w700,
                height: 1,
              ),
            ),
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: RotatedBox(
              quarterTurns: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(card.rankLabel, style: rankStyle),
                  Text(
                    card.suit.symbol,
                    style: TextStyle(color: color, fontSize: 16, height: 1),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FaceDownCard extends StatelessWidget {
  const _FaceDownCard({required this.width, required this.accent});

  final double width;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final border = accent
        ? _Palette.brass
        : Colors.white.withValues(alpha: 0.22);
    return Padding(
      padding: const EdgeInsets.all(7),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(width * 0.12),
          border: Border.all(color: border),
          gradient: const RadialGradient(
            colors: [Color(0xFF285248), Color(0xFF102120)],
          ),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            CustomPaint(painter: _CardBackPainter()),
            Center(
              child: Icon(
                Icons.auto_awesome_rounded,
                size: width * 0.28,
                color: border,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StockPile extends StatelessWidget {
  const _StockPile({
    required this.width,
    required this.height,
    required this.groupsRemaining,
    required this.highlighted,
    required this.pulseToken,
    required this.enabled,
    required this.onTap,
  });

  final double width;
  final double height;
  final int groupsRemaining;
  final bool highlighted;
  final int pulseToken;
  final bool enabled;
  final Future<void> Function()? onTap;

  @override
  Widget build(BuildContext context) {
    final borderColor = highlighted
        ? _Palette.brass
        : Colors.white.withValues(alpha: 0.22);
    return TweenAnimationBuilder<double>(
      key: ValueKey('stock-$pulseToken-$highlighted-$groupsRemaining'),
      tween: Tween(begin: 0, end: 1),
      duration: highlighted
          ? const Duration(milliseconds: 1200)
          : const Duration(milliseconds: 1),
      builder: (context, value, _) {
        final pulse = highlighted ? math.sin(value * math.pi) : 0.0;
        return Transform.scale(
          scale: 1 + pulse * 0.03,
          child: GestureDetector(
            onTap: enabled ? onTap : null,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '库存牌堆',
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: width + 22,
                  height: height + 12,
                  child: Stack(
                    children: [
                      for (
                        var layer = 0;
                        layer < math.min(groupsRemaining, 3);
                        layer++
                      )
                        Positioned(
                          left: layer * 6,
                          top: layer * 3,
                          child: IgnorePointer(
                            child: _PlayingCard(
                              card: SpiderCard(
                                id: 'stock_$layer',
                                suit: SpiderSuit.spades,
                                rank: 1,
                                faceUp: false,
                              ),
                              width: width,
                              selected: false,
                              hintSource: false,
                              hintPulseToken: 0,
                            ),
                          ),
                        ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: _Palette.ink.withValues(alpha: 0.84),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: Color.lerp(
                                borderColor,
                                _Palette.paper,
                                pulse * 0.25,
                              )!,
                            ),
                          ),
                          child: Text(
                            '$groupsRemaining 组',
                            style: const TextStyle(
                              color: _Palette.paper,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _CompletedRunsRow extends StatelessWidget {
  const _CompletedRunsRow({
    required this.completedRuns,
    required this.width,
    required this.height,
  });

  final int completedRuns;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final slotWidth = math.min(width * 0.58, 56.0);
    final slotHeight = math.min(height * 0.42, 64.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '已收束顺子',
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (var index = 0; index < 8; index++)
              Container(
                width: slotWidth,
                height: slotHeight,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: index < completedRuns
                        ? _Palette.brass
                        : Colors.white.withValues(alpha: 0.18),
                  ),
                  gradient: LinearGradient(
                    colors: index < completedRuns
                        ? const [Color(0xFFD8B06A), Color(0xFF8F6631)]
                        : [
                            Colors.white.withValues(alpha: 0.08),
                            Colors.white.withValues(alpha: 0.02),
                          ],
                  ),
                ),
                child: Icon(
                  index < completedRuns
                      ? Icons.workspace_premium_rounded
                      : Icons.linear_scale_rounded,
                  color: index < completedRuns
                      ? _Palette.ink
                      : Colors.white.withValues(alpha: 0.34),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _WinOverlay extends StatelessWidget {
  const _WinOverlay({
    required this.state,
    required this.onPlayAgain,
    required this.onShowAchievements,
  });

  final SpiderGameState state;
  final Future<void> Function() onPlayAgain;
  final Future<void> Function() onShowAchievements;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _Palette.feltDeep.withValues(alpha: 0.58),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: _Panel(
            padding: const EdgeInsets.all(26),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '织网完成',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  '${state.difficulty.label} 挑战已完成。你收走了全部 8 组顺子。',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: _Palette.paperSoft,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 18),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _MiniBadge(label: '得分 ${state.score}'),
                    _MiniBadge(
                      label: '用时 ${_formatDuration(state.elapsedSeconds)}',
                    ),
                    _MiniBadge(label: '移动 ${state.moves}'),
                  ],
                ),
                const SizedBox(height: 22),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    FilledButton.icon(
                      onPressed: onPlayAgain,
                      icon: const Icon(Icons.autorenew_rounded),
                      label: const Text('再来一局'),
                    ),
                    FilledButton.tonalIcon(
                      onPressed: onShowAchievements,
                      icon: const Icon(Icons.workspace_premium_rounded),
                      label: const Text('查看成就'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final Future<void> Function()? onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton.tonalIcon(
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(label),
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        foregroundColor: _Palette.paper,
        backgroundColor: Colors.white.withValues(alpha: 0.10),
        disabledBackgroundColor: Colors.white.withValues(alpha: 0.05),
        disabledForegroundColor: Colors.white.withValues(alpha: 0.38),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
    );
  }
}

class _DifficultyTile extends StatelessWidget {
  const _DifficultyTile({
    required this.difficulty,
    required this.selected,
    required this.onTap,
  });

  final SpiderDifficulty difficulty;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Ink(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: selected
                ? _Palette.brass
                : Colors.white.withValues(alpha: 0.16),
            width: selected ? 2.0 : 1.0,
          ),
          color: Colors.white.withValues(alpha: selected ? 0.10 : 0.05),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: selected
                        ? const [Color(0xFFD5AF6A), Color(0xFF91662C)]
                        : const [Color(0xFF29534A), Color(0xFF18312C)],
                  ),
                ),
                child: Center(
                  child: Text(
                    '${difficulty.suitCount}',
                    style: const TextStyle(
                      color: _Palette.paper,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      difficulty.label,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: _Palette.paper,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      difficulty.subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: _Palette.paperSoft,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              if (selected)
                const Icon(Icons.check_circle_rounded, color: _Palette.brass),
            ],
          ),
        ),
      ),
    );
  }
}

class _AchievementTile extends StatelessWidget {
  const _AchievementTile({required this.achievement, required this.unlocked});

  final AchievementDefinition achievement;
  final bool unlocked;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: unlocked
              ? _Palette.brass
              : Colors.white.withValues(alpha: 0.14),
        ),
        color: Colors.white.withValues(alpha: unlocked ? 0.10 : 0.04),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: unlocked
                    ? const [Color(0xFFD8B06A), Color(0xFF8E662D)]
                    : const [Color(0xFF234842), Color(0xFF122523)],
              ),
            ),
            child: Icon(
              unlocked ? Icons.workspace_premium_rounded : Icons.lock_rounded,
              color: unlocked ? _Palette.ink : _Palette.paperSoft,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  achievement.title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: _Palette.paper,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  achievement.description,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: _Palette.paperSoft,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child, this.padding = const EdgeInsets.all(16)});

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.14),
            Colors.white.withValues(alpha: 0.04),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Colors.white.withValues(alpha: 0.06),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: _Palette.paperSoft),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: _Palette.paper,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: Colors.white.withValues(alpha: 0.08),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: '$label  ',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: _Palette.paperSoft),
            ),
            TextSpan(
              text: value,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: _Palette.paper,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniBadge extends StatelessWidget {
  const _MiniBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: Colors.white.withValues(alpha: 0.06),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: _Palette.paper,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _StatusStrip extends StatelessWidget {
  const _StatusStrip({super.key, required this.text, required this.secret});

  final String text;
  final bool secret;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: secret
            ? _Palette.brass.withValues(alpha: 0.16)
            : Colors.white.withValues(alpha: 0.06),
        border: Border.all(
          color: secret
              ? _Palette.brass.withValues(alpha: 0.45)
              : Colors.white.withValues(alpha: 0.08),
        ),
      ),
      child: Row(
        children: [
          Icon(
            secret ? Icons.auto_awesome_rounded : Icons.touch_app_rounded,
            color: secret ? _Palette.brass : _Palette.paperSoft,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: _Palette.paper,
                height: 1.4,
                fontWeight: secret ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: _Palette.paper,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: _Palette.paperSoft,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}

class _SheetFrame extends StatelessWidget {
  const _SheetFrame({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: _Panel(
          padding: const EdgeInsets.all(20),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: _Palette.paperSoft,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 18),
                child,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(_Palette.brass),
          ),
          SizedBox(height: 18),
          Text(
            '正在展开牌桌…',
            style: TextStyle(
              color: _Palette.paper,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _FeltPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.03)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    const step = 28.0;
    for (double x = -size.height; x < size.width; x += step) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x + size.height, size.height),
        gridPaint,
      );
    }

    final glowPaint = Paint()
      ..shader =
          const RadialGradient(
            colors: [Color(0x44D6B06B), Color(0x00154B41)],
          ).createShader(
            Rect.fromCircle(
              center: Offset(size.width * 0.82, size.height * 0.2),
              radius: size.shortestSide * 0.4,
            ),
          );
    canvas.drawRect(Offset.zero & size, glowPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _CardBackPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    final inset = 8.0;
    final rect = Rect.fromLTWH(
      inset,
      inset,
      size.width - inset * 2,
      size.height - inset * 2,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(12)),
      paint,
    );

    for (var index = 0; index < 6; index++) {
      final factor = (index + 1) / 7;
      final y = size.height * factor;
      canvas.drawLine(
        Offset(inset + 4, y),
        Offset(size.width - inset - 4, y),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _HintThreadPainter extends CustomPainter {
  const _HintThreadPainter({
    required this.sourceRect,
    required this.targetRect,
    required this.progress,
  });

  final Rect sourceRect;
  final Rect targetRect;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final start = Offset(
      sourceRect.center.dx,
      sourceRect.top + sourceRect.height * 0.28,
    );
    final end = Offset(
      targetRect.center.dx,
      targetRect.top + targetRect.height * 0.28,
    );
    final control = Offset(
      (start.dx + end.dx) / 2,
      math.min(start.dy, end.dy) - 48,
    );

    final path = Path()
      ..moveTo(start.dx, start.dy)
      ..quadraticBezierTo(control.dx, control.dy, end.dx, end.dy);

    final basePaint = Paint()
      ..color = _Palette.paper.withValues(alpha: 0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(path, basePaint);

    final metrics = path.computeMetrics();
    if (metrics.isEmpty) {
      return;
    }
    final metric = metrics.first;

    final head = metric.length * progress.clamp(0.08, 1.0);
    final tail = math.max(0.0, head - metric.length * 0.22);
    final silkPaint = Paint()
      ..shader = const LinearGradient(
        colors: [_Palette.paper, _Palette.brass, _Palette.paper],
      ).createShader(Rect.fromPoints(start, end))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(metric.extractPath(tail, head), silkPaint);

    final tangent = metric.getTangentForOffset(head);
    if (tangent != null) {
      final glow = Paint()
        ..color = _Palette.brass.withValues(alpha: 0.92)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
      canvas.drawCircle(tangent.position, 7, glow);
      canvas.drawCircle(tangent.position, 3.5, Paint()..color = _Palette.paper);
    }
  }

  @override
  bool shouldRepaint(covariant _HintThreadPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.sourceRect != sourceRect ||
        oldDelegate.targetRect != targetRect;
  }
}

class _SpiderMascotRun extends StatelessWidget {
  const _SpiderMascotRun({required this.runToken});

  final int runToken;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 50,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return TweenAnimationBuilder<double>(
            key: ValueKey('mascot-run-$runToken'),
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 4800),
            curve: Curves.easeInOutSine,
            builder: (context, value, _) {
              final x = -54 + (constraints.maxWidth + 72) * value;
              final y = math.sin(value * math.pi * 4) * 6;
              return Stack(
                children: [
                  Positioned(
                    left: x,
                    top: 8 + y,
                    child: Transform.rotate(
                      angle: math.sin(value * math.pi * 8) * 0.05,
                      child: CustomPaint(
                        size: const Size(42, 26),
                        painter: _SpiderMascotPainter(progress: value),
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _SpiderMascotPainter extends CustomPainter {
  const _SpiderMascotPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final bodyPaint = Paint()..color = _Palette.ink.withValues(alpha: 0.92);
    final glowPaint = Paint()
      ..color = _Palette.paper.withValues(alpha: 0.20)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

    final bodyCenter = Offset(size.width * 0.54, size.height * 0.56);
    final headCenter = Offset(size.width * 0.27, size.height * 0.50);
    canvas.drawCircle(bodyCenter, size.height * 0.28, glowPaint);
    canvas.drawCircle(bodyCenter, size.height * 0.26, bodyPaint);
    canvas.drawCircle(headCenter, size.height * 0.16, bodyPaint);

    final legPaint = Paint()
      ..color = _Palette.ink.withValues(alpha: 0.88)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    final stride = math.sin(progress * math.pi * 10) * 3;

    void drawLeg(
      double baseY,
      double midYOffset,
      double endYOffset,
      double xJitter,
    ) {
      final path = Path()
        ..moveTo(size.width * 0.38, baseY)
        ..quadraticBezierTo(
          size.width * (0.18 + xJitter),
          baseY + midYOffset,
          size.width * (0.03 + xJitter * 0.5),
          baseY + endYOffset,
        );
      canvas.drawPath(path, legPaint);
    }

    for (var leg = 0; leg < 4; leg++) {
      final topBaseY = size.height * (0.28 + leg * 0.14);
      final bottomBaseY = size.height * (0.72 - leg * 0.14);
      final xJitter = leg * 0.02;
      drawLeg(
        topBaseY,
        -6 - leg.toDouble() - stride,
        -2 - leg.toDouble() * 2 + stride,
        xJitter,
      );
      drawLeg(
        bottomBaseY,
        6 + leg.toDouble() + stride,
        2 + leg.toDouble() * 2 - stride,
        xJitter,
      );
    }

    final eyePaint = Paint()..color = _Palette.brass;
    canvas.drawCircle(
      Offset(headCenter.dx - 2, headCenter.dy - 1),
      1.2,
      eyePaint,
    );
    canvas.drawCircle(
      Offset(headCenter.dx + 2, headCenter.dy - 1),
      1.2,
      eyePaint,
    );
  }

  @override
  bool shouldRepaint(covariant _SpiderMascotPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

String _formatDuration(int seconds) {
  final minutes = seconds ~/ 60;
  final remainingSeconds = seconds % 60;
  return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
}

class _Palette {
  static const feltDeep = Color(0xFF0A231E);
  static const felt = Color(0xFF154B41);
  static const feltBright = Color(0xFF1D6759);
  static const brass = Color(0xFFC49A52);
  static const paper = Color(0xFFF7F0DE);
  static const paperSoft = Color(0xFFE0D5BD);
  static const ink = Color(0xFF1A1714);
  static const berry = Color(0xFF9F3E4D);
}
