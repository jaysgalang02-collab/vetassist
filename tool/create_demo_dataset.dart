import 'dart:convert';
import 'dart:io';

import 'package:vetassist/services/symptom_engine.dart';

void main() {
  final directory = Directory('datasets')..createSync(recursive: true);
  const encoder = JsonEncoder.withIndent('  ');
  final cases = <Map<String, dynamic>>[];
  final labels = <Map<String, dynamic>>[];
  const references = <String, String>{
    'parvovirus':
        'https://www.merckvetmanual.com/digestive-system/infectious-diseases-of-the-gastrointestinal-tract-in-small-animals/canine-parvovirus-infection-parvoviral-enteritis-in-dogs',
    'distemper':
        'https://www.merckvetmanual.com/infectious-diseases/canine-distemper/canine-distemper',
    'heartworm':
        'https://www.merckvetmanual.com/circulatory-system/heartworm-disease/heartworm-disease-in-dogs%2C-cats%2C-and-ferrets',
    'feline_leukemia':
        'https://www.vet.cornell.edu/departments-centers-and-institutes/cornell-feline-health-center/health-information/feline-health-topics/feline-leukemia-virus',
    'fiv':
        'https://www.vet.cornell.edu/departments-centers-and-institutes/cornell-feline-health-center/health-information/feline-health-topics/feline-immunodeficiency-virus',
    'feline_uri':
        'https://www.merckvetmanual.com/respiratory-system/respiratory-diseases-of-small-animals/feline-respiratory-disease-complex',
  };
  for (final rule in diseaseRules) {
    final symptoms = rule.symptoms.toList()..sort();
    labels.add({
      'disease': rule.disease,
      'displayName': rule.disease.replaceAll('_', ' '),
      'species': rule.species,
      'symptomIds': symptoms,
      'labelType': 'existing_application_rule_not_confirmed_diagnosis',
      'backgroundReferenceUrl': references[rule.disease],
      'referencePurpose':
          'Background reading only; not a source of observed patient cases, probabilities, or independently validated rules.',
    });
    for (var i = 0; i < 5; i++) {
      final subset = i == 0
          ? symptoms
          : symptoms
              .where((s) => s != symptoms[(i - 1) % symptoms.length])
              .toList();
      final id = 'DEMO-${rule.species}-${rule.disease}-${i + 1}';
      cases.add({
        'caseId': id,
        'patientId': 'SYNTHETIC-$id',
        'species': rule.species,
        'disease': rule.disease,
        'symptoms': subset,
        'symptomText': subset.map((s) => s.replaceAll('_', ' ')).join(', '),
        'dataKind': 'synthetic_demo',
        'diagnosisConfirmed': false,
        'labelOrigin': 'Generated subsets of existing application rules',
        'notAnObservedPatient': true,
      });
    }
  }
  final vocabulary = symptomAliases.entries
      .map((entry) => {
            'symptomId': entry.key,
            'displayName': entry.key.replaceAll('_', ' '),
            'aliases': entry.value,
            'encoding': 'Present symptom only; unreported symptoms are unknown',
          })
      .toList();
  void write(String name, Object data) => File('${directory.path}/$name')
      .writeAsStringSync('${encoder.convert(data)}\n');
  write('demo_labeled_cases.json', cases);
  write('disease_labels.json', labels);
  write('symptom_vocabulary.json', vocabulary);
  write('dataset_manifest.json', {
    'schemaVersion': 1,
    'datasetKind': 'synthetic_demo',
    'caseCount': cases.length,
    'diseaseCount': labels.length,
    'symptomCount': vocabulary.length,
    'casesPerDisease': 5,
    'observedPatientCount': 0,
    'clinicalValidation': 'Not performed',
    'source': 'Existing application rules in lib/services/symptom_engine.dart',
    'driveDatasetUsed': false,
    'intendedUse':
        'Software training/evaluation demonstration only, not patient diagnosis or clinical accuracy claims',
    'limitation':
        'Cases are correlated generated rule subsets; some symptom patterns repeat. Splitting them does not produce independent clinical validation.',
  });
  final csv = StringBuffer(
      'caseId,patientId,species,disease,symptoms,dataKind,diagnosisConfirmed\n');
  for (final row in cases) {
    csv.writeln(
        '${row['caseId']},${row['patientId']},${row['species']},${row['disease']},${(row['symptoms'] as List).join('|')},synthetic_demo,false');
  }
  File('${directory.path}/demo_labeled_cases.csv')
      .writeAsStringSync(csv.toString());
  stdout.writeln(
      'Created ${cases.length} explicitly synthetic demo cases, ${labels.length} disease labels, and ${vocabulary.length} symptom labels. No observed patients or Drive files used.');
}
