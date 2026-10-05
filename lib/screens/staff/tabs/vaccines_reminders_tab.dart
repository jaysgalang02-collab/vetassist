import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class VaccinesRemindersTab extends StatefulWidget {
  final String clinicId;
  const VaccinesRemindersTab({super.key, required this.clinicId});

  @override
  State<VaccinesRemindersTab> createState() => _VaccinesRemindersTabState();
}

class _VaccinesRemindersTabState extends State<VaccinesRemindersTab> {
  final Map<String, Map<String, dynamic>?> _patientCache = {};
  final Map<String, Map<String, dynamic>?> _userCache = {};

  @override
  Widget build(BuildContext context) {
    final vaxQuery = FirebaseFirestore.instance
        .collection('vaccines')
        .where('clinicId', isEqualTo: widget.clinicId);

    final remQuery = FirebaseFirestore.instance
        .collection('reminders')
        .where('clinicId', isEqualTo: widget.clinicId);

    return Row(
      children: [
        Expanded(
          child: _CardSection(
            title: 'Recent Vaccinations',
            stream: vaxQuery.snapshots(),
            buildList: (docs, cs) {
              docs.sort((a, b) {
                final ad = _tsToDate(a.data()['dateGiven']) ??
                    _tsToDate(a.data()['createdAt']) ??
                    DateTime.fromMillisecondsSinceEpoch(0);
                final bd = _tsToDate(b.data()['dateGiven']) ??
                    _tsToDate(b.data()['createdAt']) ??
                    DateTime.fromMillisecondsSinceEpoch(0);
                return bd.compareTo(ad);
              });

              return ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: 4),
                itemCount: docs.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (ctx, i) {
                  final m = docs[i].data();
                  final id = docs[i].id;
                  final name = (m['name'] ?? '—').toString();
                  final pid = (m['patientId'] ?? '').toString();
                  final ownerUid = (m['ownerUid'] ?? '').toString();
                  final when =
                      _tsToDate(m['dateGiven']) ?? _tsToDate(m['createdAt']);

                  return ListTile(
                    dense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                    leading: const Icon(Icons.vaccines),
                    title: Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      softWrap: false,
                    ),
                    trailing: Text(
                      when == null ? '' : _fmt(when),
                      style:
                          TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      softWrap: false,
                    ),
                    onTap: () => _showDetailSheet(
                      context: context,
                      kind: _DetailKind.vaccine,
                      itemId: id,
                      itemData: m,
                      patientId: pid,
                      ownerUid: ownerUid,
                    ),
                  );
                },
              );
            },
            emptyPlaceholder: const Text('No vaccinations recorded.'),
          ),
        ),
        const VerticalDivider(width: 1),
        Expanded(
          child: _CardSection(
            title: 'Upcoming Reminders',
            stream: remQuery.snapshots(),
            buildList: (docs, cs) {
              docs.sort((a, b) {
                final ad = _tsToDate(a.data()['when']) ??
                    _tsToDate(a.data()['dueAt']) ??
                    _tsToDate(a.data()['createdAt']) ??
                    DateTime.fromMillisecondsSinceEpoch(0);
                final bd = _tsToDate(b.data()['when']) ??
                    _tsToDate(b.data()['dueAt']) ??
                    _tsToDate(b.data()['createdAt']) ??
                    DateTime.fromMillisecondsSinceEpoch(0);
                return ad.compareTo(bd);
              });

              return ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: 4),
                itemCount: docs.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (ctx, i) {
                  final m = docs[i].data();
                  final id = docs[i].id;
                  final title = (m['title'] ?? '—').toString();
                  final pid = (m['patientId'] ?? '').toString();
                  final ownerUidFromReminder = (m['ownerUid'] ?? '').toString();

                  final when = _tsToDate(m['when']) ??
                      _tsToDate(m['dueAt']) ??
                      _tsToDate(m['createdAt']);

                  return ListTile(
                    dense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                    leading: const Icon(Icons.alarm),
                    title: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      softWrap: false,
                    ),
                    trailing: Text(
                      when == null ? '' : _fmt(when),
                      style:
                          TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      softWrap: false,
                    ),
                    onTap: () => _showDetailSheet(
                      context: context,
                      kind: _DetailKind.reminder,
                      itemId: id,
                      itemData: m,
                      patientId: pid,
                      ownerUid: ownerUidFromReminder,
                    ),
                  );
                },
              );
            },
            emptyPlaceholder: const Text('No upcoming reminders.'),
          ),
        ),
      ],
    );
  }

  Future<void> _showDetailSheet({
    required BuildContext context,
    required _DetailKind kind,
    required String itemId,
    required Map<String, dynamic> itemData,
    required String patientId,
    required String ownerUid,
  }) async {
    final cs = Theme.of(context).colorScheme;

    final patient = await _getPatient(patientId);
    final resolvedOwnerUid =
        ownerUid.isNotEmpty ? ownerUid : (patient?['ownerUid'] ?? '');
    final owner = await _getUser(resolvedOwnerUid);

    final petName = (patient?['name'] ?? '—').toString();
    final species = (patient?['species'] ?? '—').toString();
    final breed = (patient?['breed'] ?? '').toString();
    final sex = (patient?['sex'] ?? '').toString();

    final ownerName = _bestOwnerLabel(owner, resolvedOwnerUid);

    String title;
    List<_KeyValue> facts = [];

    if (kind == _DetailKind.vaccine) {
      title = (itemData['name'] ?? 'Vaccine').toString();
      final date =
          _tsToDate(itemData['dateGiven']) ?? _tsToDate(itemData['createdAt']);
      facts = [
        _KeyValue('Type', 'Vaccine'),
        _KeyValue('Date', date == null ? '—' : _fmt(date)),
        _KeyValue('Patient ID', patientId),
        _KeyValue('Record ID', itemId),
      ];
    } else {
      title = (itemData['title'] ?? 'Reminder').toString();
      final when = _tsToDate(itemData['when']) ??
          _tsToDate(itemData['dueAt']) ??
          _tsToDate(itemData['createdAt']);
      final type = (itemData['type'] ?? '—').toString();
      facts = [
        _KeyValue('Type', type),
        _KeyValue('When', when == null ? '—' : _fmt(when)),
        _KeyValue('Patient ID', patientId),
        _KeyValue('Record ID', itemId),
      ];
    }

    if (!mounted) return;
    await showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Icon(
                      kind == _DetailKind.vaccine
                          ? Icons.vaccines
                          : Icons.alarm,
                      color: cs.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 18),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
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
                  title: ownerName,
                  subtitle: (owner?['email'] ?? '').toString(),
                ),
                const SizedBox(height: 12),
                _FactsGrid(facts: facts),
              ],
            ),
          ),
        );
      },
    );
  }

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

  static DateTime? _tsToDate(dynamic v) {
    if (v == null) return null;
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    return null;
  }

  static String _fmt(DateTime d) =>
      '${d.year}-${_p2(d.month)}-${_p2(d.day)} ${_p2(d.hour)}:${_p2(d.minute)}';
  static String _p2(int n) => n.toString().padLeft(2, '0');
}

