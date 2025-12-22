import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../../../utils/toast.dart';
import '../staff_common.dart';

class PatientsTab extends StatefulWidget {
  final String clinicId;
  const PatientsTab({super.key, required this.clinicId});

  @override
  State<PatientsTab> createState() => _PatientsTabState();
}

class _PatientsTabState extends State<PatientsTab> {
  final _qCtrl = TextEditingController();
  String _species = 'all'; // all | canine | feline

  // Simple in-memory cache so we don’t fetch the same user multiple times.
  final Map<String, String?> _ownerNameCache = {};

  @override
  void dispose() {
    _qCtrl.dispose();
    super.dispose();
  }

  // Fetch display name (or email) of owner from users/{uid}, with caching.
  Future<String?> _fetchOwnerLabel(String ownerUid) async {
    if (ownerUid.isEmpty) return null;
    if (_ownerNameCache.containsKey(ownerUid)) return _ownerNameCache[ownerUid];

    try {
      final doc =
          await FirebaseFirestore.instance.collection('users').doc(ownerUid).get();
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
      // Fail silently; we'll show a short UID fallback.
      _ownerNameCache[ownerUid] = null;
      return null;
    }
  }

  String _shortUid(String uid) {
    if (uid.length <= 8) return uid;
    return '${uid.substring(0, 4)}…${uid.substring(uid.length - 4)}';
    // e.g. VsWX…c973
  }

  @override
  Widget build(BuildContext context) {
    final q = _qCtrl.text.trim();
    final clinicId = widget.clinicId;

    Query<Map<String, dynamic>> query = FirebaseFirestore.instance
        .collection('patients')
        .where('clinicId', isEqualTo: clinicId);

    if (_species == 'canine') {
      query = query.where('species', isEqualTo: 'canine');
    } else if (_species == 'feline') {
      query = query.where('species', isEqualTo: 'feline');
    }

    if (q.isNotEmpty) {
      query = query.orderBy('name').startAt([q]).endAt(['$q\uf8ff']);
    } else {
      query = query.orderBy('name');
    }

    return Column(
      children: [
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
            stream: query.snapshots(),
            builder: (ctx, snap) {
              if (!snap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final docs = snap.data!.docs;
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
                    // Owner NAME (fallback to email, then short UID)
                    subtitle: FutureBuilder<String?>(
                      future: _fetchOwnerLabel(ownerUid),
                      builder: (context, snap) {
                        final ownerLabel =
                            snap.data ?? (ownerUid.isEmpty ? '—' : _shortUid(ownerUid));
                        final text =
                            'Species: $species • Owner: $ownerLabel';
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
                        PopupMenuItem(value: 'visit', child: Text('Add visit/treatment')),
                        PopupMenuItem(value: 'rem', child: Text('Add reminder')),
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
                      setState(() => date = DateTime(
                          picked.year, picked.month, picked.day, date!.hour, date!.minute));
                    }
                  },
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
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
              if (mounted) Navigator.pop(context);
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
    final diagnosisCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    DateTime date = DateTime.now();

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Record visit / treatment'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                  decoration: const InputDecoration(labelText: 'Diagnosis (optional)'),
                  controller: diagnosisCtrl),
              const SizedBox(height: 8),
              TextField(
                controller: notesCtrl,
                maxLines: 4,
                decoration: const InputDecoration(labelText: 'Treatment / notes'),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Date: ${date.toLocal().toString().split(".").first}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.calendar_today),
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: date,
                        firstDate: DateTime(2010),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) {
                        setState(() => date = DateTime(
                            picked.year, picked.month, picked.day, date.hour, date.minute));
                      }
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              final ownerUid = (p['ownerUid'] as String?) ?? '';
              final clinicId = (p['clinicId'] as String?) ?? '';
              if (ownerUid.isEmpty || clinicId.isEmpty) {
                toast(context, 'Missing owner/clinic.');
                return;
              }

              await FirebaseFirestore.instance.collection('visits').add({
                'ownerUid': ownerUid,
                'patientId': patientId,
                'date': Timestamp.fromDate(date),
                'clinicId': clinicId,
                'diagnosis': diagnosisCtrl.text.trim(),
                'notes': notesCtrl.text.trim(),
                'createdAt': FieldValue.serverTimestamp(),
              });
              if (mounted) Navigator.pop(context);
              toast(context, 'Visit saved.');
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
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
                      setState(() => when = DateTime(
                          picked.year, picked.month, picked.day, when.hour, when.minute));
                    }
                  },
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              // staff UID (must equal request.auth.uid per rules)
              final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';
              final clinicId = (p['clinicId'] as String?) ?? '';
              if (currentUid.isEmpty || clinicId.isEmpty) {
                toast(context, 'Missing account/clinic.');
                return;
              }

              final ts = Timestamp.fromDate(when);
              await FirebaseFirestore.instance.collection('reminders').add({
                'uid': currentUid,                   // rules check this
                'type': normalizeType(type),
                'title': titleCtrl.text.trim(),
                'clinicId': clinicId,
                'when': ts,                          // show in UI
                'dueAt': ts,                         // legacy compatibility
                'patientId': patientId,
                'createdAt': FieldValue.serverTimestamp(),
                'updatedAt': FieldValue.serverTimestamp(),
              });
              if (mounted) Navigator.pop(context);
              toast(context, 'Reminder created.');
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }
}
