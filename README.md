# vetassist

A Flutter application connecting pet owners with veterinary clinics.

## Interface

The shared Material 3 theme lives in `lib/theme/vet_theme.dart`. It uses a
forest-green palette, warm backgrounds, readable cards, and consistent form
controls. Reusable branding, responsive actions, and motion components live in
`lib/widgets/brand_widgets.dart`.

- Portal selection and sign-in adapt to phone, landscape, and tablet layouts.
- Booking keeps the clinic approval step explicit; the customer dashboard
  highlights booking, pet profiles, and clinic chat.
- Staff appointment filters separate pending, today, upcoming, approved, and
  declined bookings without changing the existing Firestore schema.
- Entrance and customer-tab animations honor the system's reduced-motion setting.
  Switching customer tabs retains existing form and chat state.

Run the layout, navigation, keyboard, and reduced-motion checks with:

```sh
flutter test test/interface_test.dart test/widget_test.dart
```

Optional rendered previews are written to the ignored `build/ui_previews/`
directory:

```sh
flutter test --dart-define=CAPTURE_UI=true test/interface_test.dart
```

Set the `UI_FONT_PATH` environment variable to a local Roboto TTF when generating
previews to use readable text instead of Flutter's test font. These widget tests
do not authenticate against Firebase. Verify registration, booking approval,
notifications, and chat using test accounts on a device before publishing.

## Getting Started

### Clinic workspace

Staff now land on a clinic overview with counts for approved visits today,
unread customer messages, and pending booking requests. Message previews open
the existing conversation at the selected message. Appointment shortcuts open
the matching schedule filter. Home, Messages, Schedule, and Patients are always
visible in the bottom navigation; clinical support, vaccines, visits, reports,
and staff codes are under More.

The overview reads the existing clinic-scoped bookings and inbox collections.
It does not mark messages read merely by displaying them. Each section has
independent loading, empty, and error states, and previews remain short with
links to the full lists. Patient search filters the clinic's records locally
to avoid requiring a composite search index.

Run `flutter test test/clinic_workspace_test.dart` to check counts, date
boundaries, unread state, navigation, and responsive layouts. The optional
`CAPTURE_UI` flag described above also generates clinic dashboard previews
using sample records. Test live booking approvals and message delivery with
clinic/customer test accounts before releasing.

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Local decision support

See [local CDSS implementation and training](docs/local-cdss.md) for the symptom rules, NLP, actual model status, dataset requirements, and validation steps.
