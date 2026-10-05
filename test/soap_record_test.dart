import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetassist/models/soap_record.dart';
import 'package:vetassist/screens/staff/medical_record_form.dart';
import 'package:vetassist/widgets/medical_record_view.dart';
import 'interface_test.dart' as previews;

final visitTime = DateTime(2026, 10, 2, 9, 30);
Map<String, String> completeValues() => {
      for (final section in soapSections)
        for (final field in section.fields)
          field.key: field.numeric ? '12.5' : 'Recorded ${field.key}',
      'patientName': 'Milo',
      'species': 'canine',
      'sex': 'male',
      'reproductiveStatus': 'neutered',
      'recordNo': '',
      'chiefComplaint': 'Follow-up examination',
    };

Map<String, dynamic> payload(
        {Map<String, String>? values,
        List<Map<String, dynamic>> signature = const []}) =>
    buildSoapVisit(
        recordId: 'record-1',
        clinicId: 'clinic-1',
        clinicName: 'Canine & Feline Clinic',
        patientId: 'pet-1',
        ownerUid: 'owner-1',
        authorUid: 'vet-1',
        date: visitTime,
        values: values ?? completeValues(),
        signature: signature,
        signatureDate: visitTime);

MedicalRecordForm form(
        {SaveSoapRecord? onSave, Map<String, String>? initial}) =>
    MedicalRecordForm(
        recordId: 'record-1',
        clinicId: 'clinic-1',
        clinicName: 'Canine & Feline Clinic',
        patientId: 'pet-1',
        ownerUid: 'owner-1',
        authorUid: 'vet-1',
        initialValues: initial ?? completeValues(),
        onSave: onSave ?? (_) async {});

Future<void> next(WidgetTester tester) async {
  await tester.tap(find.text('Continue'));
  await tester.pumpAndSettle();
}

