import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class PetFormScreen extends StatefulWidget {
  static const route = '/pet-form';

  final String? editPatientId;

  const PetFormScreen({super.key, this.editPatientId});

  @override
  State<PetFormScreen> createState() => _PetFormScreenState();
}

class _PetFormScreenState extends State<PetFormScreen> {
  final _formKey = GlobalKey<FormState>();

  final _name = TextEditingController();
  final _species = TextEditingController();
  final _breed = TextEditingController();
  final _sex = TextEditingController();
  final _color = TextEditingController();
  final _weight = TextEditingController();
  final _allergies = TextEditingController();
  final _notes = TextEditingController();

  String? _patientId;
  bool _loading = true;
  bool _saving = false;

  final _speciesOptions = const ['canine', 'feline'];
  final _sexOptions = const ['male', 'female'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  Future<void> _bootstrap() async {
    String? patientId = widget.editPatientId;

    if (patientId == null) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is Map && args['patientId'] is String) {
        patientId = args['patientId'] as String;
      } else if (args is PetFormArgs) {
        patientId = args.patientId;
      }
    }

    _patientId = patientId;

    if (_patientId == null) {
      setState(() => _loading = false);
      return;
    }

    try {
      final snap = await FirebaseFirestore.instance
          .collection('patients')
          .doc(_patientId)
          .get();

      if (!snap.exists) {
        if (!mounted) return;
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pet not found.')),
        );
        return;
      }

      final d = snap.data() as Map<String, dynamic>;
      _name.text = (d['name'] ?? '').toString();
      _species.text = (d['species'] ?? '').toString();
      _breed.text = (d['breed'] ?? '').toString();
      _sex.text = (d['sex'] ?? '').toString();
      _color.text = (d['colorMarkings'] ?? '').toString();
      final w = d['weightKg'];
      if (w != null) _weight.text = '$w';
      _allergies.text = (d['allergies'] ?? '').toString();
      _notes.text = (d['notes'] ?? '').toString();

      if (mounted) setState(() => _loading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load pet: $e')),
      );
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _species.dispose();
    _breed.dispose();
    _sex.dispose();
    _color.dispose();
    _weight.dispose();
    _allergies.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final authUser = FirebaseAuth.instance.currentUser!;
    final uid = authUser.uid;
    final ownerName = (authUser.displayName ?? '').trim();
    final ownerEmail = (authUser.email ?? '').trim();
    final db = FirebaseFirestore.instance;

    setState(() => _saving = true);

