import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/toast.dart';

class CreateAccountScreen extends StatefulWidget {
  static const route = '/create';
  const CreateAccountScreen({super.key});

  @override
  State<CreateAccountScreen> createState() => _CreateAccountScreenState();
}

/* Simple clinic model (id + name) */
class _Clinic {
  final String id;
  final String name;
  const _Clinic(this.id, this.name);
}

class _CreateAccountScreenState extends State<CreateAccountScreen> {
  // 'customer' | 'staff'
  String portal = 'customer';

  final nameCtrl       = TextEditingController();
  final emailCtrl      = TextEditingController();
  final pwCtrl         = TextEditingController();
  final pw2Ctrl        = TextEditingController();
  final clinicCodeCtrl = TextEditingController(); // required for staff

  bool showPw = false;
  bool busy   = false;

  // Clinics dropdown (customers only)
  final List<_Clinic> _clinics = <_Clinic>[];
  String? _clinicId; // currently selected clinicId (customers)
  Map<String, String> get _idToName => {for (final c in _clinics) c.id: c.name};
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _clinicSub;
  bool _clinicsBound = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final arg = ModalRoute.of(context)?.settings.arguments;
    if (arg is String && (arg == 'customer' || arg == 'staff')) {
      portal = arg;
    }
    _bindClinics();
  }

  String _norm(String? s) => (s ?? '').trim().toLowerCase();

  void _bindClinics() {
    if (_clinicsBound) return;
    _clinicsBound = true;
    bool isActive(dynamic raw) {
      if (raw == null) return true;
      if (raw is bool) return raw;
      if (raw is String) return raw.toLowerCase() == 'true';
      if (raw is num) return raw != 0;
      return true;
    }

    _clinicSub = FirebaseFirestore.instance
        .collection('clinics')
        .orderBy('name')
        .snapshots()
        .listen((snap) {
      final Map<String, QueryDocumentSnapshot<Map<String, dynamic>>> byName = {};
      for (final d in snap.docs) {
        final data = d.data();
        if (!isActive(data['active'])) continue;
        final name = (data['name'] as String?) ?? 'Clinic';
        final key = _norm(name);

        int tsScore(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
          final dd = doc.data();
          final up = dd['updatedAt'];
          final cr = dd['createdAt'];
          final upMicros = (up is Timestamp) ? up.microsecondsSinceEpoch : 0;
          final crMicros = (cr is Timestamp) ? cr.microsecondsSinceEpoch : 0;
          return upMicros > 0 ? upMicros : crMicros;
        }

        if (!byName.containsKey(key)) {
          byName[key] = d;
        } else {
          if (tsScore(d) >= tsScore(byName[key]!)) {
            byName[key] = d;
          }
        }
      }

      final fresh = byName.values
          .map((d) => _Clinic(d.id, (d.data()['name'] ?? 'Clinic') as String))
          .toList()
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

      if (!mounted) return;
      setState(() {
        _clinics
          ..clear()
          ..addAll(fresh);

        if (_clinicId != null && !_idToName.containsKey(_clinicId)) {
          _clinicId = null;
        }
      });
    });
  }

  void _refreshClinics() {
    _clinicSub?.cancel();
    _clinicsBound = false;
    _bindClinics();
  }

  @override
  void dispose() {
    nameCtrl.dispose();
    emailCtrl.dispose();
    pwCtrl.dispose();
    pw2Ctrl.dispose();
    clinicCodeCtrl.dispose();
    _clinicSub?.cancel();
    super.dispose();
  }

  /// Resolve clinicId strictly from a staff/invite **code**.
  Future<String?> _clinicIdFromStaffCode(String code) async {
    final codeDoc =
        await FirebaseFirestore.instance.doc('staff_codes/$code').get();
    if (!codeDoc.exists) return null;
    final data = codeDoc.data();
    if (data?['active'] != true) return null;
    final clinicId = data?['clinicId'] as String?;
    return (clinicId != null && clinicId.isNotEmpty) ? clinicId : null;
  }

  Future<void> _create() async {
    final name    = nameCtrl.text.trim();
    final email   = emailCtrl.text.trim();
    final pw1     = pwCtrl.text;
    final pw2     = pw2Ctrl.text;
    final isStaff = portal == 'staff';
    final code    = clinicCodeCtrl.text.trim();

    // ---- Guards ------------------------------------------------------------
    if (email.isEmpty)  { toast(context, 'Please enter your email'); return; }
    if (pw1.length < 6) { toast(context, 'Password must be at least 6 characters'); return; }
    if (pw1 != pw2)     { toast(context, 'Passwords do not match'); return; }

    // Customer MUST pick a clinic
    if (!isStaff && _clinicId == null) {
      toast(context, 'Please select your vet clinic');
      return;
    }

    // Staff MUST enter a valid code (no clinic dropdown for staff)
    if (isStaff && code.isEmpty) {
      toast(context, 'Staff/Invite code is required');
      return;
    }

    setState(() => busy = true);
    UserCredential? cred;
    try {
      // Prevent duplicate accounts for the same email
      final methods =
          await FirebaseAuth.instance.fetchSignInMethodsForEmail(email);
      if (methods.isNotEmpty) {
        if (methods.contains('google.com')) {
          toast(context,
              'This email is already linked to Google. Please sign in with Google.');
        } else {
          toast(context,
              'Email already in use. Try logging in or use "Forgot password".');
        }
        return;
      }

      // Resolve clinic
      String? finalClinicId = !isStaff ? _clinicId : null;

      // Create Firebase Auth user (needed so Firestore rules allow staff code validation)
      cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: pw1,
      );
      if (name.isNotEmpty) {
        await cred.user!.updateDisplayName(name);
      }

      if (isStaff) {
        final clinicFromCode = await _clinicIdFromStaffCode(code);
        if (clinicFromCode == null) {
          toast(context, 'Invalid or inactive staff/invite code');
          try {
            await cred.user?.delete();
          } catch (_) {}
          await FirebaseAuth.instance.signOut();
          return;
        }
        finalClinicId = clinicFromCode;
      }

      // Save Firestore profile
      final uid = cred.user!.uid;
      final now = FieldValue.serverTimestamp();
      final users = FirebaseFirestore.instance.collection('users');

      await users.doc(uid).set({
        'email': email,
        'displayName': name.isEmpty ? null : name,
        'photoURL': null,
        'role': isStaff ? 'staff' : 'customer',
        'provider': 'password',
        'createdAt': now,
        'updatedAt': now,
        'clinicId': finalClinicId, // never null here
        if (isStaff) 'clinicCodeUsed': code,
      });

      toast(context, 'Account created!');
      if (mounted) Navigator.pop(context);
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'email-already-in-use':
          toast(context,
              'Email already in use. Try logging in or use "Forgot password".');
          break;
        case 'invalid-email':
          toast(context, 'Invalid email. Please check and try again.');
          break;
        case 'weak-password':
          toast(context, 'Password is too weak. Try a stronger one.');
          break;
        default:
          toast(context, e.message ?? 'Sign-up failed. Please try again.');
      }
    } on FirebaseException catch (e) {
      toast(context, 'Failed to save your profile: ${e.message}');
      if (cred?.user != null) {
        try { await cred!.user!.delete(); } catch (_) {}
      }
    } catch (_) {
      toast(context, 'Something went wrong. Please try again.');
      if (cred?.user != null) {
        try { await cred!.user!.delete(); } catch (_) {}
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isStaff = portal == 'staff';

    return Scaffold(
      appBar: AppBar(
        title: Text(isStaff
            ? 'Create Staff/Admin Account'
            : 'Create Customer Account'),
        actions: [
          IconButton(
            tooltip: 'Reload clinics',
            onPressed: busy ? null : _refreshClinics,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: ListView(
        key: ValueKey('create-$portal'), // keep list state per tab
        padding: const EdgeInsets.all(20),
        children: [
          // Portal switcher
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'customer', label: Text('Customer')),
              ButtonSegment(value: 'staff',    label: Text('Staff/Admin')),
            ],
            selected: {portal},
            onSelectionChanged: (selection) {
              setState(() => portal = selection.first);
            },
          ),
          const SizedBox(height: 14),

          _LabeledField(
            label: 'Full name (optional)',
            child: TextField(
              controller: nameCtrl,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(hintText: 'e.g., Juan Dela Cruz'),
            ),
          ),
          const SizedBox(height: 10),

          _LabeledField(
            label: 'Email',
            child: TextField(
              controller: emailCtrl,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(hintText: 'you@example.com'),
            ),
          ),
          const SizedBox(height: 10),

          // CUSTOMER-ONLY: clinic dropdown
          if (!isStaff) ...[
            _LabeledField(
              label: 'Your Vet Clinic (required)',
              child: DropdownButtonFormField<String>(
                key: const ValueKey('clinic-dd-customer'),
                value: _clinicId,
                items: _clinics
                    .map((c) => DropdownMenuItem<String>(
                          value: c.id,
                          child: Text(c.name),
                        ))
                    .toList(),
                onChanged: (v) => setState(() => _clinicId = v),
                decoration: InputDecoration(
                  hintText: _clinics.isEmpty
                      ? 'No clinics available yet'
                      : 'Select clinic',
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],

          // STAFF-ONLY: invite code (required)
          if (isStaff) ...[
            _LabeledField(
              label: 'Staff / Invite Code (required)',
              child: TextField(
                key: const ValueKey('staff-code'),
                controller: clinicCodeCtrl,
                textInputAction: TextInputAction.next,
                decoration:
                    const InputDecoration(hintText: 'Enter staff/invite code'),
              ),
            ),
            const SizedBox(height: 10),
          ],

          _LabeledField(
            label: 'Password',
            child: TextField(
              controller: pwCtrl,
              obscureText: !showPw,
              decoration: InputDecoration(
                hintText: 'At least 6 characters',
                suffixIcon: IconButton(
                  onPressed: () => setState(() => showPw = !showPw),
                  icon: Icon(showPw ? Icons.visibility_off : Icons.visibility),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),

          _LabeledField(
            label: 'Confirm password',
            child: TextField(
              controller: pw2Ctrl,
              obscureText: !showPw,
              decoration: InputDecoration(
                hintText: 'Repeat password',
                suffixIcon: IconButton(
                  onPressed: () => setState(() => showPw = !showPw),
                  icon: Icon(showPw ? Icons.visibility_off : Icons.visibility),
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),

          FilledButton(
            onPressed: busy ? null : _create,
            child: busy
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                : const Text('Create account'),
          ),
          const SizedBox(height: 10),

          Text(
            isStaff
                ? 'Staff/Admin: Enter your staff/invite code. The code determines your clinic.'
                : 'Note: Choosing the correct clinic lets your vet see your records.',
            style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _LabeledField extends StatelessWidget {
  final String label;
  final Widget child;
  const _LabeledField({required this.label, required this.child});
  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 12)),
          const SizedBox(height: 6),
          child,
        ],
      );
}
