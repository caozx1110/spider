import 'package:flutter/material.dart';

import 'models.dart';

class ToolDefinition {
  const ToolDefinition({
    required this.id,
    required this.title,
    required this.description,
    required this.cost,
    required this.unlockLevel,
    required this.icon,
    required this.accent,
  });

  final String id;
  final String title;
  final String description;
  final int cost;
  final int unlockLevel;
  final IconData icon;
  final Color accent;
}

class RogueBoonDefinition {
  const RogueBoonDefinition({
    required this.id,
    required this.title,
    required this.description,
    required this.family,
    required this.icon,
  });

  final String id;
  final String title;
  final String description;
  final String family;
  final IconData icon;
}

class BoardThemeDefinition {
  const BoardThemeDefinition({
    required this.id,
    required this.title,
    required this.description,
    required this.cost,
    required this.unlockLevel,
    required this.primary,
    required this.secondary,
    required this.tertiary,
    required this.accent,
  });

  final String id;
  final String title;
  final String description;
  final int cost;
  final int unlockLevel;
  final Color primary;
  final Color secondary;
  final Color tertiary;
  final Color accent;
}

class CardSkinDefinition {
  const CardSkinDefinition({
    required this.id,
    required this.title,
    required this.description,
    required this.cost,
    required this.unlockLevel,
    required this.faceStart,
    required this.faceEnd,
    required this.backStart,
    required this.backEnd,
    required this.symbolTint,
  });

  final String id;
  final String title;
  final String description;
  final int cost;
  final int unlockLevel;
  final Color faceStart;
  final Color faceEnd;
  final Color backStart;
  final Color backEnd;
  final Color symbolTint;
}

class MotionSkinDefinition {
  const MotionSkinDefinition({
    required this.id,
    required this.title,
    required this.description,
    required this.cost,
    required this.unlockLevel,
    required this.speedMultiplier,
    required this.pulseScale,
  });

  final String id;
  final String title;
  final String description;
  final int cost;
  final int unlockLevel;
  final double speedMultiplier;
  final double pulseScale;
}

class SkinBundle {
  const SkinBundle({
    required this.board,
    required this.card,
    required this.motion,
  });

  final BoardThemeDefinition board;
  final CardSkinDefinition card;
  final MotionSkinDefinition motion;

  static SkinBundle fromProgress(PlayerProgress progress) {
    return SkinBundle(
      board:
          boardThemeById[progress.equippedBoardThemeId] ?? boardThemesCatalog.first,
      card: cardSkinById[progress.equippedCardSkinId] ?? cardSkinsCatalog.first,
      motion:
          motionSkinById[progress.equippedMotionSkinId] ??
          motionSkinsCatalog.first,
    );
  }
}

const toolCatalog = <ToolDefinition>[
  ToolDefinition(
    id: 'scout_lens',
    title: '侦丝透镜',
    description: '随机翻开一列顶部的暗牌，适合破局。',
    cost: 80,
    unlockLevel: 1,
    icon: Icons.visibility_rounded,
    accent: Color(0xFF87C5B4),
  ),
  ToolDefinition(
    id: 'auto_weave',
    title: '自动织线',
    description: '自动执行当前最优移动一次。',
    cost: 110,
    unlockLevel: 2,
    icon: Icons.auto_fix_high_rounded,
    accent: Color(0xFFC7A55A),
  ),
  ToolDefinition(
    id: 'royal_polish',
    title: '王庭抛光',
    description: '立即获得额外分数，适合抢更高结算。',
    cost: 140,
    unlockLevel: 3,
    icon: Icons.local_fire_department_rounded,
    accent: Color(0xFFD16A63),
  ),
  ToolDefinition(
    id: 'oracle_whisper',
    title: '蛛语低语',
    description: '免费触发一次动态提示，不增加提示负担。',
    cost: 165,
    unlockLevel: 4,
    icon: Icons.tips_and_updates_rounded,
    accent: Color(0xFF9AA7F5),
  ),
];

final toolById = <String, ToolDefinition>{
  for (final tool in toolCatalog) tool.id: tool,
};

const rogueBoonCatalog = <RogueBoonDefinition>[
  RogueBoonDefinition(
    id: 'golden_fang',
    title: '金牙纺锤',
    description: '每次收束完整顺子额外获得 60 分。',
    family: '收束',
    icon: Icons.workspace_premium_rounded,
  ),
  RogueBoonDefinition(
    id: 'veil_lifter',
    title: '揭幕蛛丝',
    description: '每次翻开暗牌额外获得 28 分。',
    family: '揭示',
    icon: Icons.remove_red_eye_rounded,
  ),
  RogueBoonDefinition(
    id: 'ember_glass',
    title: '余烬沙漏',
    description: '每次从库存发牌后返还 18 分。',
    family: '发牌',
    icon: Icons.hourglass_top_rounded,
  ),
  RogueBoonDefinition(
    id: 'oracle_hush',
    title: '静默神谕',
    description: '肉鸽模式中的提示不再计入提示次数。',
    family: '信息',
    icon: Icons.psychology_alt_rounded,
  ),
  RogueBoonDefinition(
    id: 'fortune_nest',
    title: '幸运巢室',
    description: '结算时获得的积分与经验提升 35%。',
    family: '结算',
    icon: Icons.savings_rounded,
  ),
  RogueBoonDefinition(
    id: 'patient_web',
    title: '耐心蛛网',
    description: '每进行 12 次移动，额外获得 24 分。',
    family: '节奏',
    icon: Icons.timeline_rounded,
  ),
];

