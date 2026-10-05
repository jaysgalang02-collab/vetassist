import 'dart:convert';

import 'package:flutter/services.dart';

class ClinicalReferenceDataset {
  final Map<String, dynamic> source;
  final List<Map<String, dynamic>> records;

  ClinicalReferenceDataset.fromJson(Map<String, dynamic> data)
      : source = Map<String, dynamic>.from(data['source'] as Map),
        records = (data['records'] as List)
            .map((row) => Map<String, dynamic>.from(row as Map))
            .toList() {
    if (data['schemaVersion'] != 1 ||
        data['datasetKind'] != 'publisher_reported_clinical_records') {
      throw const FormatException('Unsupported clinical reference dataset.');
    }
    if (records.map((row) => row['recordId']).toSet().length !=
        records.length) {
      throw const FormatException('Reference row IDs must be unique.');
    }
  }

  List<Map<String, dynamic>> search(String query, {String species = 'all'}) {
    final needle = query.trim().toLowerCase();
    return records.where((row) {
      if (species != 'all' && row['species'] != species) return false;
      return needle.isEmpty ||
          [
            row['reportedDiagnosis'],
            row['clinicalHistory'],
            row['physicalExam'],
            row['recordId']
          ].any((value) => value.toString().toLowerCase().contains(needle));
    }).toList();
  }
}

Future<ClinicalReferenceDataset> loadClinicalReferenceDataset() async {
  final text =
      await rootBundle.loadString('lib/assets/clinical_reference.json');
  return ClinicalReferenceDataset.fromJson(
      jsonDecode(text) as Map<String, dynamic>);
}
