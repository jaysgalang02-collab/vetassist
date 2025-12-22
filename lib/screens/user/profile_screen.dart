import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ProfileScreen extends StatelessWidget {
  static const route = '/profile';
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final doc = FirebaseFirestore.instance.collection('users').doc(uid);

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: StreamBuilder<DocumentSnapshot>(
        stream: doc.snapshots(),
        builder: (ctx, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final d = (snap.data!.data() ?? {}) as Map<String, dynamic>;
          final email = (d['email'] ?? FirebaseAuth.instance.currentUser!.email) as String?;
          final name = (d['displayName'] ?? FirebaseAuth.instance.currentUser!.displayName) as String?;
          final role = (d['role'] ?? 'customer') as String;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              ListTile(
                leading: const CircleAvatar(child: Icon(Icons.person)),
                title: Text(name ?? 'User'),
                subtitle: Text(email ?? ''),
                trailing: Chip(label: Text(role)),
              ),
              const SizedBox(height: 10),
              FilledButton.icon(
                onPressed: () async {
                  await FirebaseAuth.instance.signOut();
                  if (context.mounted) {
                    Navigator.pushNamedAndRemoveUntil(context, '/auth', (_) => false);
                  }
                },
                icon: const Icon(Icons.logout),
                label: const Text('Sign out'),
              ),
            ],
          );
        },
      ),
    );
  }
}
