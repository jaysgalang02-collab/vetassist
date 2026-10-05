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
  final _formKey = GlobalKey<FormState>();

  final _nameCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _hoursCtrl = TextEditingController();
  final _servicesCtrl = TextEditingController();

  bool _active = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _loadIfExists();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _addressCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _hoursCtrl.dispose();
    _servicesCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadIfExists() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final doc =
        await FirebaseFirestore.instance.collection('clinics').doc(uid).get();
    if (!doc.exists) return;
    final d = doc.data()!;
    setState(() {
      _nameCtrl.text = (d['name'] ?? '') as String;
      _addressCtrl.text = (d['address'] ?? '') as String;
      _phoneCtrl.text = (d['phone'] ?? '') as String;
      _emailCtrl.text = (d['email'] ?? '') as String;
      _hoursCtrl.text = (d['hours'] ?? '') as String;
      _servicesCtrl.text = (d['services'] ?? '') as String;
      _active = (d['active'] ?? true) as bool;
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    setState(() => _busy = true);
    try {
      final now = FieldValue.serverTimestamp();
      await FirebaseFirestore.instance.collection('clinics').doc(uid).set({
        'ownerUid': uid,
        'name': _nameCtrl.text.trim(),
        'address': _addressCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
        'email': _emailCtrl.text.trim(),
        'hours': _hoursCtrl.text.trim(),
        'services': _servicesCtrl.text.trim(),
        'active': _active,
        'updatedAt': now,
        'createdAt': now,
      }, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Clinic saved')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Register / Manage Clinic')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(labelText: 'Clinic name'),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _addressCtrl,
              decoration: const InputDecoration(labelText: 'Address'),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _phoneCtrl,
              decoration: const InputDecoration(labelText: 'Phone'),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _emailCtrl,
              decoration: const InputDecoration(labelText: 'Email'),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _hoursCtrl,
              decoration: const InputDecoration(
                  labelText: 'Hours (e.g., Mon–Sat, 9am–6pm)'),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _servicesCtrl,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                  labelText: 'Services (comma-separated)'),
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              value: _active,
              onChanged: (v) => setState(() => _active = v),
              title: const Text('Clinic is active'),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _busy ? null : _save,
              icon: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.save),
              label: const Text('Save clinic'),
            ),
          ],
        ),
      ),
    );
  }
}
