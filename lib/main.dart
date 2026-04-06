import 'dart:math' as math;
import 'dart:async';

import 'package:flutter/material.dart';

import 'src/controller.dart';
import 'src/meta_catalog.dart';
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
  bool _showingRogueDraft = false;
  bool _showMenu = true;
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
      if (!_showingRogueDraft && _controller.hasPendingRogueDraft) {
        await _showQueuedRogueDraft();
      }
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
      return;
    }
    if (_controller.hasPendingRogueDraft) {
      await _showQueuedRogueDraft();
    }
  }

  Future<void> _showQueuedRogueDraft() async {
    if (!mounted || _showingRogueDraft) {
      return;
    }
    final draft = _controller.consumeRogueDraft();
    if (draft == null) {
      return;
    }
    _showingRogueDraft = true;
    await showModalBottomSheet<void>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _RogueDraftSheet(
          draft: draft,
          onChoose: (boonId) async {
            Navigator.of(context).pop();
            await _controller.applyRogueDraftChoice(boonId, draft.milestone);
          },
          onSkip: () async {
            Navigator.of(context).pop();
            await _controller.skipRogueDraft(draft.milestone);
          },
        );
      },
    );
    _showingRogueDraft = false;
    if (_controller.hasPendingRogueDraft) {
      await _showQueuedRogueDraft();
    }
  }

  Future<void> _showClassicSetup() async {
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
      await _controller.startNewGame(
        mode: GameMode.classic,
        difficulty: selected,
      );
      if (mounted) {
        setState(() {
          _showMenu = false;
        });
      }
    }
  }

  Future<void> _showRogueSetup() async {
    final openingDraft = _controller.generateOpeningRogueDraft();
    var selectedDifficulty = SpiderDifficulty.twoSuits;
    var selectedBoonId = openingDraft.optionIds.first;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return _SheetFrame(
              title: '织命远征',
              subtitle: '选择难度与初始遗物。远征模式会在进度中加入随机事件与遗物流派。',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      for (final difficulty in SpiderDifficulty.values)
                        ChoiceChip(
                          label: Text(difficulty.label),
                          selected: selectedDifficulty == difficulty,
                          onSelected: (_) {
                            setModalState(() {
                              selectedDifficulty = difficulty;
                            });
                          },
                        ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  const _SectionTitle(
                    title: '初始遗物',
                    subtitle: '先拿一件核心遗物，形成本局的第一条 build 方向',
                  ),
                  const SizedBox(height: 12),
                  for (final boonId in openingDraft.optionIds)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _RogueBoonOptionTile(
                        definition: rogueBoonById[boonId]!,
                        selected: selectedBoonId == boonId,
                        onTap: () {
                          setModalState(() {
                            selectedBoonId = boonId;
                          });
                        },
                      ),
                    ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () async {
                        await _controller.startNewGame(
                          mode: GameMode.rogue,
                          difficulty: selectedDifficulty,
                          rogueBoons: [selectedBoonId],
                        );
                        if (context.mounted) {
                          Navigator.of(context).pop();
                        }
                        if (mounted) {
                          setState(() {
                            _showMenu = false;
                          });
                        }
                      },
                      icon: const Icon(Icons.auto_awesome_rounded),
                      label: const Text('开始远征'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _showNewGameFlow() async {
    if (!_controller.isReady) {
      return;
    }
    if (_controller.state.gameMode == GameMode.rogue) {
      await _showRogueSetup();
      return;
    }
    await _showClassicSetup();
  }

  Future<void> _showCollectionStudio() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            return _CollectionStudioSheet(controller: _controller);
          },
        );
      },
    );
  }

  Future<void> _showToolInventory() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            return _ToolInventorySheet(controller: _controller);
          },
        );
      },
    );
  }

  void _resumeGame() {
    setState(() {
      _showMenu = false;
    });
  }

  void _openMenu() {
    setState(() {
      _showMenu = true;
    });
  }

  Future<void> _showModeMenu() async {
    setState(() {
      _showMenu = true;
    });
  }

  Future<void> _showAchievementsFromMenu() async {
    await _showAchievementSheet();
  }

  Future<void> _showMenuAction(GameMode mode) async {
    if (mode == GameMode.classic) {
      await _showClassicSetup();
      return;
    }
    await _showRogueSetup();
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
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: _controller.isReady
                ? [
                    SkinBundle.fromProgress(_controller.progress).board.primary,
                    SkinBundle.fromProgress(_controller.progress).board.secondary,
                    SkinBundle.fromProgress(_controller.progress).board.tertiary,
                  ]
                : [_Palette.feltBright, _Palette.felt, _Palette.feltDeep],
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
                        final skin = SkinBundle.fromProgress(progress);

                        final board = _GameBoard(
                          state: state,
                          skin: skin,
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
                          skin: skin,
                          canUndo: _controller.canUndo,
                          canDeal: _controller.canDeal,
                          onNewGame: _showNewGameFlow,
                          onUndo: _controller.undo,
                          onHint: _controller.requestHint,
                          onDeal: _controller.dealFromStock,
                          onAchievements: _showAchievementSheet,
                          onMenu: _showModeMenu,
                          onTools: _showToolInventory,
                          statusText: _controller.statusMessage,
                          secretStatus: _secretStatus,
                          onTitleTap: _handleTitleTap,
                        );

                        final sidePanel = _SidePanel(
                          state: state,
                          progress: progress,
                          skin: skin,
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
                                  skin: skin,
                                  onPlayAgain: _showNewGameFlow,
                                  onShowAchievements: _showAchievementSheet,
                                  onBackToMenu: _openMenu,
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
                                    skin: skin,
                                  ),
                                ),
                              ),
                            if (_showMenu)
                              Positioned.fill(
                                child: _StartMenuOverlay(
                                  controller: _controller,
                                  skin: skin,
                                  onContinue: _resumeGame,
                                  onClassic: () => _showMenuAction(
                                    GameMode.classic,
                                  ),
                                  onRogue: () => _showMenuAction(GameMode.rogue),
                                  onCollectionStudio: _showCollectionStudio,
                                  onAchievements: _showAchievementsFromMenu,
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
    required this.skin,
    required this.canUndo,
    required this.canDeal,
    required this.onNewGame,
    required this.onUndo,
    required this.onHint,
    required this.onDeal,
    required this.onAchievements,
    required this.onMenu,
    required this.onTools,
    required this.statusText,
    required this.secretStatus,
    required this.onTitleTap,
  });

  final SpiderGameState state;
  final PlayerProgress progress;
  final SkinBundle skin;
  final bool canUndo;
  final bool canDeal;
  final Future<void> Function() onNewGame;
  final Future<void> Function() onUndo;
  final Future<void> Function() onHint;
  final Future<void> Function() onDeal;
  final Future<void> Function() onAchievements;
  final Future<void> Function() onMenu;
  final Future<void> Function() onTools;
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
                        color: _Palette.paperSoft.withValues(alpha: 0.92),
                      ),
                    ),
                  ],
                ),
              ),
              _InfoPill(label: '当前模式', value: state.gameMode.label),
              _InfoPill(label: '等级', value: 'Lv.${progress.level}'),
              _InfoPill(label: '积分', value: '${progress.coins}'),
              _InfoPill(label: '连胜', value: '${progress.winStreak}'),
            ],
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _ActionButton(
                label: '菜单',
                icon: Icons.home_rounded,
                onPressed: onMenu,
              ),
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
                label: '工具',
                icon: Icons.inventory_2_rounded,
                onPressed: onTools,
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
            duration: Duration(
              milliseconds: (260 * skin.motion.speedMultiplier).round(),
            ),
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
    required this.skin,
    required this.onAchievements,
    required this.statusText,
  });

  final SpiderGameState state;
  final PlayerProgress progress;
  final SkinBundle skin;
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
            title: 'Meta 进度',
            subtitle: '积分用于购买道具和皮肤，经验会持续提升等级',
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _MiniBadge(label: 'Lv.${progress.level}'),
              _MiniBadge(label: '积分 ${progress.coins}'),
              _MiniBadge(label: '经验 ${progress.xpIntoLevel}/240'),
              _MiniBadge(label: state.gameMode.label),
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
          if (state.isRogue && state.rogueBoonIds.isNotEmpty) ...[
            const SizedBox(height: 18),
            const _SectionTitle(
              title: '远征流派',
              subtitle: '当前肉鸽局已经拿到的遗物组合',
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final boonId in state.rogueBoonIds)
                  _MiniBadge(label: rogueBoonById[boonId]?.title ?? boonId),
              ],
            ),
          ],
          const SizedBox(height: 18),
          const _SectionTitle(
            title: '工具库存',
            subtitle: '工坊购买的辅助道具会显示在这里，对局内可从顶部工具按钮使用',
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: toolCatalog
                .where((tool) => progress.toolChargesFor(tool.id) > 0)
                .map(
                  (tool) => _MiniBadge(
                    label: '${tool.title} × ${progress.toolChargesFor(tool.id)}',
                  ),
                )
                .toList()
              ..addAll(
                progress.toolCharges.values.every((value) => value == 0)
                    ? const [_MiniBadge(label: '暂无随身道具')]
                    : const [],
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
    required this.skin,
    required this.selection,
    required this.hint,
    required this.hintPulseToken,
    required this.onCardTap,
    required this.onCardLongPress,
    required this.onColumnTap,
    required this.onDealFromStock,
  });

  final SpiderGameState state;
  final SkinBundle skin;
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
                    skin: skin,
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
                                  skin: skin,
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
                                        skin: skin,
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
    required this.skin,
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
  final SkinBundle skin;
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
          ? Duration(milliseconds: (1200 * skin.motion.speedMultiplier).round())
          : const Duration(milliseconds: 1),
      builder: (context, value, _) {
        final pulse = targetHint
            ? math.sin(value * math.pi) * skin.motion.pulseScale
            : 0.0;
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
                          skin.board.accent,
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
                          color: skin.board.accent.withValues(
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
                          skin: skin,
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
    required this.skin,
    required this.width,
    required this.selected,
    required this.hintSource,
    required this.hintPulseToken,
  });

  final SpiderCard card;
  final SkinBundle skin;
  final double width;
  final bool selected;
  final bool hintSource;
  final int hintPulseToken;

  @override
  Widget build(BuildContext context) {
    final height = width * 1.42;
    final radius = BorderRadius.circular(width * 0.16);
    final accent = selected
        ? skin.board.accent
        : hintSource
        ? _Palette.paper
        : null;

    return TweenAnimationBuilder<double>(
      key: ValueKey('card-${card.id}-$hintPulseToken-$hintSource-$selected'),
      tween: Tween(begin: 0, end: 1),
      duration: hintSource
          ? Duration(milliseconds: (1100 * skin.motion.speedMultiplier).round())
          : const Duration(milliseconds: 1),
      builder: (context, value, _) {
        final pulse = hintSource
            ? math.sin(value * math.pi) * skin.motion.pulseScale
            : 0.0;
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
                  ? LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [skin.card.faceStart, skin.card.faceEnd],
                    )
                  : LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [skin.card.backStart, skin.card.backEnd],
                    ),
            ),
            child: card.faceUp
                ? _FaceUpCard(card: card, skin: skin)
                : _FaceDownCard(
                    width: width,
                    accent: accent != null,
                    skin: skin,
                  ),
          ),
        );
      },
    );
  }
}

