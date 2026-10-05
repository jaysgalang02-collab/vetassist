import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ClinicFormScreen extends StatefulWidget {
  static const route = '/clinic-form';
  const ClinicFormScreen({super.key});

  @override
  State<ClinicFormScreen> createState() => _ClinicFormScreenState();
}

class _ClinicFormScreenState extends State<ClinicFormScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _address = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _hours = TextEditingController();
  final _services = TextEditingController();

  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _address.dispose();
    _phone.dispose();
    _email.dispose();
    _hours.dispose();
    _services.dispose();
    super.dispose();
  }

  String _genCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final r = Random.secure();
    return List.generate(6, (_) => chars[r.nextInt(chars.length)]).join();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;

    setState(() => _busy = true);
    try {
      final now = FieldValue.serverTimestamp();

      final doc = await FirebaseFirestore.instance.collection('clinics').add({
        'name': _name.text.trim(),
        'address': _address.text.trim(),
        'phone': _phone.text.trim(),
        'email': _email.text.trim(),
        'hours': _hours.text.trim(),
        'services': _services.text.trim(),
        'active': true,
        'createdAt': now,
        'updatedAt': now,
      });

      final code = _genCode();
      await FirebaseFirestore.instance.doc('staff_codes/$code').set({
        'clinicId': doc.id,
        'active': true,
        'createdAt': now,
      });

      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Clinic registered'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Clinic: ${_name.text.trim()}'),
              const SizedBox(height: 8),
              const Text('Share this code with your staff to sign up:'),
              const SizedBox(height: 8),
              SelectableText(
                code,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
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

      if (mounted) Navigator.pop(context);
    } on FirebaseException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Save failed: ${e.message ?? e.code}')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Register a Vet Clinic')),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text('Add your clinic so pet owners can select it.',
                style: TextStyle(color: cs.onSurfaceVariant)),
            const SizedBox(height: 14),
            TextFormField(
              controller: _name,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(labelText: 'Clinic name'),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _address,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(labelText: 'Address'),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _phone,
              textInputAction: TextInputAction.next,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Phone'),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _email,
              textInputAction: TextInputAction.next,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _hours,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Operating hours',
                hintText: 'Mon–Sat 9:00–18:00',
              ),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _services,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Services (comma-separated)',
                hintText: 'Vaccination, Deworming, Surgery, Grooming',
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _busy ? null : _save,
              icon: _busy
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.save),
              label: const Text('Save clinic'),
            ),
          ],
        ),
      ),
    );
  }
}
