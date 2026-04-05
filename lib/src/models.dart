import 'dart:convert';

enum SpiderSuit { spades, hearts, clubs, diamonds }

extension SpiderSuitX on SpiderSuit {
  static SpiderSuit fromName(String name) => SpiderSuit.values.byName(name);

  bool get isRed => this == SpiderSuit.hearts || this == SpiderSuit.diamonds;

  String get label => switch (this) {
    SpiderSuit.spades => '黑桃',
    SpiderSuit.hearts => '红心',
    SpiderSuit.clubs => '梅花',
    SpiderSuit.diamonds => '方块',
  };

  String get symbol => switch (this) {
    SpiderSuit.spades => '♠',
    SpiderSuit.hearts => '♥',
    SpiderSuit.clubs => '♣',
    SpiderSuit.diamonds => '♦',
  };
}

enum SpiderDifficulty { oneSuit, twoSuits, fourSuits }

extension SpiderDifficultyX on SpiderDifficulty {
  static SpiderDifficulty fromName(String name) =>
      SpiderDifficulty.values.byName(name);

  String get label => switch (this) {
    SpiderDifficulty.oneSuit => '单花色',
    SpiderDifficulty.twoSuits => '双花色',
    SpiderDifficulty.fourSuits => '四色',
  };

  String get subtitle => switch (this) {
    SpiderDifficulty.oneSuit => '适合快速开局，容错最高',
    SpiderDifficulty.twoSuits => '平衡策略与节奏',
    SpiderDifficulty.fourSuits => '接近经典规则，最考验规划',
  };

  int get suitCount => switch (this) {
    SpiderDifficulty.oneSuit => 1,
    SpiderDifficulty.twoSuits => 2,
    SpiderDifficulty.fourSuits => 4,
  };
}

class SpiderCard {
  const SpiderCard({
    required this.id,
    required this.suit,
    required this.rank,
    required this.faceUp,
  });

  final String id;
  final SpiderSuit suit;
  final int rank;
  final bool faceUp;

  String get rankLabel => switch (rank) {
    1 => 'A',
    11 => 'J',
    12 => 'Q',
    13 => 'K',
    _ => '$rank',
  };

  SpiderCard copyWith({bool? faceUp}) {
    return SpiderCard(
      id: id,
      suit: suit,
      rank: rank,
      faceUp: faceUp ?? this.faceUp,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'suit': suit.name,
      'rank': rank,
      'faceUp': faceUp,
    };
  }

  factory SpiderCard.fromJson(Map<String, dynamic> json) {
    return SpiderCard(
      id: json['id'] as String,
      suit: SpiderSuitX.fromName(json['suit'] as String),
      rank: json['rank'] as int,
      faceUp: json['faceUp'] as bool,
    );
  }
}

class SpiderGameState {
  const SpiderGameState({
    required this.difficulty,
    required this.tableau,
    required this.stock,
    required this.completedRuns,
    required this.moves,
    required this.score,
    required this.undoCount,
    required this.stockDealsUsed,
    required this.hiddenCardsRevealed,
    required this.hintsUsed,
    required this.sequencesCompletedThisGame,
    required this.elapsedSeconds,
  });

  final SpiderDifficulty difficulty;
  final List<List<SpiderCard>> tableau;
  final List<SpiderCard> stock;
  final int completedRuns;
  final int moves;
  final int score;
  final int undoCount;
  final int stockDealsUsed;
  final int hiddenCardsRevealed;
  final int hintsUsed;
  final int sequencesCompletedThisGame;
  final int elapsedSeconds;

  int get hiddenCardCount =>
      tableau.expand((column) => column).where((card) => !card.faceUp).length;

  bool get isWin => completedRuns >= 8;

  int get stockDealsRemaining => stock.length ~/ 10;