class _FaceUpCard extends StatelessWidget {
  const _FaceUpCard({required this.card, required this.skin});

  final SpiderCard card;
  final SkinBundle skin;

  @override
  Widget build(BuildContext context) {
    final color = card.suit.isRed
        ? _Palette.berry
        : skin.card.symbolTint;
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
  const _FaceDownCard({
    required this.width,
    required this.accent,
    required this.skin,
  });

  final double width;
  final bool accent;
  final SkinBundle skin;

  @override
  Widget build(BuildContext context) {
    final border = accent
        ? skin.board.accent
        : Colors.white.withValues(alpha: 0.22);
    return Padding(
      padding: const EdgeInsets.all(7),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(width * 0.12),
          border: Border.all(color: border),
          gradient: RadialGradient(
            colors: [skin.card.backStart, skin.card.backEnd],
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
    required this.skin,
    required this.width,
    required this.height,
    required this.groupsRemaining,
    required this.highlighted,
    required this.pulseToken,
    required this.enabled,
    required this.onTap,
  });

  final SkinBundle skin;
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
        ? skin.board.accent
        : Colors.white.withValues(alpha: 0.22);
    return TweenAnimationBuilder<double>(
      key: ValueKey('stock-$pulseToken-$highlighted-$groupsRemaining'),
      tween: Tween(begin: 0, end: 1),
      duration: highlighted
          ? Duration(milliseconds: (1200 * skin.motion.speedMultiplier).round())
          : const Duration(milliseconds: 1),
      builder: (context, value, _) {
        final pulse = highlighted
            ? math.sin(value * math.pi) * skin.motion.pulseScale
            : 0.0;
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
                              skin: skin,
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
    required this.skin,
    required this.onPlayAgain,
    required this.onShowAchievements,
    required this.onBackToMenu,
  });

  final SpiderGameState state;
  final SkinBundle skin;
  final Future<void> Function() onPlayAgain;
  final Future<void> Function() onShowAchievements;
  final VoidCallback onBackToMenu;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: skin.board.tertiary.withValues(alpha: 0.58),
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
                  '${state.gameMode.label} · ${state.difficulty.label} 已完成。你收走了全部 8 组顺子。',
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
                    FilledButton.tonalIcon(
                      onPressed: onBackToMenu,
                      icon: const Icon(Icons.home_rounded),
                      label: const Text('返回菜单'),
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

class _StartMenuOverlay extends StatelessWidget {
  const _StartMenuOverlay({
    required this.controller,
    required this.skin,
    required this.onContinue,
    required this.onClassic,
    required this.onRogue,
    required this.onCollectionStudio,
    required this.onAchievements,
  });

  final SpiderController controller;
  final SkinBundle skin;
  final VoidCallback onContinue;
  final Future<void> Function() onClassic;
  final Future<void> Function() onRogue;
  final Future<void> Function() onCollectionStudio;
  final Future<void> Function() onAchievements;

  @override
  Widget build(BuildContext context) {
    final progress = controller.progress;
    final state = controller.state;
    return Container(
      color: skin.board.tertiary.withValues(alpha: 0.72),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1180),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: _Panel(
              padding: const EdgeInsets.all(24),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxWidth < 880;
                  final hero = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Silken Spider',
                        style: Theme.of(context).textTheme.displayLarge?.copyWith(
                              fontSize: compact ? 54 : 72,
                              height: 0.92,
                              letterSpacing: 0.3,
                            ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        '把经典模式、积分成长、道具商店、皮肤系统和肉鸽远征织进同一张牌桌。',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: _Palette.paperSoft,
                              height: 1.45,
                            ),
                      ),
                      const SizedBox(height: 18),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          _MiniBadge(label: 'Lv.${progress.level}'),
                          _MiniBadge(label: '积分 ${progress.coins}'),
                          _MiniBadge(label: '经典 ${progress.winsForMode(GameMode.classic)} 胜'),
                          _MiniBadge(label: '远征 ${progress.winsForMode(GameMode.rogue)} 胜'),
                        ],
                      ),
                      const SizedBox(height: 22),
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(24),
                          color: Colors.white.withValues(alpha: 0.05),
                          border: Border.all(
                            color: skin.board.accent.withValues(alpha: 0.18),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '当前存档',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              '继续牌局：${state.gameMode.label} · ${state.difficulty.label}',
                              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                    color: _Palette.paper,
                                  ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '已装备主题 ${boardThemeById[progress.equippedBoardThemeId]?.title ?? progress.equippedBoardThemeId}  ·  卡牌 ${cardSkinById[progress.equippedCardSkinId]?.title ?? progress.equippedCardSkinId}  ·  动画 ${motionSkinById[progress.equippedMotionSkinId]?.title ?? progress.equippedMotionSkinId}',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: _Palette.paperSoft,
                                    height: 1.4,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );

                  final actions = Column(
                    children: [
                      _MenuActionCard(
                        title: '继续当前牌局',
                        subtitle: '回到正在进行的 ${state.gameMode.label}，保留当前局面。',
                        icon: Icons.play_circle_fill_rounded,
                        accent: skin.board.accent,
                        onTap: onContinue,
                      ),
                      const SizedBox(height: 14),
                      _MenuActionCard(
                        title: GameMode.classic.label,
                        subtitle: GameMode.classic.subtitle,
                        icon: Icons.deck_rounded,
                        accent: const Color(0xFF8FCFB9),
                        onTap: () => unawaited(onClassic()),
                      ),
                      const SizedBox(height: 14),
                      _MenuActionCard(
                        title: GameMode.rogue.label,
                        subtitle: GameMode.rogue.subtitle,
                        icon: Icons.auto_awesome_rounded,
                        accent: const Color(0xFFE4AF69),
                        onTap: () => unawaited(onRogue()),
                      ),
                      const SizedBox(height: 14),
                      _MenuActionCard(
                        title: '工坊与皮肤',
                        subtitle: '购买道具、解锁主题、切换卡牌与动画风格。',
                        icon: Icons.storefront_rounded,
                        accent: const Color(0xFFB5C7F5),
                        onTap: () => unawaited(onCollectionStudio()),
                      ),
                      const SizedBox(height: 14),
                      _MenuActionCard(
                        title: '成就与战绩',
                        subtitle: '查看长期目标与当前存档的胜场进度。',
                        icon: Icons.workspace_premium_rounded,
                        accent: const Color(0xFFD395A7),
                        onTap: () => unawaited(onAchievements()),
                      ),
                    ],
                  );

                  if (compact) {
                    return SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          hero,
                          const SizedBox(height: 20),
                          actions,
                        ],
                      ),
                    );
                  }

                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 10, child: hero),
                      const SizedBox(width: 20),
                      Expanded(flex: 9, child: actions),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MenuActionCard extends StatelessWidget {
  const _MenuActionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(26),
      child: Ink(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(26),
          color: Colors.white.withValues(alpha: 0.06),
          border: Border.all(color: accent.withValues(alpha: 0.25)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [accent.withValues(alpha: 0.95), accent.withValues(alpha: 0.45)],
                  ),
                ),
                child: Icon(icon, color: _Palette.ink),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
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
                ),
              ),
              Icon(
                Icons.arrow_forward_rounded,
                color: accent,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CollectionStudioSheet extends StatelessWidget {
  const _CollectionStudioSheet({required this.controller});

  final SpiderController controller;

  @override
  Widget build(BuildContext context) {
    final progress = controller.progress;
    return DefaultTabController(
      length: 4,
      child: _SheetFrame(
        title: '工坊与皮肤',
        subtitle: '积分 ${progress.coins} · Lv.${progress.level} · 经验 ${progress.xpIntoLevel}/240',
        child: Column(
          children: [
            const TabBar(
              isScrollable: true,
              tabs: [
                Tab(text: '道具'),
                Tab(text: '主题'),
                Tab(text: '卡牌'),
                Tab(text: '动画'),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 520,
              child: TabBarView(
                children: [
                  _ToolStoreTab(controller: controller),
                  _BoardThemeTab(controller: controller),
                  _CardSkinTab(controller: controller),
                  _MotionSkinTab(controller: controller),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ToolInventorySheet extends StatelessWidget {
  const _ToolInventorySheet({required this.controller});

  final SpiderController controller;

  @override
  Widget build(BuildContext context) {
    return _SheetFrame(
      title: '随身道具',
      subtitle: '用积分在工坊里补货，道具不会改变规则，只提供额外辅助。',
      child: Column(
        children: [
          for (final tool in toolCatalog)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _StoreTile(
                title: tool.title,
                subtitle: tool.description,
                icon: tool.icon,
                accent: tool.accent,
                trailing: FilledButton.tonal(
                  onPressed: controller.progress.toolChargesFor(tool.id) > 0
                      ? () => controller.useTool(tool.id)
                      : null,
                  child: Text('使用 ${controller.progress.toolChargesFor(tool.id)}'),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ToolStoreTab extends StatelessWidget {
  const _ToolStoreTab({required this.controller});

  final SpiderController controller;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      itemCount: toolCatalog.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final tool = toolCatalog[index];
        final progress = controller.progress;
        final locked = progress.level < tool.unlockLevel;
        final affordable = progress.coins >= tool.cost;
        return _StoreTile(
          title: tool.title,
          subtitle:
              '${tool.description}\nLv.${tool.unlockLevel} 解锁 · ${tool.cost} 积分 · 已拥有 ${progress.toolChargesFor(tool.id)}',
          icon: tool.icon,
          accent: tool.accent,
          trailing: FilledButton.tonal(
            onPressed: locked || !affordable
                ? null
                : () => controller.purchaseTool(tool.id),
            child: Text(locked ? 'Lv.${tool.unlockLevel}' : '购买'),
          ),
        );
      },
    );
  }
}

class _BoardThemeTab extends StatelessWidget {
  const _BoardThemeTab({required this.controller});

  final SpiderController controller;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      itemCount: boardThemesCatalog.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final item = boardThemesCatalog[index];
        final progress = controller.progress;
        final owned = progress.ownedBoardThemeIds.contains(item.id);
        final equipped = progress.equippedBoardThemeId == item.id;
        return _StoreTile(
          title: item.title,
          subtitle:
              '${item.description}\nLv.${item.unlockLevel} 解锁 · ${item.cost} 积分',
          icon: Icons.palette_rounded,
          accent: item.accent,
          trailing: _ownershipButton(
            owned: owned,
            equipped: equipped,
            locked: progress.level < item.unlockLevel,
            affordable: progress.coins >= item.cost,
            onBuy: () => controller.purchaseBoardTheme(item.id),
            onEquip: () => controller.equipBoardTheme(item.id),
            unlockLevel: item.unlockLevel,
          ),
        );
      },
    );
  }
}

class _CardSkinTab extends StatelessWidget {
  const _CardSkinTab({required this.controller});

  final SpiderController controller;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      itemCount: cardSkinsCatalog.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final item = cardSkinsCatalog[index];
        final progress = controller.progress;
        final owned = progress.ownedCardSkinIds.contains(item.id);
        final equipped = progress.equippedCardSkinId == item.id;
        return _StoreTile(
          title: item.title,
          subtitle:
              '${item.description}\nLv.${item.unlockLevel} 解锁 · ${item.cost} 积分',
          icon: Icons.style_rounded,
          accent: item.symbolTint,
          trailing: _ownershipButton(
            owned: owned,
            equipped: equipped,
            locked: progress.level < item.unlockLevel,
            affordable: progress.coins >= item.cost,
            onBuy: () => controller.purchaseCardSkin(item.id),
            onEquip: () => controller.equipCardSkin(item.id),
            unlockLevel: item.unlockLevel,
          ),
        );
      },
    );
  }
}

class _MotionSkinTab extends StatelessWidget {
  const _MotionSkinTab({required this.controller});

  final SpiderController controller;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      itemCount: motionSkinsCatalog.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final item = motionSkinsCatalog[index];
        final progress = controller.progress;
        final owned = progress.ownedMotionSkinIds.contains(item.id);
        final equipped = progress.equippedMotionSkinId == item.id;
        return _StoreTile(
          title: item.title,
          subtitle:
              '${item.description}\nLv.${item.unlockLevel} 解锁 · ${item.cost} 积分 · 速度 x${item.speedMultiplier.toStringAsFixed(2)}',
          icon: Icons.motion_photos_auto_rounded,
          accent: const Color(0xFFA9C1F5),
          trailing: _ownershipButton(
            owned: owned,
            equipped: equipped,
            locked: progress.level < item.unlockLevel,
            affordable: progress.coins >= item.cost,
            onBuy: () => controller.purchaseMotionSkin(item.id),
            onEquip: () => controller.equipMotionSkin(item.id),
            unlockLevel: item.unlockLevel,
          ),
        );
      },
    );
  }
}

Widget _ownershipButton({
  required bool owned,
  required bool equipped,
  required bool locked,
  required bool affordable,
  required Future<void> Function() onBuy,
  required Future<void> Function() onEquip,
  required int unlockLevel,
}) {
  if (equipped) {
    return const FilledButton.tonal(
      onPressed: null,
      child: Text('已装备'),
    );
  }

  if (owned) {
    return FilledButton.tonal(
      onPressed: onEquip,
      child: const Text('装备'),
    );
  }

  return FilledButton.tonal(
    onPressed: locked || !affordable ? null : onBuy,
    child: Text(locked ? 'Lv.$unlockLevel' : '购买'),
  );
}

class _StoreTile extends StatelessWidget {
  const _StoreTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.trailing,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: Colors.white.withValues(alpha: 0.05),
        border: Border.all(color: accent.withValues(alpha: 0.22)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [accent.withValues(alpha: 0.95), accent.withValues(alpha: 0.4)],
              ),
            ),
            child: Icon(icon, color: _Palette.ink),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
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
                        height: 1.45,
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          trailing,
        ],
      ),
    );
  }
}

class _RogueBoonOptionTile extends StatelessWidget {
  const _RogueBoonOptionTile({
    required this.definition,
    required this.selected,
    required this.onTap,
  });

  final RogueBoonDefinition definition;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Ink(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: selected
                ? _Palette.brass
                : Colors.white.withValues(alpha: 0.14),
            width: selected ? 2 : 1,
          ),
          color: Colors.white.withValues(alpha: selected ? 0.09 : 0.04),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [Color(0xFFDAB06A), Color(0xFF8D642A)],
                  ),
                ),
                child: Icon(definition.icon, color: _Palette.ink),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      definition.title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: _Palette.paper,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${definition.family}流派 · ${definition.description}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: _Palette.paperSoft,
                            height: 1.45,
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

