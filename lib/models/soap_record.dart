import 'package:cloud_firestore/cloud_firestore.dart';

class SoapField {
  const SoapField(this.key, this.label,
      {this.numeric = false, this.long = true});
  final String key;
  final String label;
  final bool numeric;
  final bool long;
}

class SoapSection {
  const SoapSection(this.key, this.title, this.subtitle, this.fields);
  final String key;
  final String title;
  final String subtitle;
  final List<SoapField> fields;
}

const soapSections = [
  SoapSection(
      'patient', 'Patient & visit', 'Confirm the details for this visit.', [
    SoapField('recordNo', 'Record no.', long: false),
    SoapField('patientName', 'Patient name', long: false),
    SoapField('species', 'Species', long: false),
    SoapField('breed', 'Breed', long: false),
    SoapField('sex', 'Sex', long: false),
    SoapField('reproductiveStatus', 'Neutered / spayed', long: false),
    SoapField('age', 'Age at visit', long: false),
    SoapField('weightKg', 'Weight (kg)', numeric: true, long: false),
    SoapField('ownerName', 'Owner name', long: false),
    SoapField('contact', 'Owner contact', long: false),
  ]),
  SoapSection('subjective', 'Subjective', 'What the owner has noticed.', [
    SoapField('chiefComplaint', 'Chief complaint'),
    SoapField('history', 'History of present illness / duration'),
    SoapField('intake', 'Appetite / water intake'),
    SoapField('symptoms',
        'Vomiting / diarrhea / coughing / sneezing / urination / other'),
    SoapField(
        'medicationsHistory', 'Medications / allergies / relevant history'),
    SoapField('ownerConcerns', "Owner's concerns / additional notes"),
  ]),
  SoapSection('objective', 'Objective',
      'Record measured values and examination findings.', [
    SoapField('temperature', 'Temperature (°C)', numeric: true, long: false),
    SoapField('heartRate', 'Heart rate (bpm)', numeric: true, long: false),
    SoapField('respiratoryRate', 'Respiratory rate (breaths/min)',
        numeric: true, long: false),
    SoapField('bcs', 'Body condition score (include scale)', long: false),
    SoapField('general', 'General'),
    SoapField('hydration', 'Hydration'),
    SoapField('mmCrt', 'Mucous membranes / capillary refill time'),
    SoapField('eyesEarsNose', 'Eyes / ears / nose'),
    SoapField('oral', 'Oral'),
    SoapField('skinCoat', 'Skin / coat'),
    SoapField('cardiovascular', 'Cardiovascular'),
    SoapField('respiratory', 'Respiratory'),
    SoapField('gi', 'Gastrointestinal'),
    SoapField('urinaryReproductive', 'Urinary / reproductive'),
    SoapField('musculoskeletal', 'Musculoskeletal'),
    SoapField('neurologic', 'Neurologic'),
    SoapField('otherFindings', 'Other findings'),
    SoapField('additionalParameters', 'Additional parameters and findings'),
  ]),
  SoapSection(
      'assessment', 'Assessment', 'Document the veterinary assessment.', [
    SoapField('primaryDiagnosis', 'Primary diagnosis'),
    SoapField('differentialDiagnoses', 'Differential diagnoses'),
    SoapField('interpretation', 'Clinical assessment / interpretation'),
  ]),
  SoapSection('plan', 'Plan', 'Care, instructions and the next review.', [
    SoapField('diagnostics', 'Diagnostics'),
    SoapField('treatment', 'Treatment / procedures'),
    SoapField('prescription', 'Medications / prescription'),
    SoapField('homeCare', 'Home care / client instructions'),
    SoapField('followUp', 'Follow-up / recheck'),
  ]),
  SoapSection(
      'signOff', 'Sign-off', 'Complete the attending veterinarian details.', [
    SoapField('veterinarian', 'Attending veterinarian', long: false),
    SoapField('licenseNo', 'License / registration no.', long: false),
    SoapField('staffInitials', 'Staff initials', long: false),
  ]),
];

String recordText(dynamic value) =>
    value is String || value is num ? value.toString().trim() : '';

Map<String, dynamic> recordMap(dynamic value) =>
    value is Map ? Map<String, dynamic>.from(value) : {};

DateTime? recordDate(dynamic value) => value is Timestamp
    ? value.toDate()
    : value is DateTime
        ? value
        : null;

String recordDateLabel(DateTime? date) {
  if (date == null) return 'Not recorded';
  String two(int n) => n.toString().padLeft(2, '0');
  return '${date.year}-${two(date.month)}-${two(date.day)} ${two(date.hour)}:${two(date.minute)}';
}

String? validateSoapField(SoapField field, String value) {
  final text = value.trim();
  if (['patientName', 'chiefComplaint'].contains(field.key) && text.isEmpty) {
    return 'Please enter ${field.label.toLowerCase()}.';
  }
  if (text.length > 4000) return 'Please use 4,000 characters or fewer.';
  if (field.numeric && text.isNotEmpty) {
    final number = double.tryParse(text);
    if (number == null || !number.isFinite || number <= 0) {
      return 'Enter a positive number.';
    }
  }
  return null;
}

