// lib/screens/clinic/clinic_gate.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../login_screen.dart';              // StaffLoginScreen.route
import 'clinic_form_screen.dart';           // ClinicFormScreen.route

class ClinicGate extends StatefulWidget {
  static const route = '/clinic-gate';
  const ClinicGate({super.key});

  @override
  State<ClinicGate> createState() => _ClinicGateState();
}

class _ClinicGateState extends State<ClinicGate> {
  @override
  void initState() {
    super.initState();
    _route();
  }

  Future<void> _route() async {
    final auth = FirebaseAuth.instance;

    // 1) If not signed in → go to Staff login first.
    if (auth.currentUser == null) {
      await Navigator.pushNamed(context, StaffLoginScreen.route);
      // When login screen pops, continue here.
    }

    // 2) Re-check after returning from login.
    final user = auth.currentUser;
    if (user == null) {
      if (mounted) Navigator.pop(context); // user cancelled
      return;
    }

    // 3) Verify role is 'staff'.
    try {
      final u = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final role = (u.data()?['role'] as String?) ?? 'customer';
      if (role != 'staff') {
        if (mounted) {
          await showDialog(
            context: context,
            builder: (_) => const AlertDialog(
              title: Text('Staff account required'),
              content: Text('Please sign in with a Staff/Vet account to register a clinic.'),
            ),
          );
          Navigator.pop(context);
        }
        return;
      }
    } catch (_) {
      if (mounted) {
        await showDialog(
          context: context,
          builder: (_) => const AlertDialog(
            title: Text('Error'),
            content: Text('Could not verify your role. Please try again.'),
          ),
        );
        Navigator.pop(context);
      }
      return;
    }

    // 4) All good → open the Clinic form.
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, ClinicFormScreen.route);
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
