import 'dart:math';

import 'models.dart';

class SpiderEngine {
  const SpiderEngine._();

  static SpiderGameState newGame(
    SpiderDifficulty difficulty, {
    Random? random,
  }) {
    final generator = random ?? Random();
    final deck = _buildDeck(difficulty)..shuffle(generator);
    final tableau = List<List<SpiderCard>>.generate(10, (_) => <SpiderCard>[]);

    for (var columnIndex = 0; columnIndex < tableau.length; columnIndex++) {
      final cardsToDeal = columnIndex < 4 ? 6 : 5;
      for (var cardIndex = 0; cardIndex < cardsToDeal; cardIndex++) {
        final rawCard = deck.removeLast();
        tableau[columnIndex].add(
          rawCard.copyWith(faceUp: cardIndex == cardsToDeal - 1),
        );
      }
    }

    return SpiderGameState(
      difficulty: difficulty,
      tableau: tableau,
      stock: deck,
      completedRuns: 0,
      moves: 0,
      score: 500,
      undoCount: 0,
      stockDealsUsed: 0,
      hiddenCardsRevealed: 0,
      hintsUsed: 0,
      sequencesCompletedThisGame: 0,
      elapsedSeconds: 0,
    );
  }

  static bool canDealFromStock(SpiderGameState state) {
    return state.stock.length >= 10 &&
        state.tableau.every((column) => column.isNotEmpty);
  }

  static bool canSelectStack(
    SpiderGameState state,
    int columnIndex,
    int startIndex,
  ) {
    if (columnIndex < 0 || columnIndex >= state.tableau.length) {
      return false;
    }

    final column = state.tableau[columnIndex];
    if (startIndex < 0 || startIndex >= column.length) {
      return false;
    }

    final selected = column[startIndex];
    if (!selected.faceUp) {
      return false;
    }

    for (var index = startIndex; index < column.length - 1; index++) {
      final current = column[index];
      final next = column[index + 1];
      if (!next.faceUp ||
          current.suit != next.suit ||
          current.rank != next.rank + 1) {
        return false;
      }
    }

    return true;
  }

  static SpiderGameState? moveStack(
    SpiderGameState state,
    int fromColumn,
    int fromIndex,
    int toColumn,
  ) {
    if (fromColumn == toColumn ||
        !canSelectStack(state, fromColumn, fromIndex)) {
      return null;
    }

    final source = state.tableau[fromColumn];
    final target = state.tableau[toColumn];
    final moving = source.sublist(fromIndex);

    if (!_canPlaceStack(moving, target)) {
      return null;
    }

    final tableau = _cloneTableau(state.tableau);
    tableau[fromColumn] = List<SpiderCard>.of(source.take(fromIndex));
    tableau[toColumn] = List<SpiderCard>.of(target)..addAll(moving);

    var revealedCards = 0;
    if (tableau[fromColumn].isNotEmpty && !tableau[fromColumn].last.faceUp) {
      final flipped = tableau[fromColumn].removeLast();
      tableau[fromColumn].add(flipped.copyWith(faceUp: true));
      revealedCards++;
    }

    final collapsed = _collapseRuns(tableau);
    final nextScore = max(0, state.score - 1 + collapsed.runsRemoved * 100);

    return state.copyWith(
      tableau: collapsed.tableau,
      completedRuns: state.completedRuns + collapsed.runsRemoved,
      moves: state.moves + 1,
      score: nextScore,
      hiddenCardsRevealed:
          state.hiddenCardsRevealed + revealedCards + collapsed.revealedCards,
      sequencesCompletedThisGame:
          state.sequencesCompletedThisGame + collapsed.runsRemoved,
    );
  }

  static SpiderGameState? dealFromStock(SpiderGameState state) {
    if (!canDealFromStock(state)) {
      return null;
    }

    final stock = List<SpiderCard>.of(state.stock);
    final tableau = _cloneTableau(state.tableau);

    for (var columnIndex = 0; columnIndex < tableau.length; columnIndex++) {
      final dealtCard = stock.removeLast().copyWith(faceUp: true);
      tableau[columnIndex].add(dealtCard);
    }

    final collapsed = _collapseRuns(tableau);
    final nextScore = max(0, state.score - 1 + collapsed.runsRemoved * 100);

    return state.copyWith(
      tableau: collapsed.tableau,
      stock: stock,
      completedRuns: state.completedRuns + collapsed.runsRemoved,
      moves: state.moves + 1,
      score: nextScore,
      stockDealsUsed: state.stockDealsUsed + 1,
      hiddenCardsRevealed: state.hiddenCardsRevealed + collapsed.revealedCards,
      sequencesCompletedThisGame:
          state.sequencesCompletedThisGame + collapsed.runsRemoved,
    );
  }

