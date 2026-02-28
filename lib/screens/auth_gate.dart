import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// dashboards
import 'user/user.dart';
import 'staff/staff_home_screen.dart';
import 'admin/admin_home_screen.dart';

// pre-login portal chooser
import 'portal_picker.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        final user = snap.data;
        if (user == null) {
          // not signed-in: show portal picker (customer vs staff)
          return const PortalPicker();
        }
        if (user.isAnonymous) {
          // Anonymous session can be left behind by pre-login flows.
          // Clear it so app doesn't get stuck waiting for users/{uid} profile.
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
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (!snap.hasData || !(snap.data?.exists ?? false)) {
          // user exists in Auth but profile document not yet present
          return const Scaffold(
            body: Center(child: Text('Setting up your profile...')),
          );
        }

        final data = snap.data!.data() ?? {};
        final role = (data['role'] as String?)?.toLowerCase() ?? 'customer';
        final dynamic adminRaw = data['adminusertype'];
        final bool isAdminUser = adminRaw is bool
            ? adminRaw
            : adminRaw is String
                ? adminRaw.toLowerCase() == 'true'
                : adminRaw is num
                    ? adminRaw != 0
                    : false;

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
