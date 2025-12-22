import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CustomerHomeScreen extends StatelessWidget {
  static const route = '/home-customer';
  const CustomerHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    return Scaffold(
      appBar: AppBar(
        title: const Text('VetAssist — Customer'),
        actions: [
          IconButton(
            onPressed: () async => FirebaseAuth.instance.signOut(),
            icon: const Icon(Icons.logout),
            tooltip: 'Sign out',
          )
        ],
      ),
      body: Center(
        child: Text(
          'Welcome, ${user?.email ?? 'Customer'} 🐾',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
