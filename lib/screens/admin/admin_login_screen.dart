import 'package:flutter/material.dart';

import '../login_screen.dart';

class AdminLoginScreen extends StatelessWidget {
  static const route = '/login-admin';
  const AdminLoginScreen({super.key});

  @override
  Widget build(BuildContext context) => const LoginScreen(portal: 'admin');
}
