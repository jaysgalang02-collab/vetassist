# App evaluation

Administrators open the gear button in Admin Workspace > App settings.
Paste the published Google Form respondent link, enable Show evaluation to
users, preview, and save. Customers see Evaluate VetAssist on Home and
Profile. Disabling evaluation hides both entries without deleting the link.
Changes arrive through a Firestore listener; offline clients receive the
updated setting after reconnecting. No app rebuild is needed to change the URL.

## Firestore document

`app_settings/evaluation`:

- `url`: trimmed HTTPS Google Forms respondent URL (`forms.gle` or
  `docs.google.com/forms/.../viewform`).
- `enabled`: Boolean, defaults to false if the document is absent.
- `updatedAt`: server timestamp.
- `updatedBy`: administrator UID.

The app validates administrator access before saving. Production Firestore
rules must also permit authenticated users to read this document and restrict
its writes to the application's verified administrators. This repository has
no Firestore rules source; no live rules were modified or deployed.

Missing, disabled, invalid, or unavailable settings never block customer
navigation. Invalid links cannot be saved. Browser launch errors offer a copy
link fallback. Responses stay in the Google account that owns the form.
