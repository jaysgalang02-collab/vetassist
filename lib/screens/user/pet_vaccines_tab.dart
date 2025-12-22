import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

// Local date formatter (yyyy-mm-dd)
String _fmt(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

class PetVaccinesTab extends StatelessWidget {
  final String patientId;
  const PetVaccinesTab({super.key, required this.patientId});

  @override
  Widget build(BuildContext context) {
    // Firestore index (one-time): vaccines: patientId ASC, dateGiven DESC
    final q = FirebaseFirestore.instance
        .collection('vaccines')
        .where('patientId', isEqualTo: patientId)
        .orderBy('dateGiven', descending: true);

    return StreamBuilder<QuerySnapshot>(
      stream: q.snapshots(),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return _FriendlyError(title: 'Couldn’t load vaccines', error: snap.error);
        }
        if (!snap.hasData || snap.data!.docs.isEmpty) {
          return const _EmptyState('No vaccination records.');
        }

        final list = snap.data!.docs;
        return ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: list.length,
          separatorBuilder: (_, __) => const SizedBox(height: 6),
          itemBuilder: (_, i) {
            final d = list[i].data() as Map<String, dynamic>;

            final name = (d['name'] ?? 'Vaccine').toString();

            // Accept both 'dateGiven' or 'date'
            final givenTs = (d['dateGiven'] ?? d['date']) as Timestamp?;
            final date = givenTs?.toDate();

            final due = (d['dueNext'] as Timestamp?)?.toDate();
            final remarks = (d['remarks'] ?? '').toString();

            final parts = <String>[
              if (date != null) 'Given: ${_fmt(date)}',
              if (due != null) 'Due next: ${_fmt(due)}',
              if (remarks.isNotEmpty) 'Note: $remarks',
            ];

            return Card(
              child: ListTile(
                leading: const Icon(Icons.vaccines),
                title: Text(name),
                subtitle: Text(
                  parts.isEmpty ? '—' : parts.join(' • '),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            );
          },
        );
      },
    );
  }
}

/* ---------- lightweight local fallbacks ---------- */

class _EmptyState extends StatelessWidget {
  final String message;
  const _EmptyState(this.message);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          message,
          style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
      ),
    );
  }
}

class _FriendlyError extends StatelessWidget {
  final String title;
  final Object? error;
  const _FriendlyError({required this.title, this.error});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, color: cs.error, size: 28),
            const SizedBox(height: 8),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
            if (error != null) ...[
              const SizedBox(height: 6),
              Text(
                '$error',
                textAlign: TextAlign.center,
                style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
