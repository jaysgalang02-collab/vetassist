import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../utils/toast.dart';

class ForgotPasswordScreen extends StatefulWidget {
  static const route = '/forgot';
  const ForgotPasswordScreen({super.key});
  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final emailCtrl = TextEditingController();
  bool busy = false;

  @override
  void dispose() {
    emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    setState(() => busy = true);
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: emailCtrl.text.trim());
      if (mounted) {
        toast(context, 'Reset email sent');
        Navigator.pop(context);
      }
    } on FirebaseAuthException catch (e) {
      toast(context, e.message ?? 'Failed to send email');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Forgot password')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text('Enter the email associated with your account:'),
          const SizedBox(height: 10),
          TextField(
            controller: emailCtrl,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(hintText: 'you@example.com'),
          ),
          const SizedBox(height: 14),
          FilledButton(
            onPressed: busy ? null : _send,
            child: busy
                ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text('Send reset link'),
          ),
        ],
      ),
    );
  }
}
