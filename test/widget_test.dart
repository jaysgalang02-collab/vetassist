// test/widget_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Import your main.dart and the specific login screen you want to test
import 'package:vetassist/main.dart';
import 'package:vetassist/screens/login_screen.dart'; // this gives CustomerLoginScreen & StaffLoginScreen

void main() {
  testWidgets('Customer login screen renders correctly', (WidgetTester tester) async {
    // Pump just the CustomerLoginScreen wrapped in a MaterialApp shell.
    await tester.pumpWidget(
      const MaterialApp(
        home: CustomerLoginScreen(),
      ),
    );

    // Smoke tests — confirm UI elements exist.
    expect(find.text('Sign in'), findsOneWidget);
    expect(find.byType(TextField), findsNWidgets(2)); // email + password
    expect(find.text('Google'), findsOneWidget);
  });
}