Future<void> showField(WidgetTester tester, String key) async {
  await tester.ensureVisible(find.byKey(ValueKey('field-$key')));
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    if (previews.capturePreviews) {
      final fontPath = Platform.environment['UI_FONT_PATH'];
      if (fontPath != null) {
        final loader = FontLoader('Roboto');
        loader.addFont(Future.value(
            ByteData.sublistView(await File(fontPath).readAsBytes())));
        await loader.load();
      }
      final icons = FontLoader('MaterialIcons');
      icons.addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
      await icons.load();
    }
  });

  test('all SOAP fields and compatibility summaries survive serialization', () {
    final source = completeValues();
    final data = payload(values: source);
    expect(data['ownerUid'], 'owner-1');
    expect(data['clinicId'], 'clinic-1');
    expect((data['date'] as Timestamp).toDate(), visitTime);
    expect(data['createdBy'], 'vet-1');
    final sections = readableSoap(data);
    for (final section in soapSections) {
      for (final field in section.fields) {
        expect(sections[section.key]![field.key],
            field.key == 'recordNo' ? 'record-1' : source[field.key],
            reason: field.key);
      }
    }
    expect(data['diagnosis'], source['primaryDiagnosis']);
    expect(data['diagnosisSummary'], source['primaryDiagnosis']);
    expect(data['notes'], source['treatment']);
    expect(data['prescription'], source['prescription']);
    expect(sections['objective']!['weightKg'], source['weightKg']);
    expect(sections['signOff']!['date'], isNull);
  });

  test('existing staff and customer visit formats remain readable', () {
    final staff = readableSoap(
        {'diagnosis': 'Skin condition', 'notes': 'Clinic instructions'});
    expect(staff['assessment']!['primaryDiagnosis'], 'Skin condition');
    expect(staff['plan']!['treatment'], 'Clinic instructions');
    final customer = readableSoap(
        {'diagnosisSummary': 'Review', 'prescription': 'Vet prescription'});
    expect(customer['assessment']!['primaryDiagnosis'], 'Review');
    expect(customer['plan']!['prescription'], 'Vet prescription');
    expect(readableSoap({})['objective'], isEmpty);
  });

  test(
      'numeric validation rejects invalid measurements without inventing findings',
      () {
    const field = SoapField('weightKg', 'Weight', numeric: true);
    for (final value in ['NaN', 'Infinity', '-1', '0', 'abc']) {
      expect(validateSoapField(field, value), isNotNull);
    }
    expect(validateSoapField(field, '1.25'), isNull);
    expect(validateSoapField(field, ''), isNull);
    final source = completeValues()..['weightKg'] = '';
    expect(readableSoap(payload(values: source))['objective']!['weightKg'], '');
  });

  test('signatures require vet identity and retain normalized strokes', () {
    final points = [
      {'x': .1, 'y': .2, 'start': true},
      {'x': .2, 'y': .3, 'start': false}
    ];
    expect(
        () => payload(
            values: completeValues()..['licenseNo'] = '', signature: points),
        throwsArgumentError);
    final record = payload(signature: points);
    expect(readableSoap(record)['signOff']!['signature'], points);
    points.clear();
    expect((readableSoap(record)['signOff']!['signature'] as List).length, 2);
    expect(
        () => payload(signature: [
              {'x': 2, 'y': .1, 'start': true}
            ]),
        throwsArgumentError);
  });

  test(
      'autofill snapshots patient and owner values without filling unknown age',
      () {
    final patient = {
      'name': 'Milo',
      'species': 'canine',
      'weightKg': 4.2,
      'allergies': 'Unknown'
    };
    final values = patientRecordDefaults(
        patient, {'displayName': 'Alex', 'phone': '09123456789'});
    expect(values['ownerName'], 'Alex');
    expect(values['contact'], '09123456789');
    expect(values['age'], '');
    expect(values['weightKg'], '4.2');
    values['patientName'] = 'Changed snapshot';
    expect(patient['name'], 'Milo');
  });

  for (final viewport in [
    (name: 'phone', size: const Size(390, 844), scale: 1.0),
    (name: 'small', size: const Size(320, 640), scale: 1.0),
    (name: 'large_text', size: const Size(320, 640), scale: 2.0),
    (name: 'landscape', size: const Size(844, 390), scale: 1.0),
    (name: 'tablet', size: const Size(1024, 768), scale: 1.0),
  ]) {
    testWidgets('all six sections work at ${viewport.name}', (tester) async {
      previews.configureView(tester, viewport.size);
      final boundary = GlobalKey();
      await tester.pumpWidget(RepaintBoundary(
          key: boundary, child: previews.app(form(), scale: viewport.scale)));
      await tester.pumpAndSettle();
      for (var section = 0; section < 6; section++) {
        expect(tester.takeException(), isNull,
            reason: soapSections[section].title);
        if (section == 0 && ['phone', 'tablet'].contains(viewport.name)) {
          await previews.capture(tester, boundary, 'soap_${viewport.name}');
        }
        await showField(tester, soapSections[section].fields.last.key);
        expect(tester.takeException(), isNull);
        if (section < 5) await next(tester);
      }
      expect(find.text('Save medical record'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('keyboard in landscape keeps the form usable', (tester) async {
    previews.configureView(tester, const Size(844, 390));
    tester.view.viewInsets = const FakeViewPadding(bottom: 180);
    await tester.pumpWidget(previews.app(form()));
    await tester.pumpAndSettle();
    await showField(tester, 'patientName');
    await tester.enterText(
        find.byKey(const ValueKey('field-patientName')), 'Milo updated');
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Continue'), findsOneWidget);
  });

  testWidgets('required fields block save even when sections are skipped',
      (tester) async {
    previews.configureView(tester, const Size(390, 844));
    var calls = 0;
    await tester.pumpWidget(previews.app(form(
        initial: completeValues()..['chiefComplaint'] = '',
        onSave: (_) async {
          calls++;
        })));
    await tester.pumpAndSettle();
    final lastChip = find.widgetWithText(ChoiceChip, '6. Sign-off');
    await tester.scrollUntilVisible(lastChip, 150,
        scrollable: find.byType(Scrollable).first);
    await tester.ensureVisible(lastChip);
    await tester.pumpAndSettle();
    await tester.tap(lastChip);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save medical record'));
    await tester.pumpAndSettle();
    expect(calls, 0);
    expect(find.text('Please enter chief complaint.'), findsOneWidget);
  });

  testWidgets(
      'failed save preserves entries, retry uses same record, busy blocks duplicates',
      (tester) async {
    previews.configureView(tester, const Size(390, 844));
    var calls = 0;
    Map<String, dynamic>? saved;
    final pending = Completer<void>();
    await tester.pumpWidget(previews.app(Builder(
        builder: (context) => Scaffold(
              body: TextButton(
                  child: const Text('Open'),
                  onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => form(onSave: (data) async {
                                calls++;
                                if (calls == 1) throw StateError('network');
                                saved = data;
                                await pending.future;
                              })))),
            ))));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    for (var i = 0; i < 5; i++) {
      await next(tester);
    }
    await tester.tap(find.text('Save medical record'));
    await tester.pumpAndSettle();
    expect(calls, 1);
    expect(find.textContaining('Save was not confirmed.'), findsWidgets);
    await tester.tap(find.text('Save medical record'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    final button = tester.widget<FilledButton>(find.ancestor(
        of: find.text('Saving record...'),
        matching: find.byWidgetPredicate((widget) => widget is FilledButton)));
    expect(button.onPressed, isNull);
    expect(calls, 2);
    expect(readableSoap(saved!)['patient']!['recordNo'], 'record-1');
    expect(readableSoap(saved!)['subjective']!['chiefComplaint'],
        'Follow-up examination');
    pending.complete();
    await tester.pumpAndSettle();
    expect(find.text('Open'), findsOneWidget);
  });

  testWidgets(
      'signed and legacy viewers scroll without truncating clinical notes',
      (tester) async {
    previews.configureView(tester, const Size(320, 640));
    final longNotes =
        List.filled(50, 'Detailed client instructions.').join(' ');
    final data =
        payload(values: completeValues()..['homeCare'] = longNotes, signature: [
      {'x': .1, 'y': .2, 'start': true},
      {'x': .4, 'y': .5, 'start': false}
    ]);
    await tester.pumpWidget(previews
        .app(MedicalRecordView(recordId: 'record-1', visit: data), scale: 2));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
        find.text('Home care / client instructions'), 400,
        scrollable: find.byType(Scrollable).first);
    expect(find.text(longNotes), findsOneWidget);
    await tester.scrollUntilVisible(find.byType(VetSignaturePad), 400,
        scrollable: find.byType(Scrollable).first);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(previews.app(const MedicalRecordView(
        recordId: 'old',
        visit: {'diagnosis': 'Review', 'notes': 'Historical notes'})));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Historical notes'), 350,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('Historical notes'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('signature can be drawn, cleared and redrawn', (tester) async {
    previews.configureView(tester, const Size(390, 844));
    var points = <Map<String, dynamic>>[];
    await tester.pumpWidget(previews.app(Scaffold(
        body: StatefulBuilder(
      builder: (context, setLocal) => Column(children: [
        VetSignaturePad(
            points: points,
            onChanged: (value) => setLocal(() => points = value)),
        TextButton(
            onPressed: () => setLocal(() => points = []),
            child: const Text('Clear')),
      ]),
    ))));
    await tester.drag(find.byType(VetSignaturePad), const Offset(50, 20));
    await tester.pumpAndSettle();
    expect(points, isNotEmpty);
    expect(points.first['start'], true);
    await tester.tap(find.text('Clear'));
    await tester.pumpAndSettle();
    expect(points, isEmpty);
    await tester.drag(find.byType(VetSignaturePad), const Offset(30, 10));
    await tester.pumpAndSettle();
    expect(points, isNotEmpty);
  });
}
