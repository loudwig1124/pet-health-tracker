import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pet_health_tracker/features/home/widgets/pet_page_dots.dart';

/// The dot rules from the Home spec: hidden at one pet, one dot per pet up to
/// five, then a five-to-seven dot window that shrinks with distance and keeps
/// only the current dot accent.
void main() {
  group('visiblePageDots', () {
    test('is empty for zero or one pet', () {
      expect(visiblePageDots(petCount: 0, currentIndex: 0), isEmpty);
      expect(visiblePageDots(petCount: 1, currentIndex: 0), isEmpty);
      expect(visiblePageDots(petCount: 1, currentIndex: 1), isEmpty);
    });

    test('shows exactly one dot per pet from two to five, no growth', () {
      for (int petCount = 2; petCount <= 5; petCount++) {
        for (final int current in <int>[0, petCount - 1]) {
          final List<PageDot> dots = visiblePageDots(
            petCount: petCount,
            currentIndex: current,
          );
          expect(dots, hasLength(petCount), reason: '$petCount pets');
          expect(dots.first.index, 0);
          expect(dots.last.index, petCount - 1);
          expect(dots.map((PageDot dot) => dot.size), everyElement(kDotSize));
          expect(dots.where((PageDot dot) => dot.isCurrent), hasLength(1));
          expect(
            dots.firstWhere((PageDot dot) => dot.isCurrent).index,
            current,
          );
        }
      }
    });

    test('grows from five to seven dots while travelling inward', () {
      expect(visiblePageDots(petCount: 10, currentIndex: 0), hasLength(5));
      expect(visiblePageDots(petCount: 10, currentIndex: 1), hasLength(6));
      expect(visiblePageDots(petCount: 10, currentIndex: 2), hasLength(7));
      expect(visiblePageDots(petCount: 10, currentIndex: 5), hasLength(7));
      expect(visiblePageDots(petCount: 10, currentIndex: 8), hasLength(6));
      expect(visiblePageDots(petCount: 10, currentIndex: 9), hasLength(5));
      expect(
        visiblePageDots(
          petCount: 10,
          currentIndex: 9,
        ).map((PageDot dot) => dot.index),
        <int>[5, 6, 7, 8, 9],
      );
    });

    test('shrinks each dot with its distance from the current page', () {
      final List<PageDot> dots = visiblePageDots(petCount: 10, currentIndex: 4);
      expect(dots.map((PageDot dot) => dot.index), <int>[1, 2, 3, 4, 5, 6, 7]);
      double sizeOf(int index) =>
          dots.firstWhere((PageDot dot) => dot.index == index).size;

      expect(sizeOf(4), kDotSize);
      expect(sizeOf(3), kDotSize);
      expect(sizeOf(5), kDotSize);
      expect(sizeOf(2), kShavedDotSize);
      expect(sizeOf(6), kShavedDotSize);
      expect(sizeOf(1), kSmallDotSize);
      expect(sizeOf(7), kSmallDotSize);
      expect(dots.where((PageDot dot) => dot.isCurrent).single.index, 4);
    });

    test('never grows past the pet count for exactly six pets', () {
      expect(visiblePageDots(petCount: 6, currentIndex: 0), hasLength(5));
      expect(visiblePageDots(petCount: 6, currentIndex: 1), hasLength(6));
      expect(visiblePageDots(petCount: 6, currentIndex: 3), hasLength(6));
    });

    test('has no current dot on the add-a-pet page', () {
      final List<PageDot> dots = visiblePageDots(petCount: 4, currentIndex: 4);
      expect(dots, hasLength(4));
      expect(dots.where((PageDot dot) => dot.isCurrent), isEmpty);
    });
  });

  testWidgets('tapping a dot jumps to that pet', (WidgetTester tester) async {
    int? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PetPageDots(
            petCount: 3,
            currentIndex: 0,
            onSelected: (int index) => selected = index,
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey<String>('pet-dot-2')));
    expect(selected, 2);

    await tester.tap(find.byKey(const ValueKey<String>('pet-dot-0')));
    expect(selected, 0);
  });

  testWidgets('paints no dots at one pet', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PetPageDots(petCount: 1, currentIndex: 0, onSelected: (_) {}),
        ),
      ),
    );

    expect(find.byKey(const ValueKey<String>('pet-dot-0')), findsNothing);
  });
}
