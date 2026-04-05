import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:spider_solitaire/src/models.dart';
import 'package:spider_solitaire/src/spider_engine.dart';

void main() {
  group('SpiderEngine.newGame', () {
    test('deals the expected opening layout', () {
      final state = SpiderEngine.newGame(
        SpiderDifficulty.oneSuit,
        random: Random(7),
      );

      expect(state.tableau.length, 10);
      expect(state.tableau[0].length, 6);
      expect(state.tableau[3].length, 6);
      expect(state.tableau[4].length, 5);
      expect(state.tableau[9].length, 5);
      expect(state.stock.length, 50);
      expect(state.tableau.every((column) => column.last.faceUp), isTrue);
      expect(
        state.tableau
            .expand((column) => column.take(column.length - 1))
            .every((card) => !card.faceUp),
        isTrue,
      );
    });
  });

  group('SpiderEngine moves', () {
    test('moving a stack reveals the next facedown card', () {
      final state = SpiderGameState(
        difficulty: SpiderDifficulty.oneSuit,
        tableau: [
          [
            _card('s0', SpiderSuit.spades, 6, false),
            _card('s1', SpiderSuit.spades, 5, true),
          ],
          [_card('t0', SpiderSuit.hearts, 6, true)],
          for (var index = 0; index < 8; index++) <SpiderCard>[],
        ],
        stock: const [],
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

      final next = SpiderEngine.moveStack(state, 0, 1, 1);

      expect(next, isNotNull);
      expect(next!.tableau[0].single.faceUp, isTrue);
      expect(next.tableau[1].last.rank, 5);
      expect(next.hiddenCardsRevealed, 1);
    });

    test('completing a full run removes it from the board', () {
      final state = SpiderGameState(
        difficulty: SpiderDifficulty.oneSuit,
        tableau: [
          const <SpiderCard>[],
          [
            for (var rank = 13; rank >= 2; rank--)
              _card('run_$rank', SpiderSuit.spades, rank, true),
          ],
          [_card('ace', SpiderSuit.spades, 1, true)],
          for (var index = 0; index < 7; index++) <SpiderCard>[],
        ],
        stock: const [],
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

      final next = SpiderEngine.moveStack(state, 2, 0, 1);

      expect(next, isNotNull);
      expect(next!.completedRuns, 1);
      expect(next.tableau[1], isEmpty);
      expect(next.sequencesCompletedThisGame, 1);
    });
  });

  group('SpiderEngine stock dealing', () {
    test('cannot deal from stock when a column is empty', () {
      final state = SpiderGameState(
        difficulty: SpiderDifficulty.oneSuit,
        tableau: [
          const <SpiderCard>[],
          for (var index = 0; index < 9; index++)
            [_card('c$index', SpiderSuit.spades, 13 - index, true)],
        ],
        stock: [
          for (var index = 0; index < 10; index++)
            _card('stock_$index', SpiderSuit.spades, (index % 13) + 1, false),
        ],
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

      expect(SpiderEngine.dealFromStock(state), isNull);
    });
  });
}

SpiderCard _card(String id, SpiderSuit suit, int rank, bool faceUp) {
  return SpiderCard(id: id, suit: suit, rank: rank, faceUp: faceUp);
}
