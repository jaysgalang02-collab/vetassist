import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ClinicFormScreen extends StatefulWidget {
  static const route = '/clinic-form';
  const ClinicFormScreen({super.key});

  @override
  State<ClinicFormScreen> createState() => _ClinicFormScreenState();
}

class _ClinicFormScreenState extends State<ClinicFormScreen> {
  final nameCtrl = TextEditingController();
  final addrCtrl = TextEditingController();
  final phoneCtrl = TextEditingController();
  final hoursCtrl = TextEditingController(text: 'Mon–Sat 9:00–18:00');
  final servicesCtrl =
      TextEditingController(text: 'Consultation, Vaccination, Grooming');
  bool busy = false;

  String _genCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final r = Random.secure();
    return List.generate(6, (_) => chars[r.nextInt(chars.length)]).join();
  }

  @override
  void dispose() {
    nameCtrl.dispose();
    addrCtrl.dispose();
    phoneCtrl.dispose();
    hoursCtrl.dispose();
    servicesCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final user = FirebaseAuth.instance.currentUser;
    final uid = user?.uid;
    if (nameCtrl.text.trim().isEmpty) {
      _toast('Enter clinic name');
      return;
    }
    setState(() => busy = true);
    try {
      final ref = await FirebaseFirestore.instance.collection('clinics').add({
        'name': nameCtrl.text.trim(),
        'address': addrCtrl.text.trim(),
        'phone': phoneCtrl.text.trim(),
        'hours': hoursCtrl.text.trim(),
        'services': servicesCtrl.text.trim(),
        if (uid != null) 'ownerUid': uid,
        'active': true,
        'createdAt': FieldValue.serverTimestamp(),
      });

      final code = _genCode();
      await FirebaseFirestore.instance.doc('staff_codes/$code').set({
        'clinicId': ref.id,
        'active': true,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (uid != null) {
        await FirebaseFirestore.instance.collection('users').doc(uid).set({
          'clinicId': ref.id,
        }, SetOptions(merge: true));
      }

      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Clinic registered'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Clinic: ${nameCtrl.text.trim()}'),
              const SizedBox(height: 8),
              const Text('Share this code with your staff to sign up:'),
              const SizedBox(height: 8),
              SelectableText(
                code,
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );

      if (mounted) Navigator.pop(context, ref.id);
    } catch (e) {
      _toast('Failed: $e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void _toast(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Register / Manage Clinic')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _f('Clinic name', nameCtrl),
          _f('Address', addrCtrl),
          _f('Phone', phoneCtrl, kb: TextInputType.phone),
          _f('Hours', hoursCtrl),
          _f('Services', servicesCtrl, maxLines: 3),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: busy ? null : _save,
            child: busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Text('Save clinic'),
          )
        ],
      ),
    );
  }

  Widget _f(String label, TextEditingController c,
      {int maxLines = 1, TextInputType? kb}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: c,
        maxLines: maxLines,
        keyboardType: kb,
        decoration: InputDecoration(labelText: label),
      ),
    );
  }
}
