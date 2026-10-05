import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetassist/screens/admin/evaluation_settings_screen.dart';
import 'package:vetassist/services/evaluation_settings_service.dart';
import 'package:vetassist/widgets/evaluation_card.dart';
import 'interface_test.dart' as preview;

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

  testWidgets('Evaluation settings visual preview', (tester) async {
    preview.configureView(tester, const Size(390, 844));
    final key = GlobalKey();
    await tester.pumpWidget(preview.app(RepaintBoundary(
        key: key,
        child: EvaluationSettingsScreen(
            load: () async => const EvaluationSettings(
                url: 'https://forms.gle/example', enabled: true)))));
    await tester.pumpAndSettle();
    await preview.capture(tester, key, 'evaluation_settings');
    await tester.ensureVisible(find.text('Evaluate VetAssist'));
    await tester.pumpAndSettle();
    await preview.capture(tester, key, 'evaluation_preview');
    expect(tester.takeException(), isNull);
  });

  test(
      'Validate Google Forms respondent links and reject unsafe or editor URLs',
      () {
    for (final link in [
      'https://forms.gle/Example123',
      ' https://docs.google.com/forms/d/e/example/viewform?usp=sharing ',
      'https://docs.google.com/forms/u/0/d/example/viewform'
    ]) {
      expect(googleFormUri(link), isNotNull, reason: link);
    }
    for (final link in [
      '',
      'https://forms.gle/',
      'http://forms.gle/example',
      'https://forms.gle.evil.com/example',
      'https://example.com',
      'javascript:alert(1)',
      'https://docs.google.com/forms/d/example/edit',
      'https://user:password@forms.gle/example',
      'https://forms.gle:8443/example',
      'https://forms.gle/example bad'
    ]) {
      expect(googleFormUri(link), isNull, reason: link);
    }
    expect(EvaluationSettings.fromMap(null).publicUri, isNull);
    expect(EvaluationSettings.fromMap({'url': 42, 'enabled': true}).publicUri,
        isNull);
    expect(const EvaluationSettings(url: 'https://forms.gle/example').publicUri,
        isNull);
  });

  testWidgets('Customer invitation updates live and disappears when disabled',
      (tester) async {
    final stream = StreamController<EvaluationSettings>();
    addTearDown(stream.close);
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: EvaluationCard(settingsStream: stream.stream))));
    expect(find.text('Evaluate VetAssist'), findsNothing);
    stream.add(const EvaluationSettings(
        url: 'https://forms.gle/example', enabled: true));
    await tester.pumpAndSettle();
    expect(find.text('Evaluate VetAssist'), findsOneWidget);
    stream.add(const EvaluationSettings(
        url: 'https://forms.gle/example', enabled: false));
    await tester.pumpAndSettle();
    expect(find.text('Evaluate VetAssist'), findsNothing);
    stream.addError(StateError('permission denied'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('Validate, save and disable the administrator form',
      (tester) async {
    final saves = <EvaluationSettings>[];
    await tester.pumpWidget(MaterialApp(
        home: EvaluationSettingsScreen(
      load: () async => const EvaluationSettings(),
      save: (settings) async => saves.add(settings),
    )));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byType(SwitchListTile));
    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Save changes'));
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();
    expect(saves, isEmpty);
    expect(find.text('Add a link before enabling evaluation.'), findsOneWidget);
    await tester.ensureVisible(find.byType(TextFormField));
    await tester.enterText(
        find.byType(TextFormField), ' https://forms.gle/example ');
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Save changes'));
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();
    expect(saves.single.url, 'https://forms.gle/example');
    expect(saves.single.enabled, isTrue);
    await tester.ensureVisible(find.byType(SwitchListTile));
    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Save changes'));
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();
    expect(saves.last.enabled, isFalse);
    expect(saves.last.url, saves.first.url);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Failed save retains draft and offers retry', (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: EvaluationSettingsScreen(
      load: () async => const EvaluationSettings(),
      save: (_) async => throw StateError('permission denied'),
    )));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byType(TextFormField), 'https://forms.gle/example');
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Save changes'));
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();
    expect(find.textContaining('We could not confirm'), findsOneWidget);
    expect(find.text('https://forms.gle/example'), findsOneWidget);
    expect(
        tester
            .widget<FilledButton>(
                find.byWidgetPredicate((widget) => widget is FilledButton))
            .onPressed,
        isNotNull);
  });

  testWidgets('Loading failure provides a retry', (tester) async {
    var calls = 0;
    await tester
        .pumpWidget(MaterialApp(home: EvaluationSettingsScreen(load: () async {
      if (++calls == 1) throw StateError('offline');
      return const EvaluationSettings();
    })));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.byType(TextFormField), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Editor fits a narrow phone with large text', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(1.8)),
            child: child!),
        home: EvaluationSettingsScreen(
            load: () async => const EvaluationSettings(
                url: 'https://forms.gle/example', enabled: true))));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Save changes'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