class _RogueDraftSheet extends StatelessWidget {
  const _RogueDraftSheet({
    required this.draft,
    required this.onChoose,
    required this.onSkip,
  });

  final RogueDraft draft;
  final Future<void> Function(String boonId) onChoose;
  final Future<void> Function() onSkip;

  @override
  Widget build(BuildContext context) {
    return _SheetFrame(
      title: draft.title,
      subtitle: draft.subtitle,
      child: Column(
        children: [
          for (final boonId in draft.optionIds)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _StoreTile(
                title: rogueBoonById[boonId]!.title,
                subtitle:
                    '${rogueBoonById[boonId]!.family}流派 · ${rogueBoonById[boonId]!.description}',
                icon: rogueBoonById[boonId]!.icon,
                accent: const Color(0xFFE2AF69),
                trailing: FilledButton(
                  onPressed: () => onChoose(boonId),
                  child: const Text('拿走'),
                ),
              ),
            ),
          const SizedBox(height: 6),
          TextButton(
            onPressed: onSkip,
            child: const Text('这次先跳过'),
          ),
        ],
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
    required this.skin,
    required this.sourceRect,
    required this.targetRect,
    required this.progress,
  });

  final SkinBundle skin;
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
      ..shader = LinearGradient(
        colors: [_Palette.paper, skin.board.accent, _Palette.paper],
      ).createShader(Rect.fromPoints(start, end))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(metric.extractPath(tail, head), silkPaint);

    final tangent = metric.getTangentForOffset(head);
    if (tangent != null) {
      final glow = Paint()
        ..color = skin.board.accent.withValues(alpha: 0.92)
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
  const _SpiderMascotRun({required this.runToken, required this.skin});

  final int runToken;
  final SkinBundle skin;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 50,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return TweenAnimationBuilder<double>(
            key: ValueKey('mascot-run-$runToken'),
            tween: Tween(begin: 0, end: 1),
            duration: Duration(
              milliseconds: (4800 * skin.motion.speedMultiplier).round(),
            ),
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
                        painter: _SpiderMascotPainter(
                          progress: value,
                          skin: skin,
                        ),
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
  const _SpiderMascotPainter({required this.progress, required this.skin});

  final double progress;
  final SkinBundle skin;

  @override
  void paint(Canvas canvas, Size size) {
    final bodyPaint = Paint()..color = _Palette.ink.withValues(alpha: 0.92);
    final glowPaint = Paint()
      ..color = skin.board.accent.withValues(alpha: 0.20)
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

    final eyePaint = Paint()..color = skin.board.accent;
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
