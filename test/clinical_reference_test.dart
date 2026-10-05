import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetassist/screens/staff/clinical_reference_screen.dart';
import 'package:vetassist/services/clinical_reference_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('source checksum, original diagnoses, and repeated IDs are preserved',
      () async {
    final data = await loadClinicalReferenceDataset();
    final bytes =
        File('datasets/clinical_reference/raw/UROGENITAL_DATASET-1.csv')
            .readAsBytesSync();
    expect(sha256.convert(bytes).toString(), data.source['rawSha256']);
    expect(data.source['doi'], '10.17632/6cjnjmtv2h.1');
    expect(data.records.length, 17);
    expect(data.search('', species: 'canine').length, 9);
    expect(data.search('', species: 'feline').length, 8);
    expect(
        data.records.where((row) => row['hasReportedDiagnosis'] == true).length,
        16);
    expect(data.records.map((row) => row['recordId']).toSet().length, 17);
    expect(
        data.records.where((row) => row['sourcePatientId'] == '1').length, 2);
    expect(data.source['independentPatientCount'], isNull);
    for (final row in data.records) {
      expect(row['reportedDiagnosis'],
          row['sourceFields']['DIAGNOSTICO DEFINITIVO']);
      expect(row['clinicalHistory'], row['sourceFields']['HISTORIA CLINICA']);
    }
    final clinicalModel =
        jsonDecode(File('lib/assets/symptom_model.json').readAsStringSync());
    expect(clinicalModel['status'], 'untrained');
  });

  testWidgets(
      'published records show source, species filters, and missing diagnosis honestly',
      (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final dataset = await tester.runAsync(loadClinicalReferenceDataset);
    await tester.pumpWidget(MaterialApp(
        home: ClinicalReferenceScreen(loader: () async => dataset!)));
    await tester.pumpAndSettle();
    expect(find.textContaining('17 published record rows'), findsOneWidget);
    expect(find.textContaining('not train or validate'), findsOneWidget);
    await tester.ensureVisible(find.text('Cats'));
    await tester.tap(find.text('Cats'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('8 record rows'), 100,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('8 record rows'), findsOneWidget);
    await tester.scrollUntilVisible(find.byType(TextField), -100,
        scrollable: find.byType(Scrollable).first);
    await tester.enterText(
        find.byType(TextField), 'mendeley-6cjnjmtv2h-v1-row-17');
    await tester.pumpAndSettle();
    tester.testTextInput.hide();
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('No reported diagnosis'), 100,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('No reported diagnosis'), findsOneWidget);
    await tester.tap(find.text('No reported diagnosis'));
    await tester.pumpAndSettle();
    expect(find.text('Published record 17'), findsOneWidget);
    expect(find.textContaining('not an assessment of the current patient'),
        findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
