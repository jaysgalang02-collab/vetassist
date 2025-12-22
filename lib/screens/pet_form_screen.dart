import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../utils/toast.dart';

class PetFormScreen extends StatefulWidget {
  static const route = '/pet-form';
  const PetFormScreen({super.key});

  @override
  State<PetFormScreen> createState() => _PetFormScreenState();
}

class _PetFormScreenState extends State<PetFormScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameCtrl   = TextEditingController();
  final _breedCtrl  = TextEditingController();
  final _notesCtrl  = TextEditingController();

  String _species = 'canine'; // canine | feline
  String _sex     = 'male';   // male | female
  bool   _busy    = false;

  String? _clinicId;   // loaded from users/{uid}
  String? _clinicName; // optional convenience

  @override
  void initState() {
    super.initState();
    _loadClinic();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _breedCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadClinic() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      final me = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (me.exists) {
        final data = me.data() as Map<String, dynamic>;
        setState(() {
          _clinicId   = data['clinicId'] as String?;
          _clinicName = (data['clinicName'] as String?) ?? 'Your Clinic';
        });
      }
    } catch (_) {
      // non-fatal; will be handled on submit if null
    }
  }

  Future<void> _submit() async {
    // 1) Validate form fields
    if (!_formKey.currentState!.validate()) return;

    // 2) Ensure we have a clinicId to attach
    if (_clinicId == null || _clinicId!.isEmpty) {
      toast(context, 'No clinic selected in your profile. Please choose a clinic first.');
      return;
    }

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      toast(context, 'You are signed out. Please log in again.');
      return;
    }

    setState(() => _busy = true);
    try {
      // 3) Build the document with required fields for rules:
      //    - ownerUid == auth.uid
      //    - species in ['canine', 'feline']
      //    - name is string
      //    - clinicId attached
      final doc = <String, dynamic>{
        'ownerUid'  : uid,
        'clinicId'  : _clinicId,
        'clinicName': _clinicName, // convenience; optional
        'name'      : _nameCtrl.text.trim(),
        'species'   : _species, // canine | feline
        'breed'     : _breedCtrl.text.trim(),
        'sex'       : _sex,     // male | female
        'notes'     : _notesCtrl.text.trim(),
        'createdAt' : FieldValue.serverTimestamp(),
        'updatedAt' : FieldValue.serverTimestamp(),
      };

      await FirebaseFirestore.instance.collection('patients').add(doc);

      if (mounted) {
        toast(context, 'Pet added successfully');
        Navigator.pop(context);
      }
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        toast(context, 'Permission denied by rules. Make sure you are signed in and ownerUid matches.');
      } else {
        toast(context, 'Failed to save: ${e.message}');
      }
    } catch (_) {
      toast(context, 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Add Pet')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_clinicId != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Icon(Icons.local_hospital, size: 18, color: cs.primary),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        _clinicName ?? 'Your Clinic',
                        style: TextStyle(color: cs.primary, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),

            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(labelText: 'Pet name', hintText: 'e.g., Bella'),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter pet name' : null,
            ),
            const SizedBox(height: 10),

            DropdownButtonFormField<String>(
              value: _species,
              items: const [
                DropdownMenuItem(value: 'canine', child: Text('Dog (Canine)')),
                DropdownMenuItem(value: 'feline', child: Text('Cat (Feline)')),
              ],
              onChanged: (v) => setState(() => _species = v ?? 'canine'),
              decoration: const InputDecoration(labelText: 'Species'),
            ),
            const SizedBox(height: 10),

            TextFormField(
              controller: _breedCtrl,
              decoration: const InputDecoration(labelText: 'Breed (optional)'),
            ),
            const SizedBox(height: 10),

            DropdownButtonFormField<String>(
              value: _sex,
              items: const [
                DropdownMenuItem(value: 'male', child: Text('Male')),
                DropdownMenuItem(value: 'female', child: Text('Female')),
              ],
              onChanged: (v) => setState(() => _sex = v ?? 'male'),
              decoration: const InputDecoration(labelText: 'Sex'),
            ),
            const SizedBox(height: 10),

            TextFormField(
              controller: _notesCtrl,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(labelText: 'Notes (optional)'),
            ),
            const SizedBox(height: 16),

            FilledButton.icon(
              onPressed: _busy ? null : _submit,
              icon: _busy
                  ? const SizedBox(
                      width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.check),
              label: const Text('Save pet'),
            ),
          ],
        ),
      ),
    );
  }
}
