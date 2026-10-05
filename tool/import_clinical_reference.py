import csv
import hashlib
import json
from collections import Counter
from pathlib import Path

root = Path(__file__).resolve().parents[1]
source_dir = root / 'datasets' / 'clinical_reference'
raw_file = source_dir / 'raw' / 'UROGENITAL_DATASET-1.csv'
expected_hash = '3584defbb504589e5983fa91fde0eded735019d765efc3b4317ecbf9652711d7'
digest = hashlib.sha256(raw_file.read_bytes()).hexdigest()
if digest != expected_hash:
    raise ValueError('The raw CSV does not match Mendeley version 1.')
with raw_file.open(encoding='utf-8-sig', newline='') as stream:
    rows = list(csv.DictReader(stream))
species_map = {'CANIN0': 'canine', 'CANINO': 'canine', 'FELINE': 'feline', 'FELINO': 'feline'}
records = []
for row_number, row in enumerate(rows, 1):
    if None in row or any(value is None for value in row.values()):
        raise ValueError(f'Malformed CSV row {row_number}')
    species_raw = row['ESPECIE'].strip()
    if species_raw not in species_map:
        raise ValueError(f'Unknown species at row {row_number}')
    diagnosis = row['DIAGNOSTICO DEFINITIVO']
    records.append({
        'recordId': f'mendeley-6cjnjmtv2h-v1-row-{row_number:02d}',
        'sourceRowNumber': row_number,
        'sourcePatientId': row['ID'],
        'species': species_map[species_raw],
        'originalSpecies': species_raw,
        'reportedDiagnosis': diagnosis,
        'hasReportedDiagnosis': diagnosis.strip().upper() not in ('', 'NONE'),
        'clinicalHistory': row['HISTORIA CLINICA'],
        'physicalExam': row['EXAMEN FISICO'],
        'sourceFields': row,
        'dataKind': 'publisher_reported_clinical_record',
        'independentDiagnosisVerification': 'Not performed by VetAssist',
    })
ids = Counter(row['ID'] for row in rows)
metadata = {
    'title': "Urogenital Disease's Clinical Cases Records in Veterinary Patients I",
    'author': 'Ariel Hernandez Camacho',
    'repository': 'Mendeley Data',
    'version': 1,
    'doi': '10.17632/6cjnjmtv2h.1',
    'sourceUrl': 'https://data.mendeley.com/datasets/6cjnjmtv2h/1',
    'license': 'CC BY 4.0',
    'licenseUrl': 'https://creativecommons.org/licenses/by/4.0/',
    'publicationDate': '2026-09-22',
    'publisherReportedRecordPeriod': 'January to June 2025',
    'publisherReportedSetting': 'Small animal clinical practice in the Caribbean',
    'sourceLanguage': 'Primarily Spanish, preserved without machine translation',
    'rawFile': 'UROGENITAL_DATASET-1.csv',
    'rawSha256': digest,
    'recordRows': len(records),
    'recordsWithReportedDiagnosis': sum(record['hasReportedDiagnosis'] for record in records),
    'speciesCounts': dict(Counter(record['species'] for record in records)),
    'repeatedSourceIds': {key: count for key, count in ids.items() if count > 1},
    'independentPatientCount': None,
    'transformation': 'CSV to JSON; preserved every source field; added unique row IDs; normalized species spelling only; flagged NONE/blank diagnoses. No synthetic symptoms or disease labels added.',
    'usage': 'Read-only published clinical reference examples. Not used to train the six-disease symptom classifier.',
    'limitations': '17 rows; repeated patient IDs; one row without a reported diagnosis; urogenital scope differs from the existing model. Independent clinical validation and patient independence were not established.',
    'attribution': "Hernandez Camacho, Ariel (2026), Urogenital Disease's Clinical Cases Records in Veterinary Patients I, Mendeley Data, V1, doi:10.17632/6cjnjmtv2h.1. CC BY 4.0. Adapted to JSON by VetAssist; no endorsement implied.",
}
dataset = {'schemaVersion': 1, 'datasetKind': 'publisher_reported_clinical_records', 'source': metadata, 'records': records}
encoded = json.dumps(dataset, ensure_ascii=False, indent=2) + '\n'
(source_dir / 'clinical_cases.json').write_text(encoded, encoding='utf-8')
(root / 'lib' / 'assets' / 'clinical_reference.json').write_text(encoded, encoding='utf-8')
(source_dir / 'source_manifest.json').write_text(json.dumps(metadata, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
assert all(record['sourceFields'] == row for record, row in zip(records, rows))
print(f'Imported {len(records)} source rows; {metadata["recordsWithReportedDiagnosis"]} have publisher-reported diagnoses. Source SHA-256 verified. Clinical model unchanged.')