  SpiderGameState copyWith({
    SpiderDifficulty? difficulty,
    List<List<SpiderCard>>? tableau,
    List<SpiderCard>? stock,
    int? completedRuns,
    int? moves,
    int? score,
    int? undoCount,
    int? stockDealsUsed,
    int? hiddenCardsRevealed,
    int? hintsUsed,
    int? sequencesCompletedThisGame,
    int? elapsedSeconds,
  }) {
    return SpiderGameState(
      difficulty: difficulty ?? this.difficulty,
      tableau: tableau ?? this.tableau,
      stock: stock ?? this.stock,
      completedRuns: completedRuns ?? this.completedRuns,
      moves: moves ?? this.moves,
      score: score ?? this.score,
      undoCount: undoCount ?? this.undoCount,
      stockDealsUsed: stockDealsUsed ?? this.stockDealsUsed,
      hiddenCardsRevealed: hiddenCardsRevealed ?? this.hiddenCardsRevealed,
      hintsUsed: hintsUsed ?? this.hintsUsed,
      sequencesCompletedThisGame:
          sequencesCompletedThisGame ?? this.sequencesCompletedThisGame,
      elapsedSeconds: elapsedSeconds ?? this.elapsedSeconds,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'difficulty': difficulty.name,
      'tableau': tableau
          .map((column) => column.map((card) => card.toJson()).toList())
          .toList(),
      'stock': stock.map((card) => card.toJson()).toList(),
      'completedRuns': completedRuns,
      'moves': moves,
      'score': score,
      'undoCount': undoCount,
      'stockDealsUsed': stockDealsUsed,
      'hiddenCardsRevealed': hiddenCardsRevealed,
      'hintsUsed': hintsUsed,
      'sequencesCompletedThisGame': sequencesCompletedThisGame,
      'elapsedSeconds': elapsedSeconds,
    };
  }

  String toEncodedJson() => jsonEncode(toJson());

  factory SpiderGameState.fromJson(Map<String, dynamic> json) {
    return SpiderGameState(
      difficulty: SpiderDifficultyX.fromName(json['difficulty'] as String),
      tableau: (json['tableau'] as List<dynamic>)
          .map(
            (column) => (column as List<dynamic>)
                .map(
                  (card) => SpiderCard.fromJson(card as Map<String, dynamic>),
                )
                .toList(),
          )
          .toList(),
      stock: (json['stock'] as List<dynamic>)
          .map((card) => SpiderCard.fromJson(card as Map<String, dynamic>))
          .toList(),
      completedRuns: json['completedRuns'] as int,
      moves: json['moves'] as int,
      score: json['score'] as int,
      undoCount: json['undoCount'] as int,
      stockDealsUsed: json['stockDealsUsed'] as int,
      hiddenCardsRevealed: json['hiddenCardsRevealed'] as int,
      hintsUsed: json['hintsUsed'] as int,
      sequencesCompletedThisGame: json['sequencesCompletedThisGame'] as int,
      elapsedSeconds: json['elapsedSeconds'] as int,
    );
  }
}

class SpiderSelection {
  const SpiderSelection({required this.column, required this.index});

  final int column;
  final int index;
}

enum HintKind { move, deal }

class MoveHint {
  const MoveHint.deal()
    : kind = HintKind.deal,
      fromColumn = null,
      fromIndex = null,
      toColumn = null;

  const MoveHint.move({
    required this.fromColumn,
    required this.fromIndex,
    required this.toColumn,
  }) : kind = HintKind.move;

  final HintKind kind;
  final int? fromColumn;
  final int? fromIndex;
  final int? toColumn;
}

class AchievementDefinition {
  const AchievementDefinition({
    required this.id,
    required this.title,
    required this.description,
  });

  final String id;
  final String title;
  final String description;
}

const achievementCatalog = <AchievementDefinition>[
  AchievementDefinition(
    id: 'first_win',
    title: '初次胜利',
    description: '完成任意一局蜘蛛纸牌。',
  ),
  AchievementDefinition(
    id: 'clean_hands',
    title: '干净双手',
    description: '在不使用撤销的情况下获胜。',
  ),
  AchievementDefinition(
    id: 'blind_oracle',
    title: '盲眼先知',
    description: '在不使用提示的情况下获胜。',
  ),
  AchievementDefinition(
    id: 'speedrunner',
    title: '十分钟内',
    description: '在 10 分钟内完成一局。',
  ),
  AchievementDefinition(
    id: 'triple_thread',
    title: '三线收束',
    description: '单局内至少收走 3 组完整顺子。',
  ),
  AchievementDefinition(
    id: 'one_suit_master',
    title: '单花色制胜',
    description: '在单花色难度下获胜。',
  ),
  AchievementDefinition(
    id: 'two_suit_master',
    title: '双花色制胜',
    description: '在双花色难度下获胜。',
  ),
  AchievementDefinition(
    id: 'four_suit_master',
    title: '四色制胜',
    description: '在四花色难度下获胜。',
  ),
  AchievementDefinition(
    id: 'streak_three',
    title: '连胜节奏',
    description: '达成 3 连胜。',
  ),
];

