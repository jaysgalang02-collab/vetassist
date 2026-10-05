import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

Map<String, dynamic> buildStaffPatientFields({
  required String clinicId,
  required String ownerUid,
  required String staffUid,
  required String name,
  required String species,
  required String sex,
  String breed = '',
  String colorMarkings = '',
  double? weightKg,
  String allergies = '',
  String notes = '',
  String ownerName = '',
  String ownerEmail = '',
}) =>
    {
      'name': name.trim(),
      'species': species.trim().toLowerCase(),
      'breed': breed.trim(),
      'sex': sex.trim().toLowerCase(),
      'colorMarkings': colorMarkings.trim(),
      'weightKg': weightKg,
      'allergies': allergies.trim().isEmpty ? null : allergies.trim(),
      'notes': notes.trim().isEmpty ? null : notes.trim(),
      'ownerUid': ownerUid,
      if (ownerName.trim().isNotEmpty) 'ownerName': ownerName.trim(),
      if (ownerEmail.trim().isNotEmpty) 'ownerEmail': ownerEmail.trim(),
      'clinicId': clinicId,
      'createdBy': staffUid,
    };

class StaffAddPatientScreen extends StatefulWidget {
  const StaffAddPatientScreen({super.key, required this.clinicId});

  final String clinicId;

  @override
  State<StaffAddPatientScreen> createState() => _StaffAddPatientScreenState();
}