    try {
      final double? weightKg = _weight.text.trim().isEmpty
          ? null
          : double.tryParse(_weight.text.trim());

      if (_patientId == null) {
        String? clinicId;
        try {
          final me = await db.collection('users').doc(uid).get();
          clinicId = (me.data() ?? const {})['clinicId'] as String?;
        } catch (_) {}

        final doc = db.collection('patients').doc();

        await doc.set({
          'name': _name.text.trim(),
          'species': _species.text.trim(),
          'breed': _breed.text.trim(),
          'sex': _sex.text.trim(),
          'colorMarkings': _color.text.trim(),
          'weightKg': weightKg,
          'allergies':
              _allergies.text.trim().isEmpty ? null : _allergies.text.trim(),
          'notes': _notes.text.trim().isEmpty ? null : _notes.text.trim(),
          'ownerUid': uid,
          if (ownerName.isNotEmpty) 'ownerName': ownerName,
          if (ownerEmail.isNotEmpty) 'ownerEmail': ownerEmail,
          'clinicId': clinicId,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        if (!mounted) return;
        Navigator.pop(context);
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Pet added')));
      } else {
        final ref = db.collection('patients').doc(_patientId);
        await ref.update({
          'name': _name.text.trim(),
          'species': _species.text.trim(),
          'breed': _breed.text.trim(),
          'sex': _sex.text.trim(),
          'colorMarkings': _color.text.trim(),
          'weightKg': weightKg,
          'allergies':
              _allergies.text.trim().isEmpty ? null : _allergies.text.trim(),
          'notes': _notes.text.trim().isEmpty ? null : _notes.text.trim(),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        if (!mounted) return;
        Navigator.pop(context);
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Pet updated')));
      }
    } on FirebaseException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message ?? 'Failed to save')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isEdit = _patientId != null;

    final String? _speciesValue =
        _speciesOptions.contains(_species.text.trim().toLowerCase())
            ? _species.text.trim().toLowerCase()
            : null;

    final String? _sexValue =
        _sexOptions.contains(_sex.text.trim().toLowerCase())
            ? _sex.text.trim().toLowerCase()
            : null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? 'Update Pet' : 'Add Pet'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  children: [
                    _Section(
                      title: 'Basic info',
                      child: Column(
                        children: [
                          TextFormField(
                            controller: _name,
                            textCapitalization: TextCapitalization.words,
                            decoration: const InputDecoration(
                              labelText: 'Name *',
                              prefixIcon: Icon(Icons.pets),
                            ),
                            validator: (v) => (v == null || v.trim().isEmpty)
                                ? 'Name is required'
                                : null,
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            value: _speciesValue,
                            decoration: const InputDecoration(
                              labelText: 'Species',
                              prefixIcon: Icon(Icons.category),
                            ),
                            items: _speciesOptions
                                .map((o) => DropdownMenuItem(
                                      value: o,
                                      child: Text(o),
                                    ))
                                .toList(),
                            onChanged: (v) =>
                                setState(() => _species.text = v ?? ''),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _breed,
                            textCapitalization: TextCapitalization.words,
                            decoration: const InputDecoration(
                              labelText: 'Breed',
                              prefixIcon: Icon(Icons.badge_outlined),
                            ),
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            value: _sexValue,
                            decoration: const InputDecoration(
                              labelText: 'Sex',
                              prefixIcon: Icon(Icons.transgender),
                            ),
                            items: _sexOptions
                                .map((o) => DropdownMenuItem(
                                      value: o,
                                      child: Text(o),
                                    ))
                                .toList(),
                            onChanged: (v) =>
                                setState(() => _sex.text = v ?? ''),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    _Section(
                      title: 'Appearance & health',
                      child: Column(
                        children: [
                          TextFormField(
                            controller: _color,
                            textCapitalization: TextCapitalization.sentences,
                            decoration: const InputDecoration(
                              labelText: 'Color/Markings',
                              prefixIcon: Icon(Icons.palette_outlined),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _weight,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            decoration: const InputDecoration(
                              labelText: 'Weight (kg)',
                              prefixIcon: Icon(Icons.monitor_weight_outlined),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _allergies,
                            minLines: 1,
                            maxLines: 3,
                            textCapitalization: TextCapitalization.sentences,
                            decoration: const InputDecoration(
                              labelText: 'Allergies',
                              prefixIcon: Icon(Icons.warning_amber_outlined),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _notes,
                            minLines: 2,
                            maxLines: 5,
                            textCapitalization: TextCapitalization.sentences,
                            decoration: const InputDecoration(
                              labelText: 'Notes',
                              prefixIcon: Icon(Icons.notes_outlined),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _saving ? null : _submit,
                        icon: _saving
                            ? const SizedBox(
                                height: 18,
                                width: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Icon(isEdit
                                ? Icons.save_as_outlined
                                : Icons.save_outlined),
                        label: Text(isEdit ? 'Update' : 'Save'),
                      ),
                    ),
                    if (isEdit) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Editing existing pet • Changes will update your dashboard and records',
                        textAlign: TextAlign.center,
                        style:
                            TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
                      ),
                    ],
                  ],
                ),
              ),
            ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final Widget child;
  const _Section({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withOpacity(.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Text(title,
                style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

class PetFormArgs {
  final String? patientId;
  const PetFormArgs({this.patientId});
}
