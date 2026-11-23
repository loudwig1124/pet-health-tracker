import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pet_health_tracker/domain/models/health_record.dart';
import 'package:pet_health_tracker/domain/models/pet.dart';
import 'package:pet_health_tracker/domain/models/vaccination.dart';
import 'package:pet_health_tracker/domain/models/vaccine_type.dart';
import 'package:pet_health_tracker/features/pets/forms/health_record_form_sheet.dart';
import 'package:pet_health_tracker/features/pets/forms/pet_form_sheet.dart';
import 'package:pet_health_tracker/features/pets/forms/vaccination_form_sheet.dart';
import 'package:pet_health_tracker/ui/kit/primary_button.dart';
import 'package:pet_health_tracker/ui/theme/app_theme.dart';

import '../../data/test_support.dart';
import 'test_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SqliteHarness harness;
  late List<VaccineType> vaccineTypes;

  setUp(() async {
    harness = await openHarness(seedDemo: true, inMemory: true);
    vaccineTypes = await harness.services.vaccineTypes.list();
  });

  tearDown(() async {
    await harness.dispose();
  });

  /// Pumps a host screen with one button that opens the sheet under test.
  Future<void> openSheet(
    WidgetTester tester,
    Future<bool?> Function(BuildContext context) open,
  ) async {
    usePhoneSurface(tester);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Builder(
            builder: (BuildContext context) => Center(
              child: PrimaryButton(
                label: 'Open',
                onPressed: () => open(context),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  Future<void> tapSave(WidgetTester tester, String key) async {
    final Finder save = find.byKey(ValueKey<String>(key));
    await tester.ensureVisible(save);
    await tester.pumpAndSettle();
    await tester.tap(save);
    await settleAsync(tester);
    await tester.pumpAndSettle();
  }

  testWidgets('pet form validates, then creates a pet', (
    WidgetTester tester,
  ) async {
    await openSheet(
      tester,
      (BuildContext context) =>
          showPetForm(context, services: harness.services),
    );

    await tapSave(tester, 'pet-form-save');

    expect(find.text('A pet needs a name'), findsOneWidget);
    expect(find.text('Pick a species'), findsOneWidget);
    expect(find.text('Weight must be greater than zero'), findsOneWidget);
    expect(
      await databaseResult(tester, () => harness.services.pets.list()),
      hasLength(2),
      reason: 'invalid drafts must not be saved',
    );

    await tester.enterText(
      find.byKey(const ValueKey<String>('pet-form-name')),
      'Tofu',
    );
    await tester.tap(find.byKey(const ValueKey<String>('pet-form-species')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cat').last);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey<String>('pet-form-weight')),
      '4.6',
    );
    await tester.enterText(
      find.byKey(const ValueKey<String>('pet-form-microchip')),
      '123456789012345',
    );
    await tester.tap(find.byKey(const ValueKey<String>('pet-form-sex-female')));
    await tester.pumpAndSettle();
    await tapSave(tester, 'pet-form-save');

    expect(find.byKey(const ValueKey<String>('pet-form-save')), findsNothing);

    final List<Pet> pets = await databaseResult(
      tester,
      () => harness.services.pets.list(),
    );
    final Pet tofu = pets.firstWhere((Pet pet) => pet.name == 'Tofu');
    expect(tofu.species, 'Cat');
    expect(tofu.sex, PetSex.female);
    expect(tofu.weightKg, 4.6);
    expect(tofu.microchip, '123456789012345');
    expect(tofu.photoPath, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('pet form edits an existing pet', (WidgetTester tester) async {
    final Pet bella = (await databaseResult(
      tester,
      () => harness.services.pets.findById(9001),
    ))!;
    await openSheet(
      tester,
      (BuildContext context) =>
          showPetForm(context, services: harness.services, existing: bella),
    );

    expect(find.text('Edit pet'), findsOneWidget);
    expect(find.text('Bella'), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey<String>('pet-form-name')),
      'Bella Rose',
    );
    await tester.tap(
      find.byKey(const ValueKey<String>('pet-form-sex-unknown')),
    );
    await tester.pumpAndSettle();
    await tapSave(tester, 'pet-form-save');

    final Pet updated = (await databaseResult(
      tester,
      () => harness.services.pets.findById(9001),
    ))!;
    expect(updated.name, 'Bella Rose');
    expect(updated.sex, PetSex.unknown);
  });

  testWidgets(
    'vaccination form prefills the interval and re-prefills by type',
    (WidgetTester tester) async {
      await openSheet(
        tester,
        (BuildContext context) => showVaccinationForm(
          context,
          services: harness.services,
          petId: 9001,
          vaccineTypes: vaccineTypes,
        ),
      );

      // Rabies interval = 12 months, dose date defaults to the fixed today.
      expect(find.text('21 Nov 2027'), findsOneWidget);

      await tester.ensureVisible(
        find.byKey(const ValueKey<String>('vaccination-form-clear-next-due')),
      );
      await tester.tap(
        find.byKey(const ValueKey<String>('vaccination-form-clear-next-due')),
      );
      await tester.pumpAndSettle();
      expect(find.text('21 Nov 2027'), findsNothing);
      expect(find.text('Not set'), findsOneWidget);

      await tester.tap(
        find.byKey(const ValueKey<String>('vaccination-form-type')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Deworming').last);
      await tester.pumpAndSettle();
      expect(find.text('21 Feb 2027'), findsOneWidget);

      await tapSave(tester, 'vaccination-form-save');
      expect(
        find.byKey(const ValueKey<String>('vaccination-form-save')),
        findsNothing,
      );

      final List<Vaccination> doses = await databaseResult(
        tester,
        () => harness.services.vaccinations.listForPet(9001),
      );
      final Vaccination stored = doses.firstWhere(
        (Vaccination dose) => dose.vaccineName == 'Deworming',
      );
      expect(stored.nextDueDate, DateTime.utc(2027, 2, 21));
      expect(stored.vaccinationDate, DateTime.utc(2026, 11, 21));
    },
  );

  testWidgets('vaccination form can save without a next due date', (
    WidgetTester tester,
  ) async {
    await openSheet(
      tester,
      (BuildContext context) => showVaccinationForm(
        context,
        services: harness.services,
        petId: 9002,
        vaccineTypes: vaccineTypes,
      ),
    );

    await tester.ensureVisible(
      find.byKey(const ValueKey<String>('vaccination-form-clear-next-due')),
    );
    await tester.tap(
      find.byKey(const ValueKey<String>('vaccination-form-clear-next-due')),
    );
    await tester.pumpAndSettle();
    await tapSave(tester, 'vaccination-form-save');

    final List<Vaccination> doses = await databaseResult(
      tester,
      () => harness.services.vaccinations.listForPet(9002),
    );
    expect(doses, hasLength(3));
    expect(
      doses.where((Vaccination dose) => dose.nextDueDate == null),
      hasLength(1),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('a clinical note needs a condition or diagnosis and appends', (
    WidgetTester tester,
  ) async {
    await openSheet(
      tester,
      (BuildContext context) => showHealthRecordForm(
        context,
        services: harness.services,
        petId: 9001,
      ),
    );

    await tapSave(tester, 'health-record-form-save');
    expect(find.text('Add a condition or a diagnosis.'), findsOneWidget);
    expect(
      await databaseResult(
        tester,
        () => harness.services.healthRecords.listForPet(9001),
      ),
      hasLength(1),
    );

    await tester.enterText(
      find.byKey(const ValueKey<String>('health-record-form-condition')),
      'Gastritis',
    );
    await tester.enterText(
      find.byKey(const ValueKey<String>('health-record-form-treatment')),
      'Bland diet for three days',
    );
    await tester.enterText(
      find.byKey(const ValueKey<String>('health-record-form-vet')),
      'Dr. Reyes',
    );
    await tapSave(tester, 'health-record-form-save');

    final List<HealthRecord> records = await databaseResult(
      tester,
      () => harness.services.healthRecords.listForPet(9001),
    );
    expect(records, hasLength(2));
    final HealthRecord latest = records.first;
    expect(latest.condition, 'Gastritis');
    expect(latest.treatment, 'Bland diet for three days');
    expect(latest.vetName, 'Dr. Reyes');
    expect(latest.recordedOn, DateTime.utc(2026, 11, 21));
    expect(tester.takeException(), isNull);
  });
}