final achievementById = <String, AchievementDefinition>{
  for (final achievement in achievementCatalog) achievement.id: achievement,
};

class PlayerProgress {
  const PlayerProgress({
    required this.unlockedAchievementIds,
    required this.gamesStarted,
    required this.gamesWon,
    required this.winStreak,
    required this.bestScore,
    required this.bestTimeSeconds,
    required this.winsByDifficulty,
    required this.preferredDifficulty,
  });

  factory PlayerProgress.initial() {
    return const PlayerProgress(
      unlockedAchievementIds: <String>{},
      gamesStarted: 0,
      gamesWon: 0,
      winStreak: 0,
      bestScore: 0,
      bestTimeSeconds: 0,
      winsByDifficulty: <String, int>{},
      preferredDifficulty: SpiderDifficulty.oneSuit,
    );
  }

  final Set<String> unlockedAchievementIds;
  final int gamesStarted;
  final int gamesWon;
  final int winStreak;
  final int bestScore;
  final int bestTimeSeconds;
  final Map<String, int> winsByDifficulty;
  final SpiderDifficulty preferredDifficulty;

  int winsFor(SpiderDifficulty difficulty) =>
      winsByDifficulty[difficulty.name] ?? 0;

  PlayerProgress copyWith({
    Set<String>? unlockedAchievementIds,
    int? gamesStarted,
    int? gamesWon,
    int? winStreak,
    int? bestScore,
    int? bestTimeSeconds,
    Map<String, int>? winsByDifficulty,
    SpiderDifficulty? preferredDifficulty,
  }) {
    return PlayerProgress(
      unlockedAchievementIds:
          unlockedAchievementIds ?? this.unlockedAchievementIds,
      gamesStarted: gamesStarted ?? this.gamesStarted,
      gamesWon: gamesWon ?? this.gamesWon,
      winStreak: winStreak ?? this.winStreak,
      bestScore: bestScore ?? this.bestScore,
      bestTimeSeconds: bestTimeSeconds ?? this.bestTimeSeconds,
      winsByDifficulty: winsByDifficulty ?? this.winsByDifficulty,
      preferredDifficulty: preferredDifficulty ?? this.preferredDifficulty,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'unlockedAchievementIds': unlockedAchievementIds.toList(),
      'gamesStarted': gamesStarted,
      'gamesWon': gamesWon,
      'winStreak': winStreak,
      'bestScore': bestScore,
      'bestTimeSeconds': bestTimeSeconds,
      'winsByDifficulty': winsByDifficulty,
      'preferredDifficulty': preferredDifficulty.name,
    };
  }

  String toEncodedJson() => jsonEncode(toJson());

  factory PlayerProgress.fromJson(Map<String, dynamic> json) {
    return PlayerProgress(
      unlockedAchievementIds:
          (json['unlockedAchievementIds'] as List<dynamic>? ?? const [])
              .map((value) => value as String)
              .toSet(),
      gamesStarted: json['gamesStarted'] as int? ?? 0,
      gamesWon: json['gamesWon'] as int? ?? 0,
      winStreak: json['winStreak'] as int? ?? 0,
      bestScore: json['bestScore'] as int? ?? 0,
      bestTimeSeconds: json['bestTimeSeconds'] as int? ?? 0,
      winsByDifficulty:
          (json['winsByDifficulty'] as Map<String, dynamic>? ??
                  const <String, dynamic>{})
              .map((key, value) => MapEntry(key, value as int)),
      preferredDifficulty: SpiderDifficultyX.fromName(
        json['preferredDifficulty'] as String? ?? SpiderDifficulty.oneSuit.name,
      ),
    );
  }
}