Map<String, String> patientRecordDefaults(
    Map<String, dynamic> patient, Map<String, dynamic> owner) {
  String pick(List<dynamic> values) =>
      values.map(recordText).firstWhere((s) => s.isNotEmpty, orElse: () => '');
  return {
    'patientName': recordText(patient['name']),
    'species': recordText(patient['species']),
    'breed': recordText(patient['breed']),
    'sex': recordText(patient['sex']),
    'reproductiveStatus': recordText(patient['reproductiveStatus']),
    'age': recordText(patient['age']),
    'weightKg': recordText(patient['weightKg']),
    'ownerName': pick([
      owner['displayName'],
      owner['name'],
      patient['ownerName'],
      owner['email']
    ]),
    'contact': pick([
      owner['phone'],
      owner['phoneNumber'],
      owner['contact'],
      owner['email']
    ]),
    'medicationsHistory': recordText(patient['allergies']).isEmpty
        ? ''
        : 'Allergies: ${recordText(patient['allergies'])}',
  };
}

Map<String, dynamic> buildSoapVisit({
  required String recordId,
  required String clinicId,
  required String clinicName,
  required String patientId,
  required String ownerUid,
  required String authorUid,
  required DateTime date,
  required Map<String, String> values,
  required List<Map<String, dynamic>> signature,
  required DateTime signatureDate,
}) {
  if ([recordId, clinicId, patientId, ownerUid, authorUid]
      .any((s) => s.trim().isEmpty)) {
    throw ArgumentError(
        'The record requires a clinic, patient, owner and author.');
  }
  for (final section in soapSections) {
    for (final field in section.fields) {
      final error = validateSoapField(field, values[field.key] ?? '');
      if (error != null) throw ArgumentError(error);
    }
  }
  if (signature.isNotEmpty &&
      ((values['veterinarian'] ?? '').trim().isEmpty ||
          (values['licenseNo'] ?? '').trim().isEmpty)) {
    throw ArgumentError(
        'Enter the veterinarian and license number before signing.');
  }
  if (signature.length > 4000 ||
      signature.any((p) =>
          p['x'] is! num ||
          p['y'] is! num ||
          !(p['x'] as num).isFinite ||
          !(p['y'] as num).isFinite ||
          (p['x'] as num) < 0 ||
          (p['x'] as num) > 1 ||
          (p['y'] as num) < 0 ||
          (p['y'] as num) > 1 ||
          p['start'] is! bool)) {
    throw ArgumentError('Invalid signature.');
  }
  final soap = <String, dynamic>{};
  for (final section in soapSections) {
    soap[section.key] = <String, dynamic>{
      for (final field in section.fields)
        field.key: (values[field.key] ?? '').trim(),
    };
  }
  soap['patient']['recordNo'] = (values['recordNo'] ?? '').trim().isEmpty
      ? recordId
      : values['recordNo']!.trim();
  soap['objective']['weightKg'] = (values['weightKg'] ?? '').trim();
  soap['signOff']['signature'] =
      signature.map((p) => Map<String, dynamic>.from(p)).toList();
  soap['signOff']['date'] =
      signature.isEmpty ? null : Timestamp.fromDate(signatureDate);
  return {
    'schemaVersion': 2,
    'recordType': 'soap',
    'clinicId': clinicId,
    'clinic': clinicName,
    'patientId': patientId,
    'patientName': (values['patientName'] ?? '').trim(),
    'ownerUid': ownerUid,
    'ownerName': (values['ownerName'] ?? '').trim(),
    'date': Timestamp.fromDate(date),
    'diagnosis': (values['primaryDiagnosis'] ?? '').trim(),
    'diagnosisSummary': (values['primaryDiagnosis'] ?? '').trim(),
    'notes': (values['treatment'] ?? '').trim(),
    'prescription': (values['prescription'] ?? '').trim(),
    'veterinarian': (values['veterinarian'] ?? '').trim(),
    'soap': soap,
    'createdBy': authorUid,
    'createdAt': FieldValue.serverTimestamp(),
  };
}

Map<String, Map<String, dynamic>> readableSoap(Map<String, dynamic> visit) {
  final soap = recordMap(visit['soap']);
  if (soap.isNotEmpty) {
    return {
      for (final section in soapSections)
        section.key: recordMap(soap[section.key])
    };
  }
  return {
    'patient': {
      'patientName': recordText(visit['patientName']),
      'ownerName': recordText(visit['ownerName'])
    },
    'subjective': {},
    'objective': {},
    'assessment': {
      'primaryDiagnosis': recordText(visit['diagnosis']).isNotEmpty
          ? recordText(visit['diagnosis'])
          : recordText(visit['diagnosisSummary'])
    },
    'plan': {
      'treatment': recordText(visit['notes']),
      'prescription': recordText(visit['prescription'])
    },
    'signOff': {'veterinarian': recordText(visit['veterinarian'])},
  };
}
