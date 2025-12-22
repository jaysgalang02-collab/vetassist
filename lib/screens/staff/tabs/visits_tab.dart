import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class VisitsTab extends StatefulWidget {
  final String clinicId;
  const VisitsTab({super.key, required this.clinicId});

  @override
  State<VisitsTab> createState() => _VisitsTabState();
}

class _VisitsTabState extends State<VisitsTab> {
  final diagnosisCtrl = TextEditingController();
  final notesCtrl = TextEditingController();
  DateTime _date = DateTime.now();

  String? _patientId;
  Map<String, dynamic>? _patient;

  final Map<String, Map<String, dynamic>?> _patientCache = {};
  final Map<String, Map<String, dynamic>?> _userCache = {};

  @override
  void dispose() {
    diagnosisCtrl.dispose();
    notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Row(
      children: [
        // ───────────── LEFT PANE ─────────────
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // FIXED header (not inside ScrollView)
              const Padding(
                padding: EdgeInsets.fromLTRB(12, 8, 8, 0),
                child: _SectionTitle('New Visit/Treatment'),
              ),

              // Scrollable body
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(12, 8, 8, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Patient picker
                      InkWell(
                        onTap: _openPatientPicker,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 14),
                          decoration: BoxDecoration(
                            border: Border.all(color: cs.outlineVariant),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.pets),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _patient != null
                                          ? (_patient!['name'] ?? '—')
                                          : 'Select patient',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w600),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    if (_patient != null)
                                      FutureBuilder<Map<String, dynamic>?>(
                                        future: _getUser(
                                            (_patient!['ownerUid'] ?? '')
                                                as String),
                                        builder: (context, snap) {
                                          final owner = snap.data;
                                          final label = _bestOwnerLabel(
                                              owner,
                                              (_patient!['ownerUid'] ?? '')
                                                  as String);
                                          final species =
                                              (_patient!['species'] ?? '')
                                                  .toString();
                                          return Text(
                                            [
                                              if (species.isNotEmpty)
                                                'Species: $species',
                                              'Owner: $label',
                                            ].join(' • '),
                                            style: TextStyle(
                                                color: cs.onSurfaceVariant,
                                                fontSize: 12),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          );
                                        },
                                      ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Icon(Icons.expand_more),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      TextField(
                        controller: diagnosisCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Diagnosis (optional)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),

                      TextField(
                        controller: notesCtrl,
                        maxLines: 6,
                        decoration: const InputDecoration(
                          labelText: 'Treatment / notes',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),

                      Row(
                        children: [
                          Expanded(
                            child: Text('Date: ${_fmt(_date)}'),
                          ),
                          IconButton(
                            icon: const Icon(Icons.calendar_month),
                            onPressed: () async {
                              final picked = await showDatePicker(
                                context: context,
                                firstDate: DateTime(2010),
                                lastDate: DateTime(2100),
                                initialDate: _date,
                              );
                              if (picked != null) {
                                setState(() => _date = DateTime(picked.year,
                                    picked.month, picked.day, _date.hour, _date.minute));
                              }
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _patient == null ? null : _saveVisit,
                          icon: const Icon(Icons.save),
                          label: const Text('Save visit'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        const VerticalDivider(width: 1),

        // ───────────── RIGHT PANE ─────────────
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // FIXED header (same padding as left for perfect alignment)
              const Padding(
                padding: EdgeInsets.fromLTRB(8, 8, 12, 0),
                child: _SectionTitle('Recent Visits'),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 12, 0),
                  child: _RecentVisitsList(
                    clinicId: widget.clinicId,
                    patientProvider: _getPatient,
                    userProvider: _getUser,
                    onTapVisit: (docId, data, patient) async {
                      final owner = await _getUser(
                          (patient?['ownerUid'] ?? '') as String);
                      _showVisitDetailSheet(
                          context, docId, data, patient, owner);
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ─────────── Patient Picker ───────────
  Future<void> _openPatientPicker() async {
    final selected = await showModalBottomSheet<_PatientPickResult>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _PatientPickerSheet(
        clinicId: widget.clinicId,
        getUser: _getUser,
      ),
    );

    if (selected != null) {
      setState(() {
        _patientId = selected.patientId;
        _patient = selected.patientData;
      });
    }
  }

  // ─────────── Save visit ───────────
  Future<void> _saveVisit() async {
    if (_patientId == null || _patient == null) return;

    final ownerUid = (_patient!['ownerUid'] ?? '') as String? ?? '';
    final clinicId = (_patient!['clinicId'] ?? '') as String? ?? '';
    if (ownerUid.isEmpty || clinicId.isEmpty) {
      _snack('Missing patient owner/clinic.');
      return;
    }

    try {
      await FirebaseFirestore.instance.collection('visits').add({
        'ownerUid': ownerUid,
        'patientId': _patientId,
        'date': Timestamp.fromDate(_date),
        'clinicId': clinicId,
        'diagnosis': diagnosisCtrl.text.trim(),
        'notes': notesCtrl.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      _snack('Visit saved.');
      setState(() {
        diagnosisCtrl.clear();
        notesCtrl.clear();
      });
    } on FirebaseException catch (e) {
      _snack('Save failed: ${e.message ?? e.code}');
    } catch (_) {
      _snack('Save failed. Please try again.');
    }
  }

  // ─────────── Data helpers / caches ───────────
  Future<Map<String, dynamic>?> _getPatient(String patientId) async {
    if (patientId.isEmpty) return null;
    if (_patientCache.containsKey(patientId)) return _patientCache[patientId];
    try {
      final doc = await FirebaseFirestore.instance
          .collection('patients')
          .doc(patientId)
          .get();
      final data = doc.data();
      _patientCache[patientId] = data;
      return data;
    } catch (_) {
      _patientCache[patientId] = null;
      return null;
    }
  }

  Future<Map<String, dynamic>?> _getUser(String uid) async {
    if (uid.isEmpty) return null;
    if (_userCache.containsKey(uid)) return _userCache[uid];
    try {
      final doc =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final data = doc.data();
      _userCache[uid] = data;
      return data;
    } catch (_) {
      _userCache[uid] = null;
      return null;
    }
  }

  String _bestOwnerLabel(Map<String, dynamic>? user, String uid) {
    final dn = (user?['displayName'] as String?)?.trim();
    final em = (user?['email'] as String?)?.trim();
    if (dn != null && dn.isNotEmpty) return dn;
    if (em != null && em.isNotEmpty) return em;
    if (uid.isEmpty) return 'Owner';
    return '${uid.substring(0, 4)}…${uid.substring(uid.length - 4)}';
  }

  void _snack(String msg) =>
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(msg)));
}

// ───────────────── RIGHT LIST ─────────────────

class _RecentVisitsList extends StatelessWidget {
  final String clinicId;
  final Future<Map<String, dynamic>?> Function(String patientId)
      patientProvider;
  final Future<Map<String, dynamic>?> Function(String uid) userProvider;
  final void Function(String docId, Map<String, dynamic> data,
      Map<String, dynamic>? patient) onTapVisit;

  const _RecentVisitsList({
    required this.clinicId,
    required this.patientProvider,
    required this.userProvider,
    required this.onTapVisit,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final visitsQuery = FirebaseFirestore.instance
        .collection('visits')
        .where('clinicId', isEqualTo: clinicId);

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: visitsQuery.snapshots(),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snap.data?.docs ?? const [];
        if (docs.isEmpty) {
          return const Center(child: Text('No visits yet.'));
        }

        // newest first
        docs.sort((a, b) {
          final ad = _tsToDate(a.data()['date']) ??
              _tsToDate(a.data()['createdAt']) ??
              DateTime.fromMillisecondsSinceEpoch(0);
          final bd = _tsToDate(b.data()['date']) ??
              _tsToDate(b.data()['createdAt']) ??
              DateTime.fromMillisecondsSinceEpoch(0);
          return bd.compareTo(ad);
        });

        return ListView.separated(
          padding: const EdgeInsets.only(top: 8, bottom: 8),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, i) {
            final d = docs[i];
            final m = d.data();
            final visitDate =
                _tsToDate(m['date']) ?? _tsToDate(m['createdAt']);
            final pid = (m['patientId'] ?? '').toString();

            return FutureBuilder<Map<String, dynamic>?>(
              future: patientProvider(pid),
              builder: (ctx, patSnap) {
                final patient = patSnap.data;
                final petName = (patient?['name'] ?? '—').toString();
                final species = (patient?['species'] ?? '').toString();
                final ownerUid = (patient?['ownerUid'] ?? '').toString();

                return FutureBuilder<Map<String, dynamic>?>(
                  future: userProvider(ownerUid),
                  builder: (ctx, userSnap) {
                    final owner = userSnap.data;
                    final ownerLabel = _bestOwnerLabel(owner, ownerUid);
                    return ListTile(
                      dense: true,
                      leading: const Icon(Icons.medical_information),
                      title: Text(
                        petName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        softWrap: false,
                      ),
                      subtitle: Text(
                        [
                          if (species.isNotEmpty) 'Species: $species',
                          'Owner: $ownerLabel',
                        ].join(' • '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        softWrap: false,
                      ),
                      trailing: Text(
                        visitDate == null ? '' : _fmt(visitDate),
                        style:
                            TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
                      ),
                      onTap: () => onTapVisit(d.id, m, patient),
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  static DateTime? _tsToDate(dynamic v) {
    if (v == null) return null;
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    return null;
  }

  String _bestOwnerLabel(Map<String, dynamic>? user, String uid) {
    final dn = (user?['displayName'] as String?)?.trim();
    final em = (user?['email'] as String?)?.trim();
    if (dn != null && dn.isNotEmpty) return dn;
    if (em != null && em.isNotEmpty) return em;
    if (uid.isEmpty) return 'Owner';
    return '${uid.substring(0, 4)}…${uid.substring(uid.length - 4)}';
  }
}

// ───────────────── Picker & Detail (unchanged) ─────────────────

class _PatientPickResult {
  final String patientId;
  final Map<String, dynamic> patientData;
  _PatientPickResult(this.patientId, this.patientData);
}

class _PatientPickerSheet extends StatefulWidget {
  final String clinicId;
  final Future<Map<String, dynamic>?> Function(String uid) getUser;
  const _PatientPickerSheet({required this.clinicId, required this.getUser});

  @override
  State<_PatientPickerSheet> createState() => _PatientPickerSheetState();
}

class _PatientPickerSheetState extends State<_PatientPickerSheet> {
  final _qCtrl = TextEditingController();

  @override
  void dispose() {
    _qCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Query<Map<String, dynamic>> q = FirebaseFirestore.instance
        .collection('patients')
        .where('clinicId', isEqualTo: widget.clinicId);

    final search = _qCtrl.text.trim();
    if (search.isNotEmpty) {
      q = q.orderBy('name').startAt([search]).endAt(['$search\uf8ff']);
    } else {
      q = q.orderBy('name');
    }

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Select patient',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
            const SizedBox(height: 12),
            TextField(
              controller: _qCtrl,
              decoration: InputDecoration(
                hintText: 'Search by pet name',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _qCtrl.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () => setState(() => _qCtrl.clear()),
                      ),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: MediaQuery.of(context).size.height * .55,
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: q.snapshots(),
                builder: (ctx, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final docs = snap.data?.docs ?? const [];
                  if (docs.isEmpty) {
                    return const Center(child: Text('No patients found.'));
                  }
                  return ListView.separated(
                    itemCount: docs.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (ctx, i) {
                      final d = docs[i];
                      final m = d.data();
                      final petName = (m['name'] ?? '—').toString();
                      final species = (m['species'] ?? '').toString();
                      final ownerUid = (m['ownerUid'] ?? '').toString();

                      return FutureBuilder<Map<String, dynamic>?>(
                        future: widget.getUser(ownerUid),
                        builder: (ctx, userSnap) {
                          final owner = userSnap.data;
                          final ownerLabel =
                              _bestOwnerLabel(owner, ownerUid);
                          return ListTile(
                            leading: const Icon(Icons.pets),
                            title: Text(
                              petName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              [
                                if (species.isNotEmpty) 'Species: $species',
                                'Owner: $ownerLabel'
                              ].join(' • '),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            onTap: () {
                              Navigator.pop(
                                  context, _PatientPickResult(d.id, m));
                            },
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _bestOwnerLabel(Map<String, dynamic>? user, String uid) {
    final dn = (user?['displayName'] as String?)?.trim();
    final em = (user?['email'] as String?)?.trim();
    if (dn != null && dn.isNotEmpty) return dn;
    if (em != null && em.isNotEmpty) return em;
    if (uid.isEmpty) return 'Owner';
    return '${uid.substring(0, 4)}…${uid.substring(uid.length - 4)}';
  }
}

void _showVisitDetailSheet(
  BuildContext context,
  String visitId,
  Map<String, dynamic> visit,
  Map<String, dynamic>? patient,
  Map<String, dynamic>? owner,
) {
  final cs = Theme.of(context).colorScheme;

  final petName = (patient?['name'] ?? '—').toString();
  final species = (patient?['species'] ?? '').toString();
  final breed = (patient?['breed'] ?? '').toString();
  final sex = (patient?['sex'] ?? '').toString();

  final dn = (owner?['displayName'] as String?)?.trim();
  final em = (owner?['email'] as String?)?.trim();
  final ownerLabel =
      (dn != null && dn.isNotEmpty) ? dn : (em != null && em.isNotEmpty ? em : 'Owner');

  final date = _tsToDate(visit['date']) ?? _tsToDate(visit['createdAt']);
  final diagnosis = (visit['diagnosis'] ?? '').toString();
  final notes = (visit['notes'] ?? '').toString();

  showModalBottomSheet(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    backgroundColor: cs.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(Icons.medical_information, color: cs.primary),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Visit / Treatment',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _InfoCard(
              leading: const Icon(Icons.pets),
              title: petName,
              subtitle: [
                if (species.isNotEmpty) 'Species: $species',
                if (breed.isNotEmpty) 'Breed: $breed',
                if (sex.isNotEmpty) 'Sex: $sex',
              ].join(' • '),
            ),
            const SizedBox(height: 8),
            _InfoCard(
              leading: const Icon(Icons.person),
              title: ownerLabel,
              subtitle: em ?? '',
            ),
            const SizedBox(height: 12),
            _FactsGrid(
              facts: [
                _KeyValue('Date', date == null ? '—' : _fmt(date)),
                _KeyValue('Diagnosis', diagnosis.isEmpty ? '—' : diagnosis),
                _KeyValue('Notes', notes.isEmpty ? '—' : notes),
                _KeyValue('Record ID', visitId),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

// ───────────────── Shared UI ─────────────────

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Text(text, style: const TextStyle(fontWeight: FontWeight.w700)),
    );
  }
}

class _KeyValue {
  final String k;
  final String v;
  const _KeyValue(this.k, this.v);
}

class _InfoCard extends StatelessWidget {
  final Widget leading;
  final String title;
  final String subtitle;
  const _InfoCard({required this.leading, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: cs.primary.withOpacity(0.1),
            child: IconTheme(data: IconThemeData(color: cs.primary), child: leading),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}

class _FactsGrid extends StatelessWidget {
  final List<_KeyValue> facts;
  const _FactsGrid({required this.facts});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: cs.outlineVariant),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, color: cs.primary),
              const SizedBox(width: 8),
              const Text('Details',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            ],
          ),
          const SizedBox(height: 8),
          ...facts.map(
            (kv) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  SizedBox(
                    width: 100,
                    child: Text(
                      kv.k,
                      style: TextStyle(
                        color: cs.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      kv.v,
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ───────────────── Utils (no intl) ─────────────────
DateTime? _tsToDate(dynamic v) {
  if (v == null) return null;
  if (v is Timestamp) return v.toDate();
  if (v is DateTime) return v;
  return null;
}

String _fmt(DateTime d) =>
    '${d.year}-${_p2(d.month)}-${_p2(d.day)} ${_p2(d.hour)}:${_p2(d.minute)}';
String _p2(int n) => n.toString().padLeft(2, '0');
