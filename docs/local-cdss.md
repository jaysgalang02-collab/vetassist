# Local clinical decision support

The app computes symptom suggestions locally. Firebase remains responsible for
authentication and role checks. The service does not call a language-model API.

The implementation follows the supplied document's symptom pipeline: keyword
NLP with English/Filipino aliases and limited negation handling, species-specific
rules, and a Naive Bayes classifier when a trained model is installed. The
current bundled model is explicitly **untrained**. Current scores are the
fraction of a rule's symptoms that match; they are not disease probabilities.
Unreported symptoms are unknown. NLP is a limited keyword parser, not a general
conversation model; each message is assessed independently.

Customer responses contain first aid and veterinary contact guidance only.
Staff responses include possible conditions and explain the matching symptoms.
Clinical validation of the rules, language parser, and model is still required.

## Published clinical reference dataset

The staff CDSS screen also provides an offline browser of 17 published clinical
record rows (9 canine, 8 feline), downloaded from Mendeley Data, DOI
`10.17632/6cjnjmtv2h.1`, CC BY 4.0, by Ariel Hernandez Camacho (2026). Sixteen
rows have reported diagnoses. The original Spanish clinical text and all
source fields are preserved, and the CSV hash matches the repository checksum.
These are urogenital reference examples with repeated IDs and mixed/missing
diagnoses; they do not train or validate the six-disease classifier. See
`datasets/clinical_reference/README.md` and the in-app source notice.

## Supplied Drive folder

Folder: https://drive.google.com/drive/folders/1_XCZw2J_9Ce86Tpq-zGI1gHz-z5DuX3h

The public folder listing inspected on October 4, 2026 contains:

- `Dog and Cat Classification.zip`, file ID `1cbb66h-B-YN8eRIqAY1IpMH-RoB_ibm3`.
- `kagglecatsanddogs_5340.zip`, file ID `17bYEWEU4g6AbR0NN_v62OYMAZ04mg3N6`.

Only the folder listing was inspected; the archives were not downloaded or
used for training. Their names suggest dog/cat image classification. Species
image labels alone do not provide disease labels or clinical symptom data.
No trained image model is installed, and attached photos do not influence
symptoms, suggestions, or urgency. The interface states this explicitly.

## Train a disease model from real labeled cases

The `datasets/` folder now contains 30 explicitly synthetic labeled demo
examples, a CSV copy, disease/symptom dictionaries, a manifest, and a separately
trained demo model. See `datasets/README.md`. These examples are generated from
the existing rules and were not obtained from the supplied Drive folder. Demo
training requires `--demo`, and demo models cannot be loaded for patient care.
The bundled clinical model remains untrained.

Use a JSON array of de-identified, independently labeled patient cases. Each
object must contain `caseId`, `patientId`, `species`, `disease`, and `symptoms`.
Use one case per patient, unique IDs, and symptom IDs from
`lib/services/symptom_engine.dart`. Disease labels must match that file's
supported species-specific disease rules. At least two disease classes and
five independent patients per class are required for each included species.
Do not substitute rule descriptions or invented cases for observed cases.

Run from the project directory:

```sh
dart run tool/train_symptom_model.dart path/to/real-labeled-cases.json lib/assets/symptom_model.json
```

The tool uses a reproducible seed of 42, stratifies by species/disease, reserves
20% per class for holdout testing, and fits class priors and symptom frequencies
on the remaining cases. Laplace smoothing avoids zero likelihoods. Prediction
uses reported positive symptoms only and normalizes scores across the modeled
diseases for the selected species. It falls back to rules for a species with no
trained classes. The training artifact records the input SHA-256 and counts.

The companion `symptom_model.json.evaluation.json` records actual holdout
accuracy and a confusion matrix. Test fixtures are synthetic software checks
and are never installed as the app's trained model. Dataset-specific accuracy
is not clinical validation, and model estimates are not calibrated diagnostic
probabilities. Rebuild the app after installing a model asset.

## Checks

```sh
flutter test
flutter analyze
```

Tests cover language extraction/negation, species separation, customer output,
model loading, trained-frequency inference, training provenance, holdout
separation, and duplicate-patient rejection. Live Firebase account and device
checks remain separate from automated tests.

First aid contact/transport guidance is based on the Merck Veterinary Manual:
https://www.merckvetmanual.com/special-pet-topics/emergencies/what-to-do-in-a-dog-or-cat-emergency
Emergency-sign escalation is based on its triage guidance:
https://www.merckvetmanual.com/emergency-medicine-and-critical-care/evaluation-and-initial-treatment-of-small-animal-emergency-patients/initial-triage-and-resuscitation-of-small-animal-emergency-patients

The removed hardcoded credential must be revoked by its account owner. Local
source removal does not revoke credentials or rewrite existing Git history.
