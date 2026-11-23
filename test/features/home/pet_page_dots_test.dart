import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pet_health_tracker/features/home/widgets/pet_page_dots.dart';

void main() {
  Future<List<int>> pumpDots(
    WidgetTester tester, {
    required int petCount,
    required int currentIndex,
  }) async {
    final List<int> chosen = <int>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: PetPageDots(
              petCount: petCount,
              currentIndex: currentIndex,
              onSelected: chosen.add,
            ),
          ),
        ),
      ),
    );
    return chosen;
  }

  testWidgets('tapping a dot jumps to that pet', (WidgetTester tester) async {
    final List<int> chosen = await pumpDots(tester, petCount: 4, currentIndex: 0);
    await tester.tap(find.byKey(const ValueKey<String>('pet-dot-2')));
    expect(chosen, <int>[2]);
  });

  testWidgets('holding the dots and sliding scrubs through pets', (
    WidgetTester tester,
  ) async {
    final List<int> chosen = await pumpDots(tester, petCount: 5, currentIndex: 0);

    final Offset start = tester.getCenter(
      find.byKey(const ValueKey<String>('pet-dot-0')),
    );
    final TestGesture gesture = await tester.startGesture(start);
    // Long press engages the scrubber.
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));

    // Slide two dots to the right.
    await gesture.moveBy(const Offset(28, 0));
    await tester.pump();
    await gesture.moveBy(const Offset(28, 0));
    await tester.pump();
    await gesture.up();
    await tester.pump();

    expect(chosen, isNotEmpty);
    expect(chosen.last, greaterThan(0));
  });

  testWidgets('one pet shows no dots', (WidgetTester tester) async {
    await pumpDots(tester, petCount: 1, currentIndex: 0);
    expect(find.byType(PetPageDots), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('pet-dot-0')), findsNothing);
  });
}
