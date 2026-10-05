# VetAssist labeled demo datasets

The `demo_*` files and the disease/symptom dictionaries contain **synthetic
software examples**, not observed veterinary patients. No Drive archive,
clinic records, or clinical study was used to create these demo rows.
Disease labels are assigned from the existing application rules,
not confirmed diagnoses. A veterinarian has not validated this demo dataset.

The separate `clinical_reference/` subfolder contains downloaded, publisher-
reported clinical records with original diagnosis labels, DOI, license, raw
CSV, verified source hash, and a source-preserving JSON adaptation. These
records are used in the app's published-case reference browser, not as
training data for the six-disease classifier. See its README for details.

## Files

- `demo_labeled_cases.json`: 30 labeled examples in the trainer's input format.
- `demo_labeled_cases.csv`: the same examples for inspection; symptom IDs use `|`.
- `disease_labels.json`: six species-specific disease IDs, rule symptom mappings,
  and veterinary background references.
- `symptom_vocabulary.json`: 12 symptom IDs with the app's English/Filipino aliases.
- `dataset_manifest.json`: counts, origin, intended use, and limitations.
- `demo_symptom_model.json`: separately trained demo model with source SHA-256.
- `demo_symptom_model.json.evaluation.json`: demonstration holdout results.

Canine labels are `parvovirus`, `distemper`, and `heartworm`. Feline labels are
`feline_leukemia`, `fiv`, and `feline_uri`. Each label has five generated rows.
These are overlapping symptom associations, not diagnostic rules established
by the references. The references provide background reading only; they do not
contain these generated cases or validate the complete application mapping.

## Reproduce the demonstration

From the project folder:

```sh
dart run tool/create_demo_dataset.dart
dart run tool/train_symptom_model.dart datasets/demo_labeled_cases.json datasets/demo_symptom_model.json --demo
```

The split has 24 training examples and 6 held-out examples. The rows are
correlated subsets of the same rules, and some patterns repeat. The holdout
score measures this software demonstration only; it must not be reported as
clinical accuracy or evidence of performance on real patients.

The trainer requires `--demo` for these rows and rejects the clinical asset
path. The app loader also rejects a model marked `synthetic_demo`. The app's
bundled `lib/assets/symptom_model.json` remains untrained and uses symptom rules.
This demo model does not perform image analysis.

## Collect real labels

Use de-identified records labeled by a veterinarian. A clinical input row needs
unique `caseId` and `patientId`, `species`, a confirmed supported `disease` ID,
and observed `symptoms` IDs. Keep the diagnosis confirmation, original source,
and relevant dates in your controlled data collection records. Do not rename
synthetic patients or remove their origin fields to make them appear observed.
Use one patient per row in the current trainer; reserve independent patients
for testing. Clinical labels and disease coverage require expert review.

See `docs/local-cdss.md` for the real-case training command and limitations.
