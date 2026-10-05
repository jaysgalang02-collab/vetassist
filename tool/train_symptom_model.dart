import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';

import 'package:vetassist/services/symptom_engine.dart';

void main(List<String> args) {
  final demo = args.length == 3 && args[2] == '--demo';
  if (args.length != 2 && !demo) {
    stderr.writeln(
        'Usage: dart run tool/train_symptom_model.dart cases.json model.json [--demo]');
    exitCode = 64;
    return;
  }
  try {
    final input = File(args[0]);
    final bytes = input.readAsBytesSync();
    final raw = jsonDecode(utf8.decode(bytes));
    if (raw is! List || raw.isEmpty) {
      throw const FormatException(
          'Expected a nonempty JSON array of labeled cases.');
    }
    final containsSynthetic =
        raw.any((row) => row is Map && row['dataKind'] == 'synthetic_demo');
    if (containsSynthetic && !demo) {
      throw const FormatException(
          'Synthetic examples require --demo and cannot be presented as clinical training.');
    }
    if (demo &&
        raw.any((row) => row is! Map || row['dataKind'] != 'synthetic_demo')) {
      throw const FormatException(
          'Demo input must explicitly label every row synthetic_demo.');
    }
    if (demo &&
        File(args[1])
            .absolute
            .path
            .toLowerCase()
            .replaceAll('\\', '/')
            .endsWith('/lib/assets/symptom_model.json')) {
      throw const FormatException(
          'Demo models must be saved separately from the patient-facing model asset.');
    }
    final groups = <String, List<Map<String, dynamic>>>{};
    final identities = <String>{};
    final patients = <String, String>{};
    for (final item in raw) {
      if (item is! Map) throw const FormatException('Invalid case.');
      final row = Map<String, dynamic>.from(item);
      if (row['caseId'] is! String ||
          (row['caseId'] as String).trim().isEmpty ||
          !identities.add(row['caseId'])) {
        throw const FormatException('Each case requires a unique caseId.');
      }
      if (row['patientId'] is! String ||
          (row['patientId'] as String).trim().isEmpty) {
        throw const FormatException(
            'A de-identified patientId is required to prevent split leakage.');
      }
      if (!diseaseRules.any(
          (r) => r.species == row['species'] && r.disease == row['disease'])) {
        throw const FormatException(
            'Species/disease is outside the supported rule vocabulary.');
      }
      if (row['symptoms'] is! List ||
          (row['symptoms'] as List).isEmpty ||
          (row['symptoms'] as List)
              .any((s) => !symptomAliases.containsKey(s))) {
        throw const FormatException(
            'Symptoms must be a nonempty list of supported symptom IDs.');
      }
      final key = '${row['species']}:${row['disease']}';
      final previous = patients[row['patientId']];
      if (previous != null) {
        throw const FormatException(
            'Use one labeled case per patient in this training format.');
      }
      patients[row['patientId']] = key;
      groups.putIfAbsent(key, () => []).add(row);
    }
    for (final species in ['canine', 'feline']) {
      final count = groups.keys.where((k) => k.startsWith('$species:')).length;
      if (count == 1) {
        throw FormatException(
            '$species requires at least two disease classes.');
      }
    }
    final training = <Map<String, dynamic>>[];
    final heldout = <Map<String, dynamic>>[];
    final keys = groups.keys.toList()..sort();
    final random = Random(42);
    for (final key in keys) {
      final rows = groups[key]!
        ..sort(
            (a, b) => (a['caseId'] as String).compareTo(b['caseId'] as String));
      if (rows.length < 5) {
        throw FormatException(
            '$key needs at least five independent labeled patients for a holdout split.');
      }
      rows.shuffle(random);
      final testCount = max(1, (rows.length * 0.2).floor());
      heldout.addAll(rows.take(testCount));
      training.addAll(rows.skip(testCount));
    }
    final counts = <String, Map<String, dynamic>>{};
    for (final row in training) {
      final key = '${row['species']}:${row['disease']}';
      final c = counts.putIfAbsent(
          key,
          () => {
                'species': row['species'],
                'disease': row['disease'],
                'count': 0,
                'symptomCounts': <String, int>{}
              });
      c['count'] = (c['count'] as int) + 1;
      final frequencies = c['symptomCounts'] as Map<String, int>;
      for (final symptom in (row['symptoms'] as List).cast<String>().toSet()) {
        frequencies.update(symptom, (n) => n + 1, ifAbsent: () => 1);
      }
    }
    final model = <String, dynamic>{
      'schemaVersion': 1,
      'status': 'trained',
      'sourceName': input.uri.pathSegments.last,
      'sourceSha256': sha256.convert(bytes).toString(),
      'datasetKind': demo ? 'synthetic_demo' : 'user_supplied_unverified',
      'trainedAtUtc': DateTime.now().toUtc().toIso8601String(),
      'algorithm':
          'Positive-evidence Naive Bayes with Laplace smoothing; unreported symptoms are unknown',
      'seed': 42,
      'trainingCases': training.length,
      'heldoutCases': heldout.length,
      'classes': counts.values.toList(),
    };
    final engine = SymptomEngine(model: model);
    var correct = 0;
    final confusion = <String, Map<String, int>>{};
    for (final row in heldout) {
      final prediction = engine
          .predict(
              row['species'], (row['symptoms'] as List).cast<String>().toSet())
          .first
          .disease;
      if (prediction == row['disease']) correct++;
      final actual = '${row['species']}:${row['disease']}';
      confusion
          .putIfAbsent(actual, () => {})
          .update(prediction, (n) => n + 1, ifAbsent: () => 1);
    }
    final report = {
      'datasetKind': model['datasetKind'],
      'interpretation': demo
          ? 'Software demonstration only. Examples derive from existing rules; accuracy does not measure clinical performance.'
          : 'User-supplied labels require independent clinical verification.',
      'sourceSha256': model['sourceSha256'],
      'trainingCases': training.length,
      'heldoutCases': heldout.length,
      'correct': correct,
      'holdoutAccuracy': correct / heldout.length,
      'confusionMatrix': confusion,
      'clinicalValidation':
          'Not performed. Holdout results are dataset-specific and not clinical validation.'
    };
    final output = File(args[1]);
    if (input.absolute.path.toLowerCase() ==
        output.absolute.path.toLowerCase()) {
      throw const FormatException(
          'Output must not overwrite the source dataset.');
    }
    output.parent.createSync(recursive: true);
    const encoder = JsonEncoder.withIndent('  ');
    output.writeAsStringSync('${encoder.convert(model)}\n');
    File('${args[1]}.evaluation.json')
        .writeAsStringSync('${encoder.convert(report)}\n');
    stdout.writeln(
        'Trained on ${training.length} cases; evaluated on ${heldout.length} held-out cases. Accuracy: ${(correct / heldout.length).toStringAsFixed(4)}. Clinical validation not performed.');
  } catch (e) {
    stderr.writeln('Training failed: $e');
    exitCode = 1;
  }
}