final rogueBoonById = <String, RogueBoonDefinition>{
  for (final boon in rogueBoonCatalog) boon.id: boon,
};

const boardThemesCatalog = <BoardThemeDefinition>[
  BoardThemeDefinition(
    id: 'verdant',
    title: '苍翠牌桌',
    description: '默认主题，适合长时间游玩。',
    cost: 0,
    unlockLevel: 1,
    primary: Color(0xFF1D6759),
    secondary: Color(0xFF154B41),
    tertiary: Color(0xFF0A231E),
    accent: Color(0xFFC49A52),
  ),
  BoardThemeDefinition(
    id: 'ember',
    title: '余烬歌剧院',
    description: '深红与铜金混合的戏剧舞台。',
    cost: 220,
    unlockLevel: 2,
    primary: Color(0xFF6E2D29),
    secondary: Color(0xFF47201E),
    tertiary: Color(0xFF1B1110),
    accent: Color(0xFFE3A85B),
  ),
  BoardThemeDefinition(
    id: 'moonlit',
    title: '月汐蓝厅',
    description: '偏冷色的月夜主题，适合静态布局。',
    cost: 260,
    unlockLevel: 3,
    primary: Color(0xFF395C87),
    secondary: Color(0xFF223A57),
    tertiary: Color(0xFF0F1A2B),
    accent: Color(0xFFB4D2F9),
  ),
  BoardThemeDefinition(
    id: 'opal',
    title: '蛋白晨雾',
    description: '更明亮、更轻盈的一套牌桌底色。',
    cost: 320,
    unlockLevel: 5,
    primary: Color(0xFF7F948A),
    secondary: Color(0xFF5C726A),
    tertiary: Color(0xFF24342F),
    accent: Color(0xFFF1D8A5),
  ),
];

final boardThemeById = <String, BoardThemeDefinition>{
  for (final item in boardThemesCatalog) item.id: item,
};

const cardSkinsCatalog = <CardSkinDefinition>[
  CardSkinDefinition(
    id: 'parchment',
    title: '羊皮卷',
    description: '默认牌面，清晰耐看。',
    cost: 0,
    unlockLevel: 1,
    faceStart: Color(0xFFFFFCF4),
    faceEnd: Color(0xFFF2E6C9),
    backStart: Color(0xFF285248),
    backEnd: Color(0xFF102120),
    symbolTint: Color(0xFF1A1714),
  ),
  CardSkinDefinition(
    id: 'obsidian',
    title: '曜石描金',
    description: '深色牌背配金属边缘，更锐利。',
    cost: 180,
    unlockLevel: 2,
    faceStart: Color(0xFFF6F1E5),
    faceEnd: Color(0xFFDCCAA1),
    backStart: Color(0xFF2E3141),
    backEnd: Color(0xFF12131C),
    symbolTint: Color(0xFFB68B4C),
  ),
  CardSkinDefinition(
    id: 'auric',
    title: '鎏金制图',
    description: '牌面更亮，适合搭配暖色主题。',
    cost: 260,
    unlockLevel: 4,
    faceStart: Color(0xFFFFF7DD),
    faceEnd: Color(0xFFF0D28A),
    backStart: Color(0xFF6B4023),
    backEnd: Color(0xFF2B160B),
    symbolTint: Color(0xFF4A2B18),
  ),
];

final cardSkinById = <String, CardSkinDefinition>{
  for (final item in cardSkinsCatalog) item.id: item,
};

const motionSkinsCatalog = <MotionSkinDefinition>[
  MotionSkinDefinition(
    id: 'silk',
    title: '丝滑',
    description: '默认过渡，偏柔和。',
    cost: 0,
    unlockLevel: 1,
    speedMultiplier: 1,
    pulseScale: 1,
  ),
  MotionSkinDefinition(
    id: 'quicksilver',
    title: '流银',
    description: '更利落，反馈更快。',
    cost: 140,
    unlockLevel: 2,
    speedMultiplier: 0.8,
    pulseScale: 0.9,
  ),
  MotionSkinDefinition(
    id: 'dream',
    title: '梦潮',
    description: '动画更悠长，提示更显眼。',
    cost: 220,
    unlockLevel: 4,
    speedMultiplier: 1.2,
    pulseScale: 1.15,
  ),
];

final motionSkinById = <String, MotionSkinDefinition>{
  for (final item in motionSkinsCatalog) item.id: item,
};
