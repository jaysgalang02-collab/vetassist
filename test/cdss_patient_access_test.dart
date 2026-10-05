import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetassist/screens/staff/clinic_role_access.dart';
import 'package:vetassist/screens/staff/staff_add_patient_screen.dart';
import 'package:vetassist/services/symptom_engine.dart';
import 'package:vetassist/widgets/cdss_chat_box.dart';

void main() {
  test('only the staff role receives full CDSS access', () {
    expect(canUseClinicalDecisionSupport('staff'), isTrue);
    expect(canUseClinicalDecisionSupport(' STAFF '), isTrue);
    for (final role in ['vet', 'admin', 'superadmin', 'customer', '', 'user']) {
      expect(canUseClinicalDecisionSupport(role), isFalse, reason: role);
    }
  });

  test('customer response contains first aid without diagnostic output', () {
    final reply = SymptomEngine()
        .reply('vomiting and diarrhea', 'canine', firstAidOnly: true);
    expect(reply, contains('1. First Aid'));
    expect(reply, contains('2. When to See a Vet'));
    expect(reply, isNot(contains('Possible Conditions')));
    expect(reply, isNot(contains('parvovirus')));
    expect(reply, isNot(contains('Treatment Plan')));
  });

  testWidgets('customer chat introduction promises only First Aid guidance',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: CDSSChatBox(species: 'canine', firstAidOnly: true),
        ),
      ),
    ));
    expect(find.textContaining('safe First Aid guidance'), findsWidgets);
    expect(find.textContaining('likely condition'), findsNothing);
    expect(find.textContaining('treatment plan'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  test('staff-created patient preserves clinic and selected customer ownership',
      () {
    final data = buildStaffPatientFields(
      clinicId: 'clinic-a',
      ownerUid: 'customer-a',
      staffUid: 'staff-a',
      name: '  Milo  ',
      species: 'CANINE',
      sex: 'Male',
      breed: '  Labrador ',
      weightKg: 12.5,
      ownerName: ' Alex Reyes ',
      ownerEmail: ' alex@example.com ',
    );
    expect(data['clinicId'], 'clinic-a');
    expect(data['ownerUid'], 'customer-a');
    expect(data['createdBy'], 'staff-a');
    expect(data['name'], 'Milo');
    expect(data['species'], 'canine');
    expect(data['sex'], 'male');
    expect(data['breed'], 'Labrador');
    expect(data['weightKg'], 12.5);
    expect(data['ownerName'], 'Alex Reyes');
    expect(data['ownerEmail'], 'alex@example.com');
    expect(data['allergies'], isNull);
    expect(data['notes'], isNull);
  });
}
