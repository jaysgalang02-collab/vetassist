import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

/// Customer view — shows reminders that belong to the
/// current customer's pets (patients the user owns).
///
/// Your `reminders` docs (per screenshots) look like:
/// { clinicId, createdAt, dueAt, patientId, title, type, uid, updatedAt, when }
/// Note: `uid` is the STAFF who created the reminder. There is NO `ownerUid`
/// in reminders. So we must first get the customer’s patient IDs, then query
/// reminders where `patientId` is in those IDs.
class RemindersScreen extends StatefulWidget {
  static const route = '/reminders';
  const RemindersScreen({super.key});

  @override
  State<RemindersScreen> createState() => _RemindersScreenState();
}

class _RemindersScreenState extends State<RemindersScreen> {
  /// 0 = Upcoming, 1 = Past
  int _tab = 0;

  /// Cache patientId -> patient (to display pet name/species)
  final Map<String, Map<String, dynamic>?> _patientCache = {};

  /// Pull-to-refresh
  final GlobalKey<RefreshIndicatorState> _refreshKey =
      GlobalKey<RefreshIndicatorState>();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Reminders')),
        body: const Center(child: Text('You need to sign in.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reminders'),
        backgroundColor: cs.surface,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(50),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
            child: _Segmented(
              segments: const ['Upcoming', 'Past'],
              index: _tab,
              onChanged: (i) => setState(() => _tab = i),
            ),
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: () => _refreshKey.currentState?.show(),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      backgroundColor: cs.surface,
      body: RefreshIndicator(
        key: _refreshKey,
        onRefresh: () async {
          setState(() {
            _patientCache.clear();
          });
        },
        child: FutureBuilder<List<String>>(
          future: _loadMyPatientIds(uid),
          builder: (context, petIdsSnap) {
            if (petIdsSnap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (petIdsSnap.hasError) {
              return _ErrorBox(message: 'Couldn’t load your pets.');
            }

            final patientIds = petIdsSnap.data ?? const <String>[];
            if (patientIds.isEmpty) {
              return const _EmptyView();
            }

            final batches = _chunk(patientIds, 10); // Firestore whereIn limit
            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
              itemCount: batches.length,
              itemBuilder: (context, i) {
                final batch = batches[i];
                final query = FirebaseFirestore.instance
                    .collection('reminders')
                    .where('patientId', whereIn: batch)
                    .orderBy('dueAt');

                return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: query.snapshots(),
                  builder: (ctx, snap) {
                    if (snap.connectionState == ConnectionState.waiting &&
                        !(snap.hasData && snap.data!.docs.isNotEmpty)) {
                      return const Padding(
                        padding: EdgeInsets.all(8),
                        child: LinearProgressIndicator(minHeight: 2),
                      );
                    }

                    if (snap.hasError) {
                      final err = snap.error;
                      String msg = 'Couldn’t load reminders.';
                      if (err is FirebaseException &&
                          err.code == 'permission-denied') {
                        msg =
                            'Couldn’t load reminders.\n[permission-denied] Not allowed.';
                      } else if (err is FirebaseException &&
                          err.code == 'failed-precondition') {
                        msg =
                            'Reminders index is building. It will appear once ready.';
                      }
                      return _ErrorBox(message: msg);
                    }

                    final docs = snap.data?.docs ?? const [];
                    if (docs.isEmpty) return const SizedBox.shrink();

                    final rows = docs
                        .map((d) => _ReminderRow.fromDoc(d.id, d.data()))
                        .toList()
                      ..sort((a, b) {
                        final ad = a.dueAt ??
                            DateTime.fromMillisecondsSinceEpoch(0);
                        final bd = b.dueAt ??
                            DateTime.fromMillisecondsSinceEpoch(0);
                        return ad.compareTo(bd);
                      });

                    final now = DateTime.now();
                    final upcoming = rows
                        .where((r) =>
                            (r.dueAt ?? now).isAfter(now) || _sameDay(r.dueAt, now))
                        .toList();
                    final past = rows
                        .where((r) =>
                            (r.dueAt ?? now).isBefore(_startOfDay(now)))
                        .toList();

                    final show = _tab == 0 ? upcoming : past;
                    if (show.isEmpty) return const SizedBox.shrink();

                    return Column(
                      children: [
                        for (final r in show)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _ReminderCard(
                              row: r,
                              petFuture: _getPatient(r.patientId),
                              onTap: () => _openDetail(context, r),
                            ),
                          ),
                      ],
                    );
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }

  // ---------- data helpers ----------

  Future<List<String>> _loadMyPatientIds(String ownerUid) async {
    final q = await FirebaseFirestore.instance
        .collection('patients')
        .where('ownerUid', isEqualTo: ownerUid)
        .get();
    return q.docs.map((d) => d.id).toList();
  }

  List<List<String>> _chunk(List<String> list, int size) {
    if (list.isEmpty) return const [];
    final List<List<String>> out = [];
    for (int i = 0; i < list.length; i += size) {
      out.add(
        list.sublist(i, i + size > list.length ? list.length : i + size),
      );
    }
    return out;
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

  void _openDetail(BuildContext context, _ReminderRow r) async {
    final pet = await _getPatient(r.patientId);
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        final cs = Theme.of(context).colorScheme;
        final petName = (pet?['name'] as String?)?.trim();
        final species = (pet?['species'] as String?)?.trim();
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(children: [
                  Icon(Icons.notifications_active, color: cs.primary),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text('Reminder',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w700)),
                  ),
                ]),
                const SizedBox(height: 12),
                _FactRow(label: 'Title', value: r.title ?? '—'),
                _FactRow(label: 'Type', value: r.type ?? '—'),
                _FactRow(
                    label: 'Due', value: r.dueAt == null ? '—' : _fmt(r.dueAt!)),
                const SizedBox(height: 10),
                _FactRow(
                  label: 'Patient',
                  value: petName == null || petName.isEmpty
                      ? r.patientIdObfuscated
                      : (species == null || species.isEmpty)
                          ? petName
                          : '$petName • $species',
                ),
                const SizedBox(height: 6),
                _FactRow(label: 'Record ID', value: r.id),
                const SizedBox(height: 4),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ===================== models & UI =====================

class _ReminderRow {
  final String id;
  final String clinicId;
  final String patientId;
  final String? title;
  final String? type;
  final DateTime? dueAt;
  final DateTime? createdAt;

  const _ReminderRow({
    required this.id,
    required this.clinicId,
    required this.patientId,
    required this.title,
    required this.type,
    required this.dueAt,
    required this.createdAt,
  });

  String get patientIdObfuscated => patientId.length < 8
      ? patientId
      : '${patientId.substring(0, 4)}…${patientId.substring(patientId.length - 4)}';

  static _ReminderRow fromDoc(String id, Map<String, dynamic> m) {
    final due = _toDate(m['dueAt']) ?? _toDate(m['when']); // legacy support
    return _ReminderRow(
      id: id,
      clinicId: (m['clinicId'] ?? '').toString(),
      patientId: (m['patientId'] ?? '').toString(),
      title: (m['title'] as String?)?.trim(),
      type: (m['type'] as String?)?.trim(),
      dueAt: due,
      createdAt: _toDate(m['createdAt']),
    );
  }

  static DateTime? _toDate(dynamic v) {
    if (v == null) return null;
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    return null;
  }
}

class _ReminderCard extends StatelessWidget {
  final _ReminderRow row;
  final Future<Map<String, dynamic>?> petFuture;
  final VoidCallback onTap;

  const _ReminderCard({
    required this.row,
    required this.petFuture,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Material(
      color: cs.surfaceContainerHighest.withOpacity(.6),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: cs.primary.withOpacity(.12),
                child: Icon(_iconForType(row.type), color: cs.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FutureBuilder<Map<String, dynamic>?>(
                  future: petFuture,
                  builder: (context, snap) {
                    final pet = snap.data;
                    final petName = (pet?['name'] as String?)?.trim();
                    final species = (pet?['species'] as String?)?.trim();
                    final subtitle = petName == null || petName.isEmpty
                        ? 'Patient: ${row.patientIdObfuscated}'
                        : (species == null || species.isEmpty)
                            ? petName
                            : '$petName • $species';
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          row.title?.isNotEmpty == true
                              ? row.title!
                              : (row.type?.isNotEmpty == true
                                  ? row.type!
                                  : 'Reminder'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: cs.onSurfaceVariant),
                        ),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(width: 12),
              Text(
                row.dueAt == null ? '' : _fmt(row.dueAt!),
                style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _iconForType(String? t) {
    switch ((t ?? '').toLowerCase()) {
      case 'vaccine':
      case 'vaccination':
        return Icons.vaccines;
      case 'followup':
      case 'follow-up':
        return Icons.event_available;
      case 'visit':
        return Icons.assignment_turned_in;
      default:
        return Icons.notifications_active;
    }
  }
}

class _Segmented extends StatelessWidget {
  final List<String> segments;
  final int index;
  final ValueChanged<int> onChanged;
  const _Segmented({
    required this.segments,
    required this.index,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: cs.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          for (int i = 0; i < segments.length; i++)
            Expanded(
              child: InkWell(
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(i == 0 ? 12 : 0),
                  bottomLeft: Radius.circular(i == 0 ? 12 : 0),
                  topRight:
                      Radius.circular(i == segments.length - 1 ? 12 : 0),
                  bottomRight:
                      Radius.circular(i == segments.length - 1 ? 12 : 0),
                ),
                onTap: () => onChanged(i),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: i == index ? cs.primary.withOpacity(.12) : null,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(i == 0 ? 12 : 0),
                      bottomLeft: Radius.circular(i == 0 ? 12 : 0),
                      topRight:
                          Radius.circular(i == segments.length - 1 ? 12 : 0),
                      bottomRight:
                          Radius.circular(i == segments.length - 1 ? 12 : 0),
                    ),
                  ),
                  child: Center(
                    child: Text(
                      segments[i],
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: i == index ? cs.primary : cs.onSurface,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView();
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.event_note, size: 48, color: cs.onSurfaceVariant),
          const SizedBox(height: 8),
          const Text('No reminders at the moment.'),
        ],
      ),
    );
  }
}

class _ErrorBox extends StatelessWidget {
  final String message;
  const _ErrorBox({required this.message});
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.red),
        ),
      ),
    );
  }
}

class _FactRow extends StatelessWidget {
  final String label;
  final String value;
  const _FactRow({required this.label, required this.value});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 96,
            child: Text(
              label,
              style: TextStyle(
                color: cs.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(value, maxLines: 3, overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }
}

// ---------- tiny date util ----------

String _fmt(DateTime d) =>
    '${d.year}-${_p2(d.month)}-${_p2(d.day)} ${_p2(d.hour)}:${_p2(d.minute)}';
String _p2(int n) => n.toString().padLeft(2, '0');

bool _sameDay(DateTime? a, DateTime b) {
  if (a == null) return false;
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

DateTime _startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);
