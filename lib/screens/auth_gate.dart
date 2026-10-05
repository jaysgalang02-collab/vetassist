import '../utils/account_access.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'user/user.dart';
import 'staff/staff_home_screen.dart';
import 'admin/admin_home_screen.dart';

import 'portal_picker.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }
        final user = snap.data;
        if (user == null) {
          return const PortalPicker();
        }
        if (user.isAnonymous) {
          return FutureBuilder<void>(
            future: FirebaseAuth.instance.signOut(),
            builder: (context, _) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            },
          );
        }
        return _RoleGate(uid: user.uid);
      },
    );
  }
}

class _RoleGate extends StatelessWidget {
  final String uid;
  const _RoleGate({required this.uid});

  @override
  Widget build(BuildContext context) {
    final ref = FirebaseFirestore.instance.collection('users').doc(uid);
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: ref.snapshots(),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }
        if (!snap.hasData || !(snap.data?.exists ?? false)) {
          return const Scaffold(
            body: Center(child: Text('Setting up your profile...')),
          );
        }

        final data = snap.data!.data() ?? {};
        final role = accountRole(data);
        final bool isAdminUser = hasAdminAccess(data);
        if (isAdminUser) {
          return const AdminHomeScreen();
        }

        if (role == 'staff' || role == 'vet' || role == 'admin') {
          return const StaffHomeScreen();
        }
        return const UserDashboard();
      },
    );
  }
}
