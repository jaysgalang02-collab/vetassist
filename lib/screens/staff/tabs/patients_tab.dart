import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../../../utils/toast.dart';
import '../medical_record_editor.dart';
import '../staff_add_patient_screen.dart';

class PatientsTab extends StatefulWidget {
  final String clinicId;
  const PatientsTab({super.key, required this.clinicId});

  @override
  State<PatientsTab> createState() => _PatientsTabState();
}

class _PatientsTabState extends State<PatientsTab> {
  final _qCtrl = TextEditingController();
  String _species = 'all';
  late Stream<QuerySnapshot<Map<String, dynamic>>> _patients = _patientStream();

  Stream<QuerySnapshot<Map<String, dynamic>>> _patientStream() =>
      FirebaseFirestore.instance
          .collection('patients')
          .where('clinicId', isEqualTo: widget.clinicId)
          .snapshots();

  @override
  void didUpdateWidget(covariant PatientsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.clinicId != widget.clinicId) {
      _patients = _patientStream();
      _ownerNameCache.clear();
    }
  }

  final Map<String, String?> _ownerNameCache = {};

  @override
  void dispose() {
    _qCtrl.dispose();
    super.dispose();
  }

  Future<String?> _fetchOwnerLabel(String ownerUid) async {
    if (ownerUid.isEmpty) return null;
    if (_ownerNameCache.containsKey(ownerUid)) return _ownerNameCache[ownerUid];

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(ownerUid)
          .get();
      final data = doc.data();
      String? label;
      if (data != null) {
        final dn = (data['displayName'] as String?)?.trim();
        final em = (data['email'] as String?)?.trim();
        label = (dn != null && dn.isNotEmpty)
            ? dn
            : (em != null && em.isNotEmpty ? em : null);
      }
      _ownerNameCache[ownerUid] = label;
      return label;
    } catch (_) {
      _ownerNameCache[ownerUid] = null;
      return null;
    }
  }

  String _shortUid(String uid) {
    if (uid.length <= 8) return uid;
    return '${uid.substring(0, 4)}…${uid.substring(uid.length - 4)}';
  }

  Future<void> _addPatient() async {
    final added = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => StaffAddPatientScreen(clinicId: widget.clinicId),
      ),
    );
    if (added == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Patient added to the clinic.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final q = _qCtrl.text.trim().toLowerCase();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 2),
          child: LayoutBuilder(builder: (context, constraints) {
            final compact = constraints.maxWidth < 430 ||
                MediaQuery.textScalerOf(context).scale(14) > 18;
            final title = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Clinic patients',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 2),
                Text(
                  'Manage pets assigned to this clinic.',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            );
            final button = FilledButton.icon(
              onPressed: _addPatient,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add patient'),
            );
            if (compact) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [title, const SizedBox(height: 12), button],
              );
            }
            return Row(
              children: [
                Expanded(child: title),
                const SizedBox(width: 12),
                button,
              ],
            );
          }),
        ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _qCtrl,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search),
                    hintText: 'Search by name',
                    suffixIcon: _qCtrl.text.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () => setState(() => _qCtrl.clear()),
                          ),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 8),
              DropdownButton<String>(
                value: _species,
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('All')),
                  DropdownMenuItem(value: 'canine', child: Text('Canine')),
                  DropdownMenuItem(value: 'feline', child: Text('Feline')),
                ],
                onChanged: (v) => setState(() => _species = v ?? 'all'),
              ),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _patients,
            builder: (ctx, snap) {
              if (snap.hasError) {
                return Center(
                    child: Padding(
                        padding: const EdgeInsets.all(24),
                        child:
                            Column(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.cloud_off_outlined, size: 36),
                          const SizedBox(height: 12),
                          const Text(
                              'Patients could not load. Please check your connection and try again.',
                              textAlign: TextAlign.center),
                          TextButton.icon(
                              onPressed: () =>
                                  setState(() => _patients = _patientStream()),
                              icon: const Icon(Icons.refresh),
                              label: const Text('Retry')),
                        ])));
              }
              if (!snap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final docs = snap.data!.docs.where((doc) {
                final data = doc.data();
                return (_species == 'all' || data['species'] == _species) &&
                    (data['name'] ?? '').toString().toLowerCase().contains(q);
              }).toList()
                ..sort((a, b) => (a.data()['name'] ?? '')
                    .toString()
                    .toLowerCase()
                    .compareTo(
                        (b.data()['name'] ?? '').toString().toLowerCase()));
              if (docs.isEmpty) {
                return const Center(child: Text('No patients found.'));
              }
              return ListView.separated(
                itemCount: docs.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (_, i) {
                  final d = docs[i];
                  final data = d.data();
                  final petName = (data['name'] ?? '—').toString();
                  final species = (data['species'] ?? '—').toString();
                  final ownerUid = (data['ownerUid'] ?? '').toString();
                  final patientId = d.id;

                  return ListTile(
                    leading: Icon(
                      species == 'canine' ? Icons.pets : Icons.pets_outlined,
                    ),
                    title: Text(
                      petName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      softWrap: false,
                    ),
                    subtitle: FutureBuilder<String?>(
                      future: _fetchOwnerLabel(ownerUid),
                      builder: (context, snap) {
                        final ownerLabel = snap.data ??
                            (ownerUid.isEmpty ? '—' : _shortUid(ownerUid));
                        final text = 'Species: $species • Owner: $ownerLabel';
                        return Text(
                          text,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          softWrap: false,
                        );
                      },
                    ),
                    trailing: PopupMenuButton<String>(
                      onSelected: (k) => _handleAction(k, patientId, data),
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'vax', child: Text('Add vaccine')),
                        PopupMenuItem(
                            value: 'visit', child: Text('Add visit/treatment')),
                        PopupMenuItem(
                            value: 'rem', child: Text('Add reminder')),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _handleAction(
      String key, String patientId, Map<String, dynamic> patient) async {
    switch (key) {
      case 'vax':
        _showAddVaccineDialog(patientId, patient);
        break;
      case 'visit':
        _showAddVisitDialog(patientId, patient);
        break;
      case 'rem':
        _showAddReminderDialog(patientId, patient);
        break;
    }
  }

  Future<void> _showAddVaccineDialog(
      String patientId, Map<String, dynamic> p) async {
    final nameCtrl = TextEditingController();
    DateTime? date = DateTime.now();

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Record vaccine'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              decoration: const InputDecoration(labelText: 'Vaccine name'),
              controller: nameCtrl,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Date given: ${date!.toLocal().toString().split(".").first}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.calendar_month),
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      firstDate: DateTime(2010),
                      lastDate: DateTime(2100),
                      initialDate: date!,
                    );
                    if (picked != null) {
                      setState(() => date = DateTime(picked.year, picked.month,
                          picked.day, date!.hour, date!.minute));
                    }
                  },
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              final ownerUid = (p['ownerUid'] as String?) ?? '';
              final clinicId = (p['clinicId'] as String?) ?? '';
              if (ownerUid.isEmpty || clinicId.isEmpty) {
                toast(context, 'Missing owner/clinic.');
                return;
              }

              await FirebaseFirestore.instance.collection('vaccines').add({
                'ownerUid': ownerUid,
                'patientId': patientId,
                'name': nameCtrl.text.trim(),
                'dateGiven': Timestamp.fromDate(date!),
                'clinicId': clinicId,
                'createdAt': FieldValue.serverTimestamp(),
              });
              if (!mounted) return;
              Navigator.pop(context);
              toast(context, 'Vaccine recorded.');
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _showAddVisitDialog(
      String patientId, Map<String, dynamic> p) async {
    await openMedicalRecordEditor(context,
        clinicId: widget.clinicId, patientId: patientId);
  }

  Future<void> _showAddReminderDialog(
      String patientId, Map<String, dynamic> p) async {
    final titleCtrl = TextEditingController();
    String type = 'vaccine';
    DateTime when = DateTime.now().add(const Duration(days: 30));

    String normalizeType(String raw) {
      final v = raw.trim().toLowerCase();
      if (v.startsWith('follow')) return 'followup';
      if (v.startsWith('vacc')) return 'vaccine';
      if (v.startsWith('visit')) return 'visit';
      if (v == 'custom') return 'custom';
      return 'custom';
    }

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Create reminder'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              value: type,
              items: const [
                DropdownMenuItem(value: 'vaccine', child: Text('Vaccine')),
                DropdownMenuItem(value: 'followup', child: Text('Follow-up')),
                DropdownMenuItem(value: 'visit', child: Text('Visit')),
                DropdownMenuItem(value: 'custom', child: Text('Custom')),
              ],
              onChanged: (v) => type = v ?? 'vaccine',
              decoration: const InputDecoration(labelText: 'Type'),
            ),
            const SizedBox(height: 8),
            TextField(
              decoration: const InputDecoration(labelText: 'Title'),
              controller: titleCtrl,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'When: ${when.toLocal().toString().split(".").first}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.calendar_month),
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: when,
                      firstDate: DateTime(2010),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null) {
                      setState(() => when = DateTime(picked.year, picked.month,
                          picked.day, when.hour, when.minute));
                    }
                  },
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';
              final clinicId = (p['clinicId'] as String?) ?? '';
              if (currentUid.isEmpty || clinicId.isEmpty) {
                toast(context, 'Missing account/clinic.');
                return;
              }

              final ts = Timestamp.fromDate(when);
              await FirebaseFirestore.instance.collection('reminders').add({
                'uid': currentUid,
                'type': normalizeType(type),
                'title': titleCtrl.text.trim(),
                'clinicId': clinicId,
                'when': ts,
                'dueAt': ts,
                'patientId': patientId,
                'createdAt': FieldValue.serverTimestamp(),
                'updatedAt': FieldValue.serverTimestamp(),
              });
              if (!mounted) return;
              Navigator.pop(context);
              toast(context, 'Reminder created.');
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }
}
