import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pet_health_tracker/domain/models/pet.dart';
import 'package:pet_health_tracker/domain/models/vaccination.dart';
import 'package:pet_health_tracker/features/pets/pet_detail_screen.dart';
import 'package:pet_health_tracker/ui/kit/app_chip.dart';

import '../../data/test_support.dart';
import 'test_harness.dart';

/// 1 x 1 transparent PNG: a real decodable file so the photo layer renders an
/// `Image` rather than the fallback in the geometry tests.
const List<int> _tinyPng = <int>[
  137,
  80,
  78,
  71,
  13,
  10,
  26,
  10,
  0,
  0,
  0,
  13,
  73,
  72,
  68,
  82,
  0,
  0,
  0,
  1,
  0,
  0,
  0,
  1,
  8,
  6,
  0,
  0,
  0,
  31,
  21,
  196,
  137,
  0,
  0,
  0,
  10,
  73,
  68,
  65,
  84,
  120,
  156,
  99,
  0,
  1,
  0,
  0,
  5,
  0,
  1,
  13,
  10,
  45,
  180,
  0,
  0,
  0,
  0,
  73,
  69,
  78,
  68,
  174,
  66,
  96,
  130,
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SqliteHarness harness;

  setUp(() async {
    harness = await openHarness(seedDemo: true, inMemory: true);
    // Bella gets a real local photo so the page paints an image, not a fallback.
    final File photo = File('${harness.directory.path}/bella.png')
      ..writeAsBytesSync(_tinyPng);
    final Pet bella = (await harness.services.pets.findById(9001))!;
    await harness.services.pets.update(
      9001,
      PetDraft(
        name: bella.name,
        species: bella.species,
        breed: bella.breed,
        sex: bella.sex,
        dateOfBirth: bella.dateOfBirth,
        weightKg: bella.weightKg,
        microchip: bella.microchip,
        photoPath: photo.path,
      ),
    );
  });

  tearDown(() async {
    await harness.dispose();
  });

  Future<void> pumpPetPage(WidgetTester tester, {int petId = 9001}) async {
    usePhoneSurface(tester);
    await pumpScreen(tester, harness.services, PetDetailScreen(petId: petId));
  }

  Future<void> raiseSheet(WidgetTester tester) async {
    await tester.drag(
      find.byKey(const ValueKey<String>('pet-sheet-handle')),
      const Offset(0, -300),
    );
    await tester.pumpAndSettle();
  }

  Finder rowKey(int id) => find.byKey(ValueKey<String>('vaccine-row-$id'));

  String chipLabelOf(WidgetTester tester, int vaccineRowId) {
    final Finder chip = find.descendant(
      of: rowKey(vaccineRowId),
      matching: find.byType(AppChip),
    );
    expect(chip, findsOneWidget);
    return tester.widget<AppChip>(chip).label;
  }

  testWidgets('the photo is pinned while the sheet moves between 560 and 168', (
    WidgetTester tester,
  ) async {
    await pumpPetPage(tester);

    final Finder photoFinder = find.byKey(const ValueKey<String>('pet-photo'));
    final Finder sheetFinder = find.byKey(const ValueKey<String>('pet-sheet'));
    expect(photoFinder, findsOneWidget);
    expect(
      find.descendant(of: photoFinder, matching: find.byType(Image)),
      findsOneWidget,
      reason: 'the stored photo should be painted',
    );

    final Rect restingPhoto = tester.getRect(photoFinder);
    expect(restingPhoto.topLeft, Offset.zero);
    expect(restingPhoto.size, const Size(390, 844));

    final Rect restingSheet = tester.getRect(sheetFinder);
    expect(restingSheet.top, kPetSheetRestingTop);
    expect(restingSheet.height, 844 - kPetSheetRestingTop);

    // Resting: name, one vaccine card, no medical history, no blur.
    expect(find.text('Bella'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('pet-swipe-hint')),
      findsOneWidget,
    );
    expect(rowKey(9101), findsOneWidget);
    expect(rowKey(9102), findsNothing);
    expect(
      find.byKey(const ValueKey<String>('medical-history-section')),
      findsNothing,
    );
    expect(find.byType(ImageFiltered), findsNothing);

    await raiseSheet(tester);

    final Rect raisedPhoto = tester.getRect(photoFinder);
    final Rect raisedSheet = tester.getRect(sheetFinder);
    expect(raisedSheet.top, kPetSheetRaisedTop);
    expect(raisedSheet.height, 844 - kPetSheetRaisedTop);
    // The photo keeps the exact same rectangle and pixels (edge to edge).
    expect(raisedPhoto, restingPhoto);
    expect(
      find.byType(ImageFiltered),
      findsOneWidget,
      reason: 'the raised state blurs the same photo in place',
    );
    expect(find.byKey(const ValueKey<String>('pet-swipe-hint')), findsNothing);
    expect(rowKey(9101), findsOneWidget);
    expect(rowKey(9102), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('medical-history-section')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);

    // Tapping the handle lowers the sheet again without touching the photo.
    await tester.tap(find.byKey(const ValueKey<String>('pet-sheet-handle')));
    await tester.pumpAndSettle();
    expect(tester.getRect(sheetFinder).top, kPetSheetRestingTop);
    expect(tester.getRect(photoFinder), restingPhoto);
  });

  testWidgets('vaccine chips use the shared due rule and the saved window', (
    WidgetTester tester,
  ) async {
    late Vaccination dueSoon;
    await tester.runAsync(() async {
      dueSoon = await harness.services.vaccinations.append(
        VaccinationDraft(
          petId: 9001,
          vaccineTypeId: 7,
          vaccineName: 'Deworming',
          vaccinationDate: harness.services.today().subtract(
            const Duration(days: 80),
          ),
          nextDueDate: harness.services.today().add(const Duration(days: 10)),
          vetName: 'Dr. Cruz',
        ),
      );
    });
    await pumpPetPage(tester);
    await raiseSheet(tester);

    expect(chipLabelOf(tester, 9101), 'Overdue');
    expect(chipLabelOf(tester, 9102), 'Up to date');
    expect(chipLabelOf(tester, dueSoon.id), 'Due soon');

    // The persisted due-soon window feeds the same rule: widening it to a year
    // turns the DHPP booster (due in 120 days) into "due soon".
    await harness.services.settings.setDueSoonWindowDays(365);
    await tester.pump();
    expect(chipLabelOf(tester, 9102), 'Due soon');
    expect(tester.takeException(), isNull);
  });

  testWidgets('clinical notes have no edit or delete affordance', (
    WidgetTester tester,
  ) async {
    await pumpPetPage(tester);
    await raiseSheet(tester);

    final Finder medical = find.byKey(
      const ValueKey<String>('medical-history-section'),
    );
    expect(medical, findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('health-record-row-9201')),
      findsOneWidget,
    );
    // The append-only guarantee surfaces as "no affordance": no edit, delete,
    // swipe-to-dismiss or overflow menu anywhere in the medical history.
    expect(
      find.descendant(of: medical, matching: find.byType(IconButton)),
      findsNothing,
    );
    expect(
      find.descendant(of: medical, matching: find.byIcon(Icons.edit)),
      findsNothing,
    );
    expect(
      find.descendant(of: medical, matching: find.byIcon(Icons.delete)),
      findsNothing,
    );
    expect(
      find.descendant(of: medical, matching: find.byType(Dismissible)),
      findsNothing,
    );
    expect(
      find.descendant(
        of: medical,
        matching: find.byType(PopupMenuButton<Object?>),
      ),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('an unknown pet id shows the not-found state', (
    WidgetTester tester,
  ) async {
    await pumpPetPage(tester, petId: 424242);

    expect(find.text('Pet not found'), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('pet-photo')), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
