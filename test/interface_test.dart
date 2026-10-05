import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetassist/screens/admin/admin_login_screen.dart';
import 'package:vetassist/screens/create_account_screen.dart';
import 'package:vetassist/screens/login_screen.dart';
import 'package:vetassist/screens/portal_picker.dart';
import 'package:vetassist/screens/splash_screen.dart';
import 'package:vetassist/theme/vet_theme.dart';
import 'package:vetassist/widgets/brand_widgets.dart';

const capturePreviews = bool.fromEnvironment('CAPTURE_UI');

void configureView(WidgetTester tester, Size size) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetViewInsets);
}

Widget app(Widget child,
    {double scale = 1,
    bool reduceMotion = false,
    RouteFactory? onGenerateRoute}) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: VetTheme.light,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(scale),
          disableAnimations: reduceMotion),
      child: child!,
    ),
    onGenerateRoute: onGenerateRoute,
    home: child,
  );
}

Future<void> capture(WidgetTester tester, GlobalKey key, String name) async {
  if (!capturePreviews) return;
  await tester.runAsync(() => precacheImage(
      const AssetImage('lib/assets/logo.png'), key.currentContext!));
  await tester.pumpAndSettle();
  await tester.runAsync(() async {
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 2);
    try {
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final directory = Directory('build/ui_previews');
      await directory.create(recursive: true);
      await File('${directory.path}/$name.png')
          .writeAsBytes(bytes!.buffer.asUint8List());
    } finally {
      image.dispose();
    }
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  WidgetController.hitTestWarningShouldBeFatal = true;

  setUpAll(() async {
    final fontPath = Platform.environment['UI_FONT_PATH'];
    if (capturePreviews && fontPath != null) {
      final bytes = ByteData.sublistView(await File(fontPath).readAsBytes());
      final loader = FontLoader('Roboto');
      loader.addFont(Future.value(bytes));
      await loader.load();
      final icons = FontLoader('MaterialIcons');
      icons.addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
      await icons.load();
    }
  });

  for (final viewport in [
    (name: 'small', size: const Size(320, 640), scale: 1.0),
    (name: 'phone', size: const Size(390, 844), scale: 1.0),
    (name: 'landscape', size: const Size(844, 390), scale: 1.0),
    (name: 'tablet', size: const Size(1024, 768), scale: 1.0),
    (name: 'large_text', size: const Size(320, 640), scale: 2.0),
  ]) {
    testWidgets('Portal remains usable at ${viewport.name}', (tester) async {
      configureView(tester, viewport.size);
      final boundaryKey = GlobalKey();
      await tester.pumpWidget(RepaintBoundary(
        key: boundaryKey,
        child: app(const PortalPicker(), scale: viewport.scale),
      ));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      if (viewport.name == 'phone' || viewport.name == 'tablet') {
        await capture(tester, boundaryKey, 'portal_${viewport.name}');
      }
      await tester.ensureVisible(find.text('Create a pet owner account'));
      await tester.pumpAndSettle();
      expect(find.text('Create a pet owner account').hitTestable(),
          findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Login stays scrollable at ${viewport.name}', (tester) async {
      configureView(tester, viewport.size);
      final boundaryKey = GlobalKey();
      await tester.pumpWidget(RepaintBoundary(
        key: boundaryKey,
        child: app(const CustomerLoginScreen(), scale: viewport.scale),
      ));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      if (viewport.name == 'phone') {
        await capture(tester, boundaryKey, 'login_phone');
      }
      await tester.scrollUntilVisible(find.text('Sign in'), 200,
          scrollable: find.byType(Scrollable).first);
      await tester.pumpAndSettle();
      expect(find.text('Sign in').hitTestable(), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Staff login'), 200,
          scrollable: find.byType(Scrollable).first);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }

  for (final portal in [
    (label: 'Pet owner', route: CustomerLoginScreen.route, arguments: null),
    (label: 'Staff / Vet', route: StaffLoginScreen.route, arguments: null),
    (
      label: 'Create a pet owner account',
      route: CreateAccountScreen.route,
      arguments: 'customer'
    ),
  ]) {
    testWidgets('${portal.label} opens the correct flow', (tester) async {
      configureView(tester, const Size(390, 844));
      RouteSettings? received;
      await tester
          .pumpWidget(app(const PortalPicker(), onGenerateRoute: (settings) {
        received = settings;
        return MaterialPageRoute<void>(
            builder: (_) => const Scaffold(body: Text('Destination')));
      }));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text(portal.label));
      await tester.tap(find.text(portal.label));
      await tester.pumpAndSettle();
      expect(received?.name, portal.route);
      expect(received?.arguments, portal.arguments);
      expect(find.text('Destination'), findsOneWidget);
    });
  }

  testWidgets('Administrator access remains available', (tester) async {
    RouteSettings? received;
    await tester
        .pumpWidget(app(const PortalPicker(), onGenerateRoute: (settings) {
      received = settings;
      return MaterialPageRoute<void>(builder: (_) => const Scaffold());
    }));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Administrator sign in'));
    await tester.pumpAndSettle();
    expect(received?.name, AdminLoginScreen.route);
  });

  testWidgets('Password visibility works with the keyboard open',
      (tester) async {
    configureView(tester, const Size(390, 844));
    await tester.pumpWidget(app(const CustomerLoginScreen()));
    await tester.pumpAndSettle();
    final password = find.byType(TextField).last;
    await tester.enterText(password, 'example password');
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byTooltip('Show password'));
    await tester.tap(find.byTooltip('Show password'));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(password).obscureText, isFalse);
    await tester.ensureVisible(find.text('Sign in'));
    await tester.pumpAndSettle();
    expect(find.text('Sign in').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Care actions adapt and remain tappable with large text',
      (tester) async {
    configureView(tester, const Size(320, 640));
    var taps = 0;
    await tester.pumpWidget(app(
        Scaffold(
            body: ListView(children: [
          CareHero(
            eyebrow: 'CARE, ONE VISIT AT A TIME',
            title: 'Make time for their wellbeing.',
            subtitle: 'Choose a time and request a visit with your clinic.',
            action: FilledButton(
                onPressed: () => taps++, child: const Text('Book a visit')),
          ),
          AdaptiveActions(children: [
            OutlinedButton(
                onPressed: () => taps++, child: const Text('Vaccinations')),
            OutlinedButton(onPressed: () => taps++, child: const Text('Chat')),
          ]),
        ])),
        scale: 2));
    await tester.pumpAndSettle();
    for (final label in ['Book a visit', 'Vaccinations', 'Chat']) {
      await tester.scrollUntilVisible(find.text(label), 200);
      await tester.pumpAndSettle();
      await tester.tap(find.text(label));
    }
    expect(taps, 3);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Entrance honors reduced motion', (tester) async {
    await tester.pumpWidget(app(
      const Scaffold(body: Entrance(child: Text('Ready'))),
      reduceMotion: true,
    ));
    expect(find.text('Ready'), findsOneWidget);
    expect(
        find.descendant(
            of: find.byType(Entrance),
            matching: find.byType(TweenAnimationBuilder<double>)),
        findsNothing);
  });

  for (final reduceMotion in [false, true]) {
    testWidgets('Tab transitions retain drafts (reduced motion: $reduceMotion)',
        (tester) async {
      var selected = 0;
      late StateSetter selectTab;
      await tester.pumpWidget(app(StatefulBuilder(builder: (context, setState) {
        selectTab = setState;
        return Scaffold(
            body: MotionTabStack(index: selected, children: const [
          TextField(decoration: InputDecoration(labelText: 'Draft')),
          Center(child: Text('Second tab')),
        ]));
      }), reduceMotion: reduceMotion));
      await tester.enterText(find.byType(TextField), 'Unsaved note');
      selectTab(() => selected = 1);
      await tester.pumpAndSettle();
      expect(find.text('Second tab'), findsOneWidget);
      expect(tester.testTextInput.isVisible, isFalse);
      selectTab(() => selected = 0);
      await tester.pumpAndSettle();
      expect(find.text('Unsaved note'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Splash moves to the existing authentication gate',
      (tester) async {
    await tester
        .pumpWidget(app(const SplashScreen(), onGenerateRoute: (settings) {
      expect(settings.name, '/auth');
      return MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('Auth gate')));
    }));
    await tester.pump(const Duration(milliseconds: 1200));
    await tester.pumpAndSettle();
    expect(find.text('Auth gate'), findsOneWidget);
  });

  testWidgets('Disposing splash cancels pending navigation', (tester) async {
    await tester.pumpWidget(app(const SplashScreen()));
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 2));
    expect(tester.takeException(), isNull);
  });
}