  static MoveHint? findHint(SpiderGameState state) {
    MoveHint? bestHint;
    var bestScore = -1 << 20;

    for (
      var sourceColumn = 0;
      sourceColumn < state.tableau.length;
      sourceColumn++
    ) {
      final column = state.tableau[sourceColumn];
      for (var startIndex = 0; startIndex < column.length; startIndex++) {
        if (!canSelectStack(state, sourceColumn, startIndex)) {
          continue;
        }

        final moving = column.sublist(startIndex);
        for (
          var targetColumn = 0;
          targetColumn < state.tableau.length;
          targetColumn++
        ) {
          if (targetColumn == sourceColumn) {
            continue;
          }

          final target = state.tableau[targetColumn];
          if (!_canPlaceStack(moving, target)) {
            continue;
          }

          var score = 0;
          if (target.isEmpty) {
            score -= 20;
          } else {
            score += 40;
            if (target.last.suit == moving.first.suit) {
              score += 35;
            }
          }

          score += moving.length * 3;

          if (startIndex > 0 && !column[startIndex - 1].faceUp) {
            score += 50;
          }

          if (_wouldCreateLongerRun(moving, target)) {
            score += 30;
          }

          if (score > bestScore) {
            bestScore = score;
            bestHint = MoveHint.move(
              fromColumn: sourceColumn,
              fromIndex: startIndex,
              toColumn: targetColumn,
            );
          }
        }
      }
    }

    if (bestHint != null) {
      return bestHint;
    }

    if (canDealFromStock(state)) {
      return const MoveHint.deal();
    }

    return null;
  }

  static List<List<SpiderCard>> _cloneTableau(List<List<SpiderCard>> tableau) {
    return tableau.map((column) => List<SpiderCard>.of(column)).toList();
  }

  static bool _canPlaceStack(List<SpiderCard> moving, List<SpiderCard> target) {
    if (moving.isEmpty) {
      return false;
    }

    if (target.isEmpty) {
      return true;
    }

    return target.last.faceUp && target.last.rank == moving.first.rank + 1;
  }

  static bool _wouldCreateLongerRun(
    List<SpiderCard> moving,
    List<SpiderCard> target,
  ) {
    if (target.isEmpty) {
      return false;
    }

    if (target.last.suit != moving.first.suit) {
      return false;
    }

    return target.last.rank == moving.first.rank + 1;
  }

  static _CollapseResult _collapseRuns(List<List<SpiderCard>> tableau) {
    var runsRemoved = 0;
    var revealedCards = 0;

    for (var columnIndex = 0; columnIndex < tableau.length; columnIndex++) {
      final column = List<SpiderCard>.of(tableau[columnIndex]);
      while (column.length >= 13 &&
          _isCompleteRun(column.sublist(column.length - 13))) {
        column.removeRange(column.length - 13, column.length);
        runsRemoved++;
        if (column.isNotEmpty && !column.last.faceUp) {
          final flipped = column.removeLast();
          column.add(flipped.copyWith(faceUp: true));
          revealedCards++;
        }
      }
      tableau[columnIndex] = column;
    }

    return _CollapseResult(
      tableau: tableau,
      runsRemoved: runsRemoved,
      revealedCards: revealedCards,
    );
  }

  static bool _isCompleteRun(List<SpiderCard> cards) {
    if (cards.length != 13 || cards.first.rank != 13 || cards.last.rank != 1) {
      return false;
    }

    for (var index = 0; index < cards.length - 1; index++) {
      final current = cards[index];
      final next = cards[index + 1];
      if (!current.faceUp ||
          !next.faceUp ||
          current.suit != next.suit ||
          current.rank != next.rank + 1) {
        return false;
      }
    }

    return true;
  }

  static List<SpiderCard> _buildDeck(SpiderDifficulty difficulty) {
    final deckSuits = switch (difficulty) {
      SpiderDifficulty.oneSuit => List<SpiderSuit>.filled(8, SpiderSuit.spades),
      SpiderDifficulty.twoSuits => <SpiderSuit>[
        ...List<SpiderSuit>.filled(4, SpiderSuit.spades),
        ...List<SpiderSuit>.filled(4, SpiderSuit.hearts),
      ],
      SpiderDifficulty.fourSuits => <SpiderSuit>[
        SpiderSuit.spades,
        SpiderSuit.hearts,
        SpiderSuit.clubs,
        SpiderSuit.diamonds,
        SpiderSuit.spades,
        SpiderSuit.hearts,
        SpiderSuit.clubs,
        SpiderSuit.diamonds,
      ],
    };

    final deck = <SpiderCard>[];
    for (var deckIndex = 0; deckIndex < deckSuits.length; deckIndex++) {
      final suit = deckSuits[deckIndex];
      for (var rank = 1; rank <= 13; rank++) {
        deck.add(
          SpiderCard(
            id: '${difficulty.name}_${suit.name}_${rank}_$deckIndex',
            suit: suit,
            rank: rank,
            faceUp: false,
          ),
        );
      }
    }
    return deck;
  }
}

class _CollapseResult {
  const _CollapseResult({
    required this.tableau,
    required this.runsRemoved,
    required this.revealedCards,
  });

  final List<List<SpiderCard>> tableau;
  final int runsRemoved;
  final int revealedCards;
}
