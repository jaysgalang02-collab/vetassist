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
  final addressCtrl = TextEditingController();
  final phoneCtrl = TextEditingController();
  final emailCtrl = TextEditingController();
  final hoursCtrl = TextEditingController();

  bool active = true;
  bool busy = false;

  String? clinicId;
  String? firstStaffCode;

  bool get _isSignedIn => FirebaseAuth.instance.currentUser != null;
  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  @override
  void initState() {
    super.initState();
    _loadMine();
  }

  Future<void> _loadMine() async {
    if (!_isSignedIn) return;
    try {
      final uid = _uid!;
      final q = await FirebaseFirestore.instance
          .collection('clinics')
          .where('ownerUid', isEqualTo: uid)
          .limit(1)
          .get();

      if (q.docs.isNotEmpty) {
        final d = q.docs.first;
        clinicId = d.id;
        final data = d.data();
        nameCtrl.text = (data['name'] ?? '') as String;
        addressCtrl.text = (data['address'] ?? '') as String;
        phoneCtrl.text = (data['phone'] ?? '') as String;
        emailCtrl.text = (data['email'] ?? '') as String;
        hoursCtrl.text = (data['hours'] ?? '') as String;
        active = (data['active'] ?? true) as bool;

        setState(() {});
        await _loadExistingCode();
      }
    } catch (_) {}
  }

  Future<void> _loadExistingCode() async {
    if (clinicId == null) return;
    final snap = await FirebaseFirestore.instance
        .collection('staff_codes')
        .where('clinicId', isEqualTo: clinicId)
        .limit(1)
        .get();
    if (snap.docs.isNotEmpty) {
      firstStaffCode = snap.docs.first.id;
      setState(() {});
    }
  }

  String _makeCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rnd = Random.secure();
    return List.generate(6, (_) => chars[rnd.nextInt(chars.length)]).join();
  }

  Future<void> _ensureInitialStaffCode(String cId) async {
    if (!_isSignedIn) return;

    final existing = await FirebaseFirestore.instance
        .collection('staff_codes')
        .where('clinicId', isEqualTo: cId)
        .limit(1)
        .get();

    if (existing.docs.isNotEmpty) {
      firstStaffCode = existing.docs.first.id;
      return;
    }

    final code = _makeCode();
    final now = FieldValue.serverTimestamp();

    await FirebaseFirestore.instance.doc('staff_codes/$code').set({
      'clinicId': cId,
      'active': true,
      'uses': 0,
      'maxUses': 50,
      'createdAt': now,
      'updatedAt': now,
    });

    firstStaffCode = code;
  }

  Future<void> _patchOwnerIfMissing(String id) async {
    if (!_isSignedIn) return;
    final uid = _uid!;
    final doc = FirebaseFirestore.instance.collection('clinics').doc(id);
    final snap = await doc.get();
    if (!snap.exists) return;
    final data = snap.data() as Map<String, dynamic>;
    if (!data.containsKey('ownerUid') || data['ownerUid'] == null) {
      await doc.update({
        'ownerUid': uid,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  Future<void> _save() async {
    final name = nameCtrl.text.trim();
    if (name.isEmpty) {
      _toast('Clinic name is required');
      return;
    }

    setState(() => busy = true);
    try {
      final now = FieldValue.serverTimestamp();

      final data = <String, dynamic>{
        'name': name,
        'address': addressCtrl.text.trim(),
        'phone': phoneCtrl.text.trim(),
        'email': emailCtrl.text.trim(),
        'hours': hoursCtrl.text.trim(),
        'active': active,
        'updatedAt': now,
        if (clinicId == null) 'createdAt': now,
        if (_isSignedIn) 'ownerUid': _uid,
      };

      final col = FirebaseFirestore.instance.collection('clinics');

      if (clinicId == null) {
        final doc = await col.add(data);
        clinicId = doc.id;

        if (_isSignedIn) {
          await _patchOwnerIfMissing(clinicId!);
        }
      } else {
        if (_isSignedIn) {
          await _patchOwnerIfMissing(clinicId!);
        }
        await col.doc(clinicId).update(data);
      }

      await _ensureInitialStaffCode(clinicId!);

      if (!mounted) return;
      _toast('Clinic saved');
      if (_isSignedIn) {
        if (firstStaffCode != null) {
          _toast('Invite code: $firstStaffCode');
        } else {
          _toast(
              'You can generate staff invite codes after claiming ownership.');
        }
      } else {
        _toast(
            'Tip: Sign in later to claim this clinic and generate staff invite codes.');
      }
      Navigator.pop(context);
    } on FirebaseException catch (e) {
      _toast('Save failed: ${e.message ?? e.code}');
    } catch (_) {
      _toast('Save failed. Please try again.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  void dispose() {
    nameCtrl.dispose();
    addressCtrl.dispose();
    phoneCtrl.dispose();
    emailCtrl.dispose();
    hoursCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    InputDecoration deco(String label, {String? hint}) {
      return InputDecoration(
        labelText: label,
        hintText: hint,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabled: !busy,
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Register a Vet Clinic')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Add your clinic so pet owners can select it.',
            style: TextStyle(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: nameCtrl,
            decoration: deco('Clinic name', hint: 'e.g. Pawfect Vets'),
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: addressCtrl,
            decoration: deco('Address', hint: 'Street, Barangay, City'),
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: phoneCtrl,
            keyboardType: TextInputType.phone,
            decoration: deco('Phone', hint: 'e.g. 0917xxxxxxx'),
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: emailCtrl,
            keyboardType: TextInputType.emailAddress,
            decoration: deco('Email', hint: 'e.g. clinic@example.com'),
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: hoursCtrl,
            maxLines: 2,
            decoration: deco('Operating hours', hint: 'e.g. Mon–Sat 8AM–6PM'),
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            value: active,
            onChanged: busy ? null : (v) => setState(() => active = v),
            title: const Text('Active (visible to customers)'),
            subtitle: const Text('Turn off to temporarily hide your clinic.'),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 48,
            child: FilledButton.icon(
              onPressed: busy ? null : _save,
              icon: const Icon(Icons.save),
              label: Text(busy ? 'Saving…' : 'Save clinic'),
            ),
          ),
          const SizedBox(height: 10),
          if (clinicId != null)
            Text(
              'Clinic ID: $clinicId',
              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
            ),
          if (_isSignedIn && firstStaffCode != null)
            Text(
              'Staff/Invite code: $firstStaffCode',
              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
            ),
          if (!_isSignedIn)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'You are not signed in. You can still add a clinic. '
                'Sign in later to claim ownership and generate staff invite codes.',
                style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}
