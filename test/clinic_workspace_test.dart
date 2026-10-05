import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetassist/screens/staff/clinic_navigation.dart';
import 'package:vetassist/screens/staff/clinic_overview.dart';
import 'interface_test.dart' as previews;

final day = DateTime(2026, 9, 28, 10);

ClinicRecord booking(String id, String date, String time, String status) =>
    ClinicRecord(id, {
      'dateKey': date,
      'timeKey': time,
      'status': status,
      'patientName': 'Milo',
      'ownerName': 'Alex Reyes',
    });

ClinicRecord message(String id, String owner,
        {bool read = false, bool staff = false, int minutes = 0}) =>
    ClinicRecord(id, {
      'ownerUid': owner,
      'ownerName': owner == 'a' ? 'Alex Reyes' : 'Jamie Santos',
      'body': 'Can I confirm the visit for my pet?',
      if (staff) 'fromStaffUid': 'staff1' else 'fromOwnerUid': owner,
      'read': read,
      'createdAt': Timestamp.fromDate(day.add(Duration(minutes: minutes))),
    });

ClinicSummary sampleSummary() => ClinicSummary.fromRecords([
      booking('a', '2026-09-28', '09:00', 'approved'),
      booking('b', '2026-09-28', '11:30', 'approved'),
      booking('c', '2026-09-29', '10:00', 'approved'),
      booking('d', '2026-09-28', '14:00', 'pending'),
    ], [
      message('one', 'a'),
      message('two', 'a', minutes: 5),
      message('three', 'b', minutes: 8)
    ], day);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  WidgetController.hitTestWarningShouldBeFatal = true;

  setUpAll(() async {
    final path = Platform.environment['UI_FONT_PATH'];
    if (previews.capturePreviews && path != null) {
      final font = FontLoader('Roboto')
        ..addFont(File(path).readAsBytes().then(ByteData.sublistView));
      await font.load();
      final icons = FontLoader('MaterialIcons')
        ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
      await icons.load();
    }
  });

  test(
      'Counts confirmed visits by local calendar day, sorts times, excludes invalid dates',
      () {
    final summary = ClinicSummary.fromRecords([
      booking('late', '2026-09-28', '17:00', 'approved'),
      booking('early', '2026-09-28', '08:00', 'approved'),
      booking('pending', '2026-09-28', '12:00', 'pending'),
      booking('declined', '2026-09-28', '13:00', 'rejected'),
      booking('future', '2026-09-29', '10:00', 'approved'),
      booking('past', '2026-09-27', '10:00', 'approved'),
      booking('invalid', '2026-02-30', '09:00', 'approved'),
      booking('badtime', '2026-09-28', '25:00', 'approved'),
      const ClinicRecord('missing', {'status': 'approved'}),
    ], [], day);
    expect(summary.today.map((b) => b.id), ['early', 'late']);
    expect(summary.upcoming.map((b) => b.id), ['future']);
    expect(summary.pending.map((b) => b.id), ['pending']);
    final nextDay = ClinicSummary.fromRecords(
        [booking('future', '2026-09-29', '10:00', 'approved')],
        [],
        DateTime(2026, 9, 29));
    expect(nextDay.today.length, 1);
  });

  test('Unread badges exclude staff and read messages and clear after reading',
      () {
    final messages = [
      message('one', 'a'),
      message('two', 'a', minutes: 1),
      message('reply', 'a', staff: true, minutes: 2),
      message('read', 'b', read: true, minutes: 3),
      const ClinicRecord('legacy', {'ownerUid': 'c', 'fromStaffUid': 'staff1'}),
    ];
    final summary = ClinicSummary.fromRecords([], messages, day);
    expect(summary.unread, 2);
    expect(summary.threads.first.latest.id, 'reply');
    expect(summary.threads.first.focus.id, 'two');
    expect(summary.threads.first.unread, 2);
    final read = messages
        .map((m) => ClinicRecord(m.id, {...m.data, 'read': true}))
        .toList();
    expect(ClinicSummary.fromRecords([], read, day).unread, 0);
  });

  for (final viewport in [
    (name: 'phone', size: const Size(390, 844), scale: 1.0),
    (name: 'small', size: const Size(320, 640), scale: 1.0),
    (name: 'large_text', size: const Size(320, 640), scale: 2.0),
    (name: 'tablet', size: const Size(1024, 768), scale: 1.0),
  ]) {
    testWidgets('Clinic overview layout and actions: ${viewport.name}',
        (tester) async {
      previews.configureView(tester, viewport.size);
      final key = GlobalKey();
      String? filter;
      String? messageId;
      var inboxOpened = false;
      await tester.pumpWidget(RepaintBoundary(
          key: key,
          child: previews.app(
              Scaffold(
                appBar: AppBar(title: const Text('Clinic workspace')),
                body: ClinicOverview(
                  clinicName: 'M.D Vet Clinic',
                  summary: sampleSummary(),
                  now: day,
                  onRetry: () {},
                  onSchedule: (value) => filter = value,
                  onMessages: () => inboxOpened = true,
                  onMessage: (value) => messageId = value,
                ),
                bottomNavigationBar: ClinicNavigation(
                    section: 8,
                    unreadMessages: 3,
                    pendingBookings: 1,
                    onSelected: (_) {},
                    onMore: () {}),
              ),
              scale: viewport.scale)));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      if (viewport.name == 'phone' || viewport.name == 'tablet') {
        await previews.capture(tester, key, 'clinic_${viewport.name}');
      }
      await tester.scrollUntilVisible(find.text('Today’s visits'), 150,
          scrollable: find.byType(Scrollable).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Today’s visits'));
      expect(filter, 'today');
      await tester.scrollUntilVisible(find.text('To review'), 150,
          scrollable: find.byType(Scrollable).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('To review'));
      expect(filter, 'pending');
      await tester.scrollUntilVisible(find.text('View inbox'), 150,
          scrollable: find.byType(Scrollable).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('View inbox'));
      expect(inboxOpened, isTrue);
      await tester.scrollUntilVisible(find.text('Jamie Santos'), 150,
          scrollable: find.byType(Scrollable).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Jamie Santos'));
      expect(messageId, 'three');
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Empty, failed and loading sections remain independent',
      (tester) async {
    var retries = 0;
    await tester.pumpWidget(previews.app(Scaffold(
        body: ClinicOverview(
      clinicName: 'Clinic',
      summary: ClinicSummary.fromRecords([], [], day),
      now: day,
      bookingsError: true,
      messagesLoading: true,
      onRetry: () => retries++,
      onSchedule: (_) {},
      onMessages: () {},
      onMessage: (_) {},
    ))));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Loading conversations…'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Retry'), 150);
    await tester.tap(find.text('Retry'));
    expect(retries, 1);
    await tester.pumpWidget(previews.app(Scaffold(
        body: ClinicOverview(
      clinicName: 'Clinic',
      summary: ClinicSummary.fromRecords([], [], day),
      now: day,
      onRetry: () {},
      onSchedule: (_) {},
      onMessages: () {},
      onMessage: (_) {},
    ))));
    await tester.pumpAndSettle();
    expect(find.text('No conversations yet'), findsOneWidget);
    await tester.scrollUntilVisible(
        find.text('No approved visits scheduled'), 150);
    expect(find.text('No approved visits scheduled'), findsOneWidget);
  });

  testWidgets(
      'Bottom navigation opens each destination and only shows unread badges',
      (tester) async {
    var section = 8;
    var more = false;
    late StateSetter update;
    await tester
        .pumpWidget(previews.app(StatefulBuilder(builder: (context, setState) {
      update = setState;
      return Scaffold(
          bottomNavigationBar: ClinicNavigation(
        section: section,
        unreadMessages: section == 8 ? 3 : 0,
        pendingBookings: 0,
        onSelected: (value) => setState(() => section = value),
        onMore: () => more = true,
      ));
    })));
    expect(find.text('3'), findsWidgets);
    for (final item in [
      ('Messages', 5),
      ('Schedule', 6),
      ('Patients', 0),
      ('Home', 8)
    ]) {
      await tester.tap(find.text(item.$1));
      await tester.pumpAndSettle();
      expect(section, item.$2);
    }
    await tester.tap(find.text('More'));
    expect(more, isTrue);
    update(() => section = 5);
    await tester.pumpAndSettle();
    final badges = tester.widgetList<Badge>(find.byType(Badge));
    expect(badges.every((badge) => !badge.isLabelVisible), isTrue);
  });
}
