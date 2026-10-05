import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vetassist/screens/login_screen.dart';

void main() {
  testWidgets('Customer login screen renders correctly',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: CustomerLoginScreen(),
      ),
    );

    expect(find.text('Sign in'), findsOneWidget);
    expect(find.byType(TextField), findsNWidgets(2));
    expect(find.text('Google'), findsOneWidget);
  });
}
