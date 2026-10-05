import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetassist/screens/admin/admin_workspace.dart';
import 'package:vetassist/screens/admin/admin_clinic_editor.dart';
import 'interface_test.dart' as preview;

Widget overview(
        ValueChanged<int> onSelect, VoidCallback onCreate) =>
    AdminOverview(
        totals: const [
          128,
          246,
          18,
          6
        ],
        clinics: const [
          'Greenwood Veterinary Clinic',
          'Paws & Care Animal Hospital'
        ],
        activeClinics: 5,
        name: 'Alex',
        onSelect: onSelect,
        onCreateClinic: onCreate);

void main() {
  setUpAll(() async {
    if (preview.capturePreviews) {
      final font = FontLoader('Roboto')
        ..addFont(Future.value(ByteData.sublistView(
            await File('C:/Windows/Fonts/arial.ttf').readAsBytes())));
      await font.load();
      final icons = FontLoader('MaterialIcons')
        ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
      await icons.load();
    }
  });

  for (final viewport in [
    (name: 'small', size: const Size(320, 640), scale: 1.0),
    (name: 'phone', size: const Size(390, 844), scale: 1.0),
    (name: 'large_text', size: const Size(320, 640), scale: 1.8),
    (name: 'desktop', size: const Size(1280, 900), scale: 1.0),
  ]) {
    testWidgets('Admin navigation and overview at ${viewport.name}',
        (tester) async {
      preview.configureView(tester, viewport.size);
      var index = 0;
      var creates = 0;
      var signouts = 0;
      final key = GlobalKey();
      await tester.pumpWidget(preview.app(
          RepaintBoundary(
              key: key,
              child: StatefulBuilder(builder: (context, setState) {
                void select(int next) => setState(() => index = next);
                return AdminWorkspace(
                    index: index,
                    onSelect: select,
                    onSignOut: () => signouts++,
                    onCreateClinic: () => creates++,
                    pages: [
                      overview(select, () => creates++),
                      for (var i = 1; i < 5; i++)
                        Center(child: Text('Directory $i'))
                    ]);
              })),
          scale: viewport.scale));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await preview.capture(tester, key, 'admin_${viewport.name}');
      await tester.ensureVisible(find.text('Register a clinic'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Register a clinic'));
      expect(creates, 1);
      for (var i = 1; i < 5; i++) {
        await tester.tap(find.byIcon(adminIcons[i]).last);
        await tester.pumpAndSettle();
        expect(find.text('Directory $i').hitTestable(), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
      await tester.tap(find.text('New clinic'));
      expect(creates, 2);
      await tester.tap(find.byTooltip('Sign out'));
      expect(signouts, 1);
    });
  }

  testWidgets('Long record details and team controls fit on narrow screens',
      (tester) async {
    preview.configureView(tester, const Size(320, 640));
    var toggles = 0;
    await tester.pumpWidget(preview.app(
        Scaffold(
            body: ListView(padding: const EdgeInsets.all(20), children: [
          AdminRecordCard(
              title: 'Dr. Alexandra Maria Santiago',
              subtitle:
                  'alexandra.santiago@example.com\nClinic: Greenwood Veterinary Clinic',
              icon: Icons.badge_outlined,
              badge: const AdminBadge(label: 'SUPERADMIN'),
              actions: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    const Text('Admin flag'),
                    Switch(value: true, onChanged: (_) => toggles++),
                    IconButton(
                        onPressed: () {}, icon: const Icon(Icons.more_vert)),
                    IconButton(
                        onPressed: () {},
                        icon: const Icon(Icons.delete_outline)),
                  ])),
        ])),
        scale: 1.8));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byType(Switch));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Switch));
    expect(toggles, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'Clinic editor validates, survives keyboard, and retries failed saves',
      (tester) async {
    preview.configureView(tester, const Size(320, 640));
    var saves = 0;
    await tester.pumpWidget(
        preview.app(Scaffold(body: AdminClinicEditor(onSave: (data) async {
      saves++;
      expect(data['name'], 'New clinic');
      throw StateError('offline');
    })), scale: 1.4));
    await tester.scrollUntilVisible(find.text('Create clinic'), 200,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Create clinic'));
    await tester.pumpAndSettle();
    expect(saves, 0);
    await tester.ensureVisible(find.byType(TextFormField).first);
    await tester.enterText(find.byType(TextFormField).first, 'New clinic');
    tester.view.viewInsets = const FakeViewPadding(bottom: 260);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Create clinic'), 150,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Create clinic'));
    await tester.pumpAndSettle();
    expect(saves, 1);
    expect(find.text('Unable to save. Check your connection and try again.'),
        findsOneWidget);
    await tester.ensureVisible(find.text('Create clinic'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create clinic'));
    await tester.pumpAndSettle();
    expect(saves, 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Overview supports reduced motion and unavailable totals',
      (tester) async {
    await tester.pumpWidget(preview.app(
        Scaffold(
            body: AdminOverview(
                totals: const [null, null, null, null],
                clinics: const [],
                activeClinics: null,
                name: 'Admin',
                onSelect: (_) {},
                onCreateClinic: () {},
                hasError: true)),
        reduceMotion: true));
    await tester.pumpAndSettle();
    expect(find.text('—'), findsNWidgets(4));
    expect(tester.takeException(), isNull);
  });
}
