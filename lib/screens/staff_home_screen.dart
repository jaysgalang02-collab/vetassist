// lib/screens/staff_home_screen.dart
import 'package:flutter/material.dart';
import 'clinic/clinic_form_screen.dart'; // <— add this import

class StaffHomeScreen extends StatelessWidget {
  static const route = '/home-staff';
  const StaffHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('VetAssist — Staff')),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.local_hospital),
            title: const Text('Register / Manage Clinic'),
            subtitle: const Text('Set clinic info that customers can select.'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.pushNamed(context, ClinicFormScreen.route),
          ),

          // …your other staff tiles
        ],
      ),
    );
  }
}