enum _DetailKind { vaccine, reminder }

class _KeyValue {
  final String k;
  final String v;
  const _KeyValue(this.k, this.v);
}

class _InfoCard extends StatelessWidget {
  final Widget leading;
  final String title;
  final String subtitle;
  const _InfoCard({
    required this.leading,
    required this.title,
    required this.subtitle,
  });

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
            child: IconTheme(
              data: IconThemeData(color: cs.primary),
              child: leading,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 16),
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
          ),
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
              Text('Details',
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 16)),
            ],
          ),
          const SizedBox(height: 8),
          ...facts.map((kv) => Padding(
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
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}

class _CardSection extends StatelessWidget {
  final String title;
  final Stream<QuerySnapshot<Map<String, dynamic>>> stream;

  final Widget Function(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    ColorScheme cs,
  ) buildList;

  final Widget emptyPlaceholder;

  const _CardSection({
    required this.title,
    required this.stream,
    required this.buildList,
    required this.emptyPlaceholder,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.all(8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: cs.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
            decoration: BoxDecoration(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(12)),
              color: cs.surfaceContainerHighest,
            ),
            child: Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: cs.onSurface,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              softWrap: false,
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: stream,
              builder: (ctx, snap) {
                if (snap.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        'Error loading $title.\n${snap.error}',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final docs = snap.data?.docs ?? const [];
                if (docs.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: emptyPlaceholder,
                    ),
                  );
                }
                return buildList(docs, cs);
              },
            ),
          ),
        ],
      ),
    );
  }
}
