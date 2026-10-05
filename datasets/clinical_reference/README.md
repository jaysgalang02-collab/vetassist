# Published clinical reference records

Source: Hernandez Camacho, Ariel (2026), *Urogenital Disease's Clinical Cases
Records in Veterinary Patients I*, Mendeley Data, V1.

- DOI: https://doi.org/10.17632/6cjnjmtv2h.1
- Repository: https://data.mendeley.com/datasets/6cjnjmtv2h/1
- License: CC BY 4.0, https://creativecommons.org/licenses/by/4.0/
- Published: September 22, 2026.

The publisher describes anonymised canine/feline records from a Caribbean
small-animal practice, covering January–June 2025. The dataset has original
clinical histories, physical examinations, differential diagnoses, laboratory
and imaging results, and a reported definitive-diagnosis field. VetAssist has
not independently confirmed the underlying diagnoses or anonymisation process.

The downloaded CSV contains **17 record rows**, including 9 canine rows and 8
feline rows. Sixteen rows contain a reported diagnosis; the remaining row says
`NONE`. Source IDs 1, 3, and 4 are repeated. We therefore do not claim 17
independent patients. Several labels contain multiple conditions; they have
not been forced into single disease classes.

## Files and transformations

`raw/UROGENITAL_DATASET-1.csv` is the unmodified source file. Its SHA-256 is:

`3584defbb504589e5983fa91fde0eded735019d765efc3b4317ecbf9652711d7`

This matches the file checksum supplied by the Mendeley public file metadata.
`clinical_cases.json` preserves every original field, adds a unique record ID
per CSV row, normalizes only the species spellings (`CANIN0`/`CANINO` to canine,
`FELINE`/`FELINO` to feline), and flags missing diagnoses. No symptoms, patient
cases, translations, or confirmed disease labels were invented. Primarily
Spanish notes remain in their original language. `source_manifest.json`
records provenance, attribution, transformations, counts, and limitations.

Reproduce the JSON import using a Python installation from the project folder:

```sh
python tool/import_clinical_reference.py
```

## Actual application use

Staff can open **Clinical decision support → Published clinical cases** to
search original clinical notes, filter by species, and read the complete
published source fields offline. Source, DOI, license, and limitations are
displayed in that screen. These are reference examples; they are not live
clinic patients, are not inserted into Firestore, and are not diagnoses of the
current patient. The source creator does not endorse VetAssist.

This dataset is **not used to train the six-disease symptom classifier**.
It describes urogenital conditions outside that classifier's supported labels,
has very few records per condition, includes repeated IDs, and includes mixed
or missing diagnoses. Training would require a reviewed condition vocabulary,
clinical symptom annotation, sufficient independent patients per class, and
independent evaluation. The bundled symptom model remains untrained. The
synthetic demonstration dataset remains separately labeled synthetic.
