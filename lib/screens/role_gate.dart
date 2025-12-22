import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'customer_home_screen.dart';
import 'staff_home_screen.dart';

/// Reads users/{uid}.role and routes accordingly.
class RoleGate extends StatelessWidget {
  const RoleGate({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      // Should not happen (AuthGate prevents), but safe fallback:
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final docRef = FirebaseFirestore.instance.collection('users').doc(uid);

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: docRef.snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        if (!snap.hasData || !snap.data!.exists) {
          // No profile yet → default to customer.
          return const CustomerHomeScreen();
        }

        final role = (snap.data!.data()?['role'] as String? ?? 'customer').toLowerCase();
        if (role == 'staff') return const StaffHomeScreen();
        return const CustomerHomeScreen();
      },
    );
  }
}