class _StaffAddPatientScreenState extends State<StaffAddPatientScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _breed = TextEditingController();
  final _color = TextEditingController();
  final _weight = TextEditingController();
  final _allergies = TextEditingController();
  final _notes = TextEditingController();

  late Stream<QuerySnapshot<Map<String, dynamic>>> _customers =
      _customerStream();
  String? _ownerUid;
  String _species = 'canine';
  String _sex = 'male';
  bool _saving = false;

  Stream<QuerySnapshot<Map<String, dynamic>>> _customerStream() =>
      FirebaseFirestore.instance
          .collection('users')
          .where('clinicId', isEqualTo: widget.clinicId)
          .snapshots();

  @override
  void dispose() {
    _name.dispose();
    _breed.dispose();
    _color.dispose();
    _weight.dispose();
    _allergies.dispose();
    _notes.dispose();
    super.dispose();
  }

  String _ownerLabel(Map<String, dynamic> data) {
    final displayName = (data['displayName'] as String?)?.trim() ?? '';
    final email = (data['email'] as String?)?.trim() ?? '';
    return displayName.isNotEmpty ? displayName : email;
  }

  Future<void> _save() async {
    if (_saving || !_formKey.currentState!.validate()) return;
    final ownerUid = _ownerUid;
    final staffUid = FirebaseAuth.instance.currentUser?.uid;
    if (ownerUid == null || ownerUid.isEmpty || staffUid == null) return;

    final weightText = _weight.text.trim();
    final weight = weightText.isEmpty ? null : double.tryParse(weightText);
    if (weightText.isNotEmpty &&
        (weight == null || !weight.isFinite || weight <= 0)) {
      setState(() {});
      return;
    }

    setState(() => _saving = true);
    try {
      final owner = await FirebaseFirestore.instance
          .collection('users')
          .doc(ownerUid)
          .get()
          .timeout(const Duration(seconds: 15));
      final ownerData = owner.data() ?? {};
      final ownerRole = (ownerData['role'] as String?)?.trim().toLowerCase();
      if (!owner.exists ||
          ownerRole != 'customer' ||
          ownerData['clinicId'] != widget.clinicId) {
        throw StateError(
            'The selected customer is no longer assigned to this clinic.');
      }

      final ownerName = _ownerLabel(ownerData);
      await FirebaseFirestore.instance.collection('patients').add({
        ...buildStaffPatientFields(
          clinicId: widget.clinicId,
          ownerUid: ownerUid,
          staffUid: staffUid,
          name: _name.text,
          species: _species,
          sex: _sex,
          breed: _breed.text,
          colorMarkings: _color.text,
          weightKg: weight,
          allergies: _allergies.text,
          notes: _notes.text,
          ownerName: ownerName,
          ownerEmail: (ownerData['email'] as String?) ?? '',
        ),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }).timeout(const Duration(seconds: 20));

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text(
          'Patient could not be added. Check the customer, connection, and clinic access, then retry.',
        ),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Add patient')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [
                    colors.primaryContainer,
                    colors.surfaceContainerHighest,
                  ]),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Row(
                  children: [
                    CircleAvatar(child: Icon(Icons.pets_rounded)),
                    SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Create a clinic patient',
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.w700),
                          ),
                          SizedBox(height: 4),
                          Text(
                              'Choose the customer first, then enter the pet’s details.'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Text('Customer', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: _customers,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return _InlineLoadError(
                      onRetry: () =>
                          setState(() => _customers = _customerStream()),
                    );
                  }
                  if (!snapshot.hasData) {
                    return const LinearProgressIndicator();
                  }
                  final customers = snapshot.data!.docs.where((doc) {
                    final role =
                        (doc.data()['role'] as String?)?.trim().toLowerCase();
                    return role == 'customer';
                  }).toList()
                    ..sort((a, b) => _ownerLabel(a.data())
                        .toLowerCase()
                        .compareTo(_ownerLabel(b.data()).toLowerCase()));

                  if (customers.isEmpty) {
                    return const Card(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Text(
                          'No customer is assigned to this clinic yet. Create or assign the customer account first.',
                        ),
                      ),
                    );
                  }
                  final validOwner =
                      customers.any((doc) => doc.id == _ownerUid);
                  if (!validOwner) _ownerUid = null;
                  return DropdownButtonFormField<String>(
                    value: validOwner ? _ownerUid : null,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Pet owner',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                    items: [
                      for (final customer in customers)
                        DropdownMenuItem(
                          value: customer.id,
                          child: Text(
                            _ownerLabel(customer.data()).isEmpty
                                ? 'Customer'
                                : _ownerLabel(customer.data()),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: _saving
                        ? null
                        : (value) => setState(() => _ownerUid = value),
                    validator: (value) => value == null
                        ? 'Select the customer who owns this pet.'
                        : null,
                  );
                },
              ),
              const SizedBox(height: 24),
              Text('Patient details',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              TextFormField(
                controller: _name,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Pet name',
                  prefixIcon: Icon(Icons.badge_outlined),
                ),
                validator: (value) {
                  final text = value?.trim() ?? '';
                  if (text.isEmpty) return 'Enter the pet name.';
                  if (text.length > 100) return 'Use 100 characters or fewer.';
                  return null;
                },
              ),
              const SizedBox(height: 14),
              LayoutBuilder(builder: (context, constraints) {
                final wide = constraints.maxWidth >= 600;
                final width = wide
                    ? (constraints.maxWidth - 14) / 2
                    : constraints.maxWidth;
                return Wrap(
                  spacing: 14,
                  runSpacing: 14,
                  children: [
                    SizedBox(
                      width: width,
                      child: DropdownButtonFormField<String>(
                        value: _species,
                        decoration: const InputDecoration(
                          labelText: 'Species',
                          prefixIcon: Icon(Icons.pets_outlined),
                        ),
                        items: const [
                          DropdownMenuItem(
                              value: 'canine', child: Text('Dog (Canine)')),
                          DropdownMenuItem(
                              value: 'feline', child: Text('Cat (Feline)')),
                        ],
                        onChanged: _saving
                            ? null
                            : (value) =>
                                setState(() => _species = value ?? 'canine'),
                      ),
                    ),
                    SizedBox(
                      width: width,
                      child: DropdownButtonFormField<String>(
                        value: _sex,
                        decoration: const InputDecoration(
                          labelText: 'Sex',
                          prefixIcon: Icon(Icons.wc_outlined),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'male', child: Text('Male')),
                          DropdownMenuItem(
                              value: 'female', child: Text('Female')),
                        ],
                        onChanged: _saving
                            ? null
                            : (value) => setState(() => _sex = value ?? 'male'),
                      ),
                    ),
                    SizedBox(
                      width: width,
                      child: TextFormField(
                        controller: _breed,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(
                            labelText: 'Breed (optional)'),
                      ),
                    ),
                    SizedBox(
                      width: width,
                      child: TextFormField(
                        controller: _weight,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: const InputDecoration(
                            labelText: 'Weight in kg (optional)'),
                        validator: (value) {
                          final text = value?.trim() ?? '';
                          if (text.isEmpty) return null;
                          final number = double.tryParse(text);
                          return number == null ||
                                  !number.isFinite ||
                                  number <= 0
                              ? 'Enter a positive weight.'
                              : null;
                        },
                      ),
                    ),
                    SizedBox(
                      width: width,
                      child: TextFormField(
                        controller: _color,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: const InputDecoration(
                            labelText: 'Color / markings (optional)'),
                      ),
                    ),
                    SizedBox(
                      width: width,
                      child: TextFormField(
                        controller: _allergies,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: const InputDecoration(
                            labelText: 'Allergies (optional)'),
                      ),
                    ),
                  ],
                );
              }),
              const SizedBox(height: 14),
              TextFormField(
                controller: _notes,
                minLines: 3,
                maxLines: 6,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Notes (optional)',
                  alignLabelWithHint: true,
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            8,
            16,
            12 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.add_rounded),
            label: Text(_saving ? 'Adding patient…' : 'Add patient'),
          ),
        ),
      ),
    );
  }
}

class _InlineLoadError extends StatelessWidget {
  const _InlineLoadError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              const Icon(Icons.cloud_off_outlined),
              const SizedBox(width: 10),
              const Expanded(child: Text('Customers could not load.')),
              TextButton(onPressed: onRetry, child: const Text('Retry')),
            ],
          ),
        ),
      );
}
