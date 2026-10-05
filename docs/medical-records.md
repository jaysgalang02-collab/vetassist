# SOAP medical records

The uploaded veterinary SOAP template is implemented through a shared editor.
Staff can open it from **Patients > Add visit/treatment** or
**Clinic tools > Visits & treatments > New SOAP record**. Customers open the
saved record from their pet's **Visits** tab.

## Stored format

Existing `visits/{recordId}` documents are retained. New records add
`schemaVersion: 2`, `recordType: "soap"`, `createdBy`, and these nested maps:

- `soap.patient`: recordNo, patientName, species, breed, sex,
  reproductiveStatus, age, weightKg, ownerName, contact.
- `soap.subjective`: chiefComplaint, history, intake, symptoms,
  medicationsHistory, ownerConcerns.
- `soap.objective`: temperature, heartRate, respiratoryRate, weightKg, bcs,
  general, hydration, mmCrt, eyesEarsNose, oral, skinCoat, cardiovascular,
  respiratory, gi, urinaryReproductive, musculoskeletal, neurologic,
  otherFindings, additionalParameters.
- `soap.assessment`: primaryDiagnosis, differentialDiagnoses, interpretation.
- `soap.plan`: diagnostics, treatment, prescription, homeCare, followUp.
- `soap.signOff`: veterinarian, licenseNo, staffInitials, signature, date.

Clinical entries are trimmed strings. Blank means not recorded; the app does
not infer a normal finding or an unknown patient's age. Measurement fields
accept positive finite numbers; BCS includes the clinician's chosen scale.
Weight is entered once and copied into the objective section.

`date` remains the visit Timestamp. The signature is an optional array of
normalized `{x, y, start}` stroke maps (maximum 4,000 points); its date is null
when no signature was drawn. A drawn signature requires the veterinarian's
name and license/registration number. It is a captured handwritten signature,
not a cryptographic verification of identity.

Top-level `ownerUid`, `patientId`, `clinicId`, `date`, `diagnosis`, `notes`,
`diagnosisSummary`, `prescription`, `veterinarian`, and `createdAt` maintain
compatibility with existing dashboards, reports and visit data consumers.
Patient and owner names/contact are visit snapshots; editing the form does
not modify the patient or user profiles.

## Saving and reading

The patient and clinic are loaded before editing. Saves use a Firestore
transaction to recheck clinic and owner assignment. A single document ID is
allocated for the editor session, so retries reuse that record. Save
confirmation has a 20-second deadline. An unconfirmed write may still finish;
retrying uses the same ID, and errors preserve the form entries. The save
button prevents concurrent taps and leaving during an active save.

Existing documents need no migration. The viewer supports both historical
`diagnosis/notes` and `diagnosisSummary/prescription` fields. New history
queries filter only by clinicId or patientId and sort by visit date locally,
avoiding a new composite index. Lists show 10 records per UI page; this is
display pagination, not server-side query pagination.

Firestore authentication and authorization rules remain unchanged. Production
rules must continue to authorize the intended staff and pet-owner access;
local UI validation does not replace those rules.

## Verification

`flutter test test/soap_record_test.dart` covers all six sections at phone,
small-screen, large-text, landscape and tablet sizes; keyboard layout; old
record compatibility; serialization; numeric validation; required fields;
signatures; and failed-save retry behavior.

Live Firebase permissions and actual device persistence still require an
end-to-end check with a clinic account and a pet owner account.
