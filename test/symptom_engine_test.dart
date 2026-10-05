import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vetassist/services/local_cdss_service.dart';
import 'package:vetassist/services/symptom_engine.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('bundled model is honestly untrained', () async {
    final engine = await loadSymptomEngine();
    expect(engine.model!['status'], 'untrained');
    expect(engine.predict('canine', {'vomiting'}).first.source,
        contains('not disease probability'));
  });

  test('NLP recognizes English and Filipino and respects negation', () {
    final engine = SymptomEngine();
    expect(engine.extract('Sumusuka, nagtatae at matamlay'),
        {'vomiting', 'diarrhea', 'lethargy'});
    expect(engine.extract('No fever or cough, but vomiting.'), {'vomiting'});
    expect(
        engine.extract('Walang lagnat; hindi kumakain.'), {'loss_of_appetite'});
    expect(
        engine.extract('The vomiting has stopped. No longer weak.'), isEmpty);
    expect(engine.extract('not eating and difficulty breathing'),
        {'loss_of_appetite', 'respiratory_distress'});
    expect(engine.extract('scoughing is not a symptom'), isEmpty);
    expect(engine.extract('nasal_discharge'), {'nasal_discharge'});
  });

  test('rules stay species-specific and do not predict from missing evidence',
      () {
    final engine = SymptomEngine();
    expect(engine.predict('canine', {'vomiting', 'diarrhea'}).first.disease,
        'parvovirus');
    expect(engine.predict('feline', {'vomiting', 'diarrhea'}), isEmpty);
    expect(engine.predict('canine', {}), isEmpty);
    expect(engine.predict('canine', {'unrecognized'}), isEmpty);
    expect(() => engine.predict('bird', {'fever'}), throwsArgumentError);
  });

  test('customer output never exposes disease suggestions or probabilities',
      () {
    final reply = SymptomEngine().reply('hirap huminga at sumusuka', 'canine',
        firstAidOnly: true, hasImages: true);
    expect(reply, contains('EMERGENCY'));
    expect(reply, contains('attachments only'));
    expect(reply, isNot(contains('parvovirus')));
    expect(reply, isNot(contains('%')));
    expect(SymptomEngine().reply('', 'feline', hasImages: true),
        contains('No supported symptoms'));
  });

  test('Naive Bayes uses trained frequencies, smoothing, and species filtering',
      () {
    final model = <String, dynamic>{
      'schemaVersion': 1,
      'status': 'trained',
      'sourceName': 'TEST FIXTURE',
      'sourceSha256': 'test-only',
      'classes': [
        {
          'species': 'canine',
          'disease': 'parvovirus',
          'count': 10,
          'symptomCounts': {'vomiting': 9}
        },
        {
          'species': 'canine',
          'disease': 'distemper',
          'count': 10,
          'symptomCounts': {'vomiting': 1}
        },
        {
          'species': 'feline',
          'disease': 'fiv',
          'count': 10,
          'symptomCounts': {'vomiting': 10}
        },
      ],
    };
    final results = SymptomEngine(model: model).predict('canine', {'vomiting'});
    expect(results.length, 2);
    expect(results.first.disease, 'parvovirus');
    expect(results.first.score, closeTo(10 / 12, 1e-10));
    expect(results.fold<double>(0, (n, s) => n + s.score), closeTo(1, 1e-10));
    expect(
        () => SymptomEngine(model: {
              ...model,
              'classes': [
                {
                  'species': 'canine',
                  'disease': 'x',
                  'count': -1,
                  'symptomCounts': {}
                }
              ]
            }),
        throwsFormatException);
  });

  test('training produces model provenance and a separate holdout evaluation',
      () async {
    final temp =
        Directory.systemTemp.createTempSync('vetassist-training-test-');
    addTearDown(() => temp.deleteSync(recursive: true));
    final cases = <Map<String, dynamic>>[];
    for (final disease in ['parvovirus', 'distemper']) {
      for (var i = 0; i < 5; i++) {
        cases.add({
          'caseId': '$disease-$i',
          'patientId': '$disease-patient-$i',
          'species': 'canine',
          'disease': disease,
          'symptoms': [disease == 'parvovirus' ? 'vomiting' : 'cough']
        });
      }
    }
    final source = File('${temp.path}/TEST_FIXTURE.json')
      ..writeAsStringSync(jsonEncode(cases));
    final output = File('${temp.path}/model.json');
    final dart =
        '${Platform.environment['FLUTTER_ROOT'] ?? 'C:/flutter'}/bin/cache/dart-sdk/bin/dart.exe';
    final result = await Process.run(dart,
        ['run', 'tool/train_symptom_model.dart', source.path, output.path]);
    expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
    final model = jsonDecode(output.readAsStringSync()) as Map<String, dynamic>;
    expect(model['trainingCases'], 8);
    expect(model['heldoutCases'], 2);
    expect(model['sourceSha256'], hasLength(64));
    final report =
        jsonDecode(File('${output.path}.evaluation.json').readAsStringSync());
    expect(report['heldoutCases'], 2);
    expect(report['clinicalValidation'], startsWith('Not performed'));
    cases[1]['patientId'] = cases[0]['patientId'];
    source.writeAsStringSync(jsonEncode(cases));
    final rejected = await Process.run(dart, [
      'run',
      'tool/train_symptom_model.dart',
      source.path,
      '${temp.path}/rejected.json'
    ]);
    expect(rejected.exitCode, 1);
    expect(File('${temp.path}/rejected.json').existsSync(), isFalse);
  });

  test(
      'synthetic dataset requires demo mode and cannot replace the clinical asset',
      () async {
    final temp = Directory.systemTemp.createTempSync('vetassist-demo-test-');
    addTearDown(() => temp.deleteSync(recursive: true));
    final dart =
        '${Platform.environment['FLUTTER_ROOT'] ?? 'C:/flutter'}/bin/cache/dart-sdk/bin/dart.exe';
    final clinicalAsset = File('lib/assets/symptom_model.json');
    final original = clinicalAsset.readAsStringSync();
    final noFlag = await Process.run(dart, [
      'run',
      'tool/train_symptom_model.dart',
      'datasets/demo_labeled_cases.json',
      '${temp.path}/rejected.json'
    ]);
    expect(noFlag.exitCode, 1);
    expect(noFlag.stderr, contains('require --demo'));
    expect(File('${temp.path}/rejected.json').existsSync(), isFalse);
    final assetAttempt = await Process.run(dart, [
      'run',
      'tool/train_symptom_model.dart',
      'datasets/demo_labeled_cases.json',
      clinicalAsset.path,
      '--demo'
    ]);
    expect(assetAttempt.exitCode, 1);
    expect(assetAttempt.stderr, contains('patient-facing model asset'));
    expect(clinicalAsset.readAsStringSync(), original);
    final demo =
        jsonDecode(File('datasets/demo_symptom_model.json').readAsStringSync());
    expect(demo['datasetKind'], 'synthetic_demo');
    expect(demo['trainingCases'], 24);
    expect(demo['heldoutCases'], 6);
  });
}
