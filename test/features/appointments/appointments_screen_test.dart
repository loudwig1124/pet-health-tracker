import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pet_health_tracker/app/app_scope.dart';
import 'package:pet_health_tracker/app/navigation_requests.dart';
import 'package:pet_health_tracker/domain/models/appointment.dart';
import 'package:pet_health_tracker/domain/models/pet.dart';
import 'package:pet_health_tracker/features/appointments/appointments_screen.dart';
import 'package:pet_health_tracker/ui/format/app_formats.dart';
import 'package:pet_health_tracker/ui/kit/list_row.dart';
import 'package:pet_health_tracker/ui/kit/primary_button.dart';
import 'package:pet_health_tracker/ui/theme/app_theme.dart';

import '../../data/test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SqliteHarness harness;
  late Pet bella;
  late Pet miso;
  late Appointment futureVisit;
  late Appointment misoVisit;
  late Appointment pastScheduled;
  late Appointment completedVisit;
  late Appointment cancelledVisit;
  late Appointment noShowVisit;

  final DateTime now = fixedNow();

  Future<Appointment> createVisit({
    required int petId,
    required String clinic,
    required String purpose,
    required DateTime scheduledAt,
  }) {
    return harness.services.appointments.create(
      AppointmentDraft(
        petId: petId,
        clinicName: clinic,
        purpose: purpose,
        scheduledAt: scheduledAt,
      ),
    );
  }

  setUp(() async {
    harness = await openHarness(inMemory: true);
    bella = await harness.services.pets.create(
      PetDraft(
        name: 'Bella',
        species: 'Dog',
        sex: PetSex.female,
        dateOfBirth: DateTime.utc(2021, 3, 14),
        weightKg: 12.4,
      ),
    );
    miso = await harness.services.pets.create(
      PetDraft(
        name: 'Miso',
        species: 'Cat',
        sex: PetSex.male,
        dateOfBirth: DateTime.utc(2022, 7, 1),
        weightKg: 4.2,
      ),
    );

    futureVisit = await createVisit(
      petId: bella.id,
      clinic: 'Paws & Claws',
      purpose: 'Annual wellness check',
      scheduledAt: now.add(const Duration(days: 5)),
    );
    misoVisit = await createVisit(
      petId: miso.id,
      clinic: 'City Vet',
      purpose: 'FeLV booster',
      scheduledAt: now.add(const Duration(days: 6)),
    );
    pastScheduled = await createVisit(
      petId: bella.id,
      clinic: 'Paws & Claws',
      purpose: 'Dental cleaning',
      scheduledAt: now.subtract(const Duration(hours: 2)),
    );

    final Appointment completedDraft = await createVisit(
      petId: miso.id,
      clinic: 'Paws & Claws',
      purpose: 'Annual exam',
      scheduledAt: now.subtract(const Duration(days: 3)),
    );
    completedVisit = await harness.services.appointments.updateStatus(
      completedDraft.id,
      AppointmentStatus.completed,
      now: now,
    );

    final Appointment cancelledDraft = await createVisit(
      petId: bella.id,
      clinic: 'City Vet',
      purpose: 'Grooming consult',
      scheduledAt: now.subtract(const Duration(days: 4)),
    );
    cancelledVisit = await harness.services.appointments.updateStatus(
      cancelledDraft.id,
      AppointmentStatus.cancelled,
      now: now,
      cancelReason: 'Clinic closed',
    );

    final Appointment noShowDraft = await createVisit(
      petId: miso.id,
      clinic: 'Paws & Claws',
      purpose: 'Dental follow-up',
      scheduledAt: now.subtract(const Duration(days: 5)),
    );
    noShowVisit = await harness.services.appointments.updateStatus(
      noShowDraft.id,
      AppointmentStatus.noShow,
      now: now,
    );
  });

  tearDown(() async {
    await harness.dispose();
  });

  /// Lets the real SQLite work finish, then rebuilds the widget tree.
  Future<void> settleDatabase(WidgetTester tester) async {
    for (int attempt = 0; attempt < 6; attempt++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
    }
    await tester.pumpAndSettle();
  }

  Future<void> pumpAppointments(WidgetTester tester) async {
    await tester.pumpWidget(
      AppScope(
        services: harness.services,
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const AppointmentsScreen(),
        ),
      ),
    );
    await settleDatabase(tester);
  }

  Future<void> tapByKey(
    WidgetTester tester,
    String key, {
    bool settle = true,
  }) async {
    await tester.tap(find.byKey(ValueKey<String>(key)));
    if (settle) {
      await settleDatabase(tester);
    } else {
      await tester.pump();
    }
  }

  Future<void> clearSnackBar(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  }


  testWidgets('a write from elsewhere refreshes this already-open tab', (
    WidgetTester tester,
  ) async {
    await pumpAppointments(tester);
    // The centre action writes the visit and stays on this branch, so no tab
    // switch ever happens to refresh it.
    await tester.runAsync(
      () => harness.services.appointments.create(
        AppointmentDraft(
          petId: bella.id,
          clinicName: 'Reload Clinic',
          purpose: 'Booster follow-up',
          scheduledAt: now.add(const Duration(days: 2)),
        ),
      ),
    );
    NavigationRequests.bumpHousehold();
    await settleDatabase(tester);

    expect(find.text('Reload Clinic'), findsOneWidget);
  });

  testWidgets('the segmented control splits upcoming from past', (
    WidgetTester tester,
  ) async {
    await pumpAppointments(tester);

    expect(
      find.byKey(ValueKey<String>('appointment-card-${futureVisit.id}')),
      findsOneWidget,
    );
    expect(
      find.byKey(ValueKey<String>('appointment-card-${misoVisit.id}')),
      findsOneWidget,
    );
    expect(
      find.byKey(ValueKey<String>('appointment-card-${pastScheduled.id}')),
      findsNothing,
    );
    expect(find.text('Scheduled'), findsNWidgets(2));
    expect(
      // The separator is glued to the time with a non-breaking space.
      find.text(
        'Annual wellness check ·\u00A0${formatTimeOfDay(futureVisit.scheduledAt)}',
      ),
      findsOneWidget,
    );
    expect(
      find.text(
        formatWeekdayShort(futureVisit.scheduledAt.toLocal()).toUpperCase(),
      ),
      findsWidgets,
    );
    expect(
      find.text(formatDayOfMonth(futureVisit.scheduledAt.toLocal())),
      findsWidgets,
    );

    await tapByKey(tester, 'appointments-tab-past');

    expect(
      find.byKey(ValueKey<String>('appointment-card-${pastScheduled.id}')),
      findsOneWidget,
    );
    expect(
      find.byKey(ValueKey<String>('appointment-card-${completedVisit.id}')),
      findsOneWidget,
    );
    expect(
      find.byKey(ValueKey<String>('appointment-card-${cancelledVisit.id}')),
      findsOneWidget,
    );
    expect(
      find.byKey(ValueKey<String>('appointment-card-${noShowVisit.id}')),
      findsOneWidget,
    );
    expect(find.text('Completed'), findsOneWidget);
    expect(find.text('Cancelled'), findsOneWidget);
    expect(find.text('No-show'), findsOneWidget);
  });

  testWidgets('no-show is offered only after the appointment time', (
    WidgetTester tester,
  ) async {
    await pumpAppointments(tester);
    await tapByKey(tester, 'appointment-card-${futureVisit.id}');

    final ListRow futureNoShow = tester.widget<ListRow>(
      find.byKey(const ValueKey<String>('appointment-action-no-show')),
    );
    expect(futureNoShow.onTap, isNull);
    expect(find.text('Available after the appointment time'), findsOneWidget);
    final ListRow completeRow = tester.widget<ListRow>(
      find.byKey(const ValueKey<String>('appointment-action-complete')),
    );
    expect(completeRow.onTap, isNotNull);
    await tapByKey(tester, 'appointment-actions-dismiss');

    await tapByKey(tester, 'appointments-tab-past');
    await tapByKey(tester, 'appointment-card-${pastScheduled.id}');
    final ListRow pastNoShow = tester.widget<ListRow>(
      find.byKey(const ValueKey<String>('appointment-action-no-show')),
    );
    expect(pastNoShow.onTap, isNotNull);
    expect(find.text('The visit was missed'), findsOneWidget);
    await tapByKey(tester, 'appointment-actions-dismiss');
  });

  testWidgets('a terminal appointment offers no further transitions', (
    WidgetTester tester,
  ) async {
    await pumpAppointments(tester);
    await tapByKey(tester, 'appointments-tab-past');
    await tapByKey(tester, 'appointment-card-${completedVisit.id}');

    expect(find.text('Mark completed'), findsNothing);
    expect(find.text('Cancel appointment'), findsNothing);
    expect(find.text('Reschedule'), findsNothing);
    expect(find.text('Completed visits cannot be changed.'), findsOneWidget);
    await tapByKey(tester, 'appointment-actions-close');

    // A cancelled row still shows its reason and stays closed.
    await tapByKey(tester, 'appointment-card-${cancelledVisit.id}');
    expect(find.text('Reason: Clinic closed'), findsOneWidget);
    expect(find.text('Cancelled visits cannot be changed.'), findsOneWidget);
    expect(find.text('Mark completed'), findsNothing);
    await tapByKey(tester, 'appointment-actions-close');
  });

  testWidgets('marking completed moves the visit to Past', (
    WidgetTester tester,
  ) async {
    await pumpAppointments(tester);
    await tapByKey(tester, 'appointment-card-${futureVisit.id}');
    await tapByKey(tester, 'appointment-action-complete');

    expect(find.text('Appointment marked completed.'), findsOneWidget);
    expect(
      find.byKey(ValueKey<String>('appointment-card-${futureVisit.id}')),
      findsNothing,
    );
    final Appointment? stored = await tester.runAsync<Appointment?>(
      () => harness.services.appointments.findById(futureVisit.id),
    );
    expect(stored!.status, AppointmentStatus.completed);
    expect(stored.completedAt, isNotNull);
    await clearSnackBar(tester);

    await tapByKey(tester, 'appointments-tab-past');
    expect(
      find.byKey(ValueKey<String>('appointment-card-${futureVisit.id}')),
      findsOneWidget,
    );
    expect(find.text('Completed'), findsNWidgets(2));
  });

  testWidgets('rescheduling cancels the old visit and books the new one', (
    WidgetTester tester,
  ) async {
    await pumpAppointments(tester);
    await tapByKey(tester, 'appointment-card-${futureVisit.id}');
    await tapByKey(tester, 'appointment-action-reschedule');

    expect(
      find.byKey(const ValueKey<String>('appointment-reschedule-date')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('appointment-reschedule-time')),
      findsOneWidget,
    );
    await tapByKey(tester, 'appointment-reschedule-confirm');

    expect(find.text('Appointment rescheduled.'), findsOneWidget);
    final Appointment? previous = await tester.runAsync<Appointment?>(
      () => harness.services.appointments.findById(futureVisit.id),
    );
    expect(previous!.status, AppointmentStatus.cancelled);
    expect(previous.cancelReason, 'rescheduled');

    final List<Appointment>? upcoming = await tester
        .runAsync<List<Appointment>>(
          () => harness.services.appointments.listUpcoming(now: now),
        );
    expect(upcoming, hasLength(2));
    expect(
      upcoming!
          .firstWhere(
            (Appointment item) => item.purpose == 'Annual wellness check',
          )
          .id,
      isNot(futureVisit.id),
    );
    expect(
      find.byKey(ValueKey<String>('appointment-card-${futureVisit.id}')),
      findsNothing,
    );
    await clearSnackBar(tester);
  });

  testWidgets('cancelling requires and stores a reason', (
    WidgetTester tester,
  ) async {
    await pumpAppointments(tester);
    await tapByKey(tester, 'appointment-card-${futureVisit.id}');
    await tapByKey(tester, 'appointment-action-cancel');

    final PrimaryButton confirm = tester.widget<PrimaryButton>(
      find.byKey(const ValueKey<String>('appointment-cancel-confirm')),
    );
    expect(confirm.onPressed, isNull);

    await tester.enterText(
      find.byKey(const ValueKey<String>('appointment-cancel-reason')),
      'Pet unwell',
    );
    await tester.pump();
    await tapByKey(tester, 'appointment-cancel-confirm');

    expect(find.text('Appointment cancelled.'), findsOneWidget);
    final Appointment? stored = await tester.runAsync<Appointment?>(
      () => harness.services.appointments.findById(futureVisit.id),
    );
    expect(stored!.status, AppointmentStatus.cancelled);
    expect(stored.cancelReason, 'Pet unwell');
    await clearSnackBar(tester);

    await tapByKey(tester, 'appointments-tab-past');
    expect(
      find.byKey(ValueKey<String>('appointment-card-${futureVisit.id}')),
      findsOneWidget,
    );
    expect(find.text('Cancelled'), findsNWidgets(2));
  });

  testWidgets('a past scheduled visit can be marked as a no-show', (
    WidgetTester tester,
  ) async {
    await pumpAppointments(tester);
    await tapByKey(tester, 'appointments-tab-past');
    await tapByKey(tester, 'appointment-card-${pastScheduled.id}');
    await tapByKey(tester, 'appointment-action-no-show');

    expect(find.text('Appointment marked as a no-show.'), findsOneWidget);
    final Appointment? stored = await tester.runAsync<Appointment?>(
      () => harness.services.appointments.findById(pastScheduled.id),
    );
    expect(stored!.status, AppointmentStatus.noShow);
    await clearSnackBar(tester);
  });

  testWidgets('the pet filter narrows the list quietly', (
    WidgetTester tester,
  ) async {
    await pumpAppointments(tester);

    await tapByKey(tester, 'appointment-pet-filter-${bella.id}');
    expect(
      find.byKey(ValueKey<String>('appointment-card-${futureVisit.id}')),
      findsOneWidget,
    );
    expect(
      find.byKey(ValueKey<String>('appointment-card-${misoVisit.id}')),
      findsNothing,
    );

    await tapByKey(tester, 'appointment-pet-filter-${miso.id}');
    expect(
      find.byKey(ValueKey<String>('appointment-card-${futureVisit.id}')),
      findsNothing,
    );
    expect(
      find.byKey(ValueKey<String>('appointment-card-${misoVisit.id}')),
      findsOneWidget,
    );

    await tapByKey(tester, 'appointment-pet-filter-all');
    expect(
      find.byKey(ValueKey<String>('appointment-card-${futureVisit.id}')),
      findsOneWidget,
    );
    expect(
      find.byKey(ValueKey<String>('appointment-card-${misoVisit.id}')),
      findsOneWidget,
    );
  });

  testWidgets('lays out phone-sized cards and sheets without overflow', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await pumpAppointments(tester);
    expect(tester.takeException(), isNull);

    await tapByKey(tester, 'appointment-card-${futureVisit.id}');
    expect(tester.takeException(), isNull);

    await tapByKey(tester, 'appointment-action-cancel');
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows the empty state for an empty upcoming list', (
    WidgetTester tester,
  ) async {
    await tester.runAsync(() async {
      await harness.services.appointments.updateStatus(
        futureVisit.id,
        AppointmentStatus.completed,
        now: now,
      );
      await harness.services.appointments.updateStatus(
        misoVisit.id,
        AppointmentStatus.completed,
        now: now,
      );
    });
    await pumpAppointments(tester);

    expect(
      find.byKey(const ValueKey<String>('appointments-empty')),
      findsOneWidget,
    );
    expect(find.text('No upcoming visits'), findsOneWidget);
  });
}
