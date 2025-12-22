import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

// Local date formatter (yyyy-mm-dd)
String _fmt(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

class PetVisitsTab extends StatelessWidget {
  final String patientId;
  const PetVisitsTab({super.key, required this.patientId});

  @override
  Widget build(BuildContext context) {
    // Firestore index (one-time): visits: patientId ASC, date DESC
    final q = FirebaseFirestore.instance
        .collection('visits')
        .where('patientId', isEqualTo: patientId)
        .orderBy('date', descending: true);

    return StreamBuilder<QuerySnapshot>(
      stream: q.snapshots(),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return _FriendlyError(title: 'Couldn’t load visits', error: snap.error);
        }
        if (!snap.hasData || snap.data!.docs.isEmpty) {
          return const _EmptyState('No visits yet.');
        }

        final list = snap.data!.docs;
        return ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: list.length,
          separatorBuilder: (_, __) => const SizedBox(height: 6),
          itemBuilder: (_, i) {
            final d = list[i].data() as Map<String, dynamic>;
            final date = (d['date'] as Timestamp?)?.toDate();
            final clinic = (d['clinic'] ?? '').toString();
            final vet = (d['veterinarian'] ?? '').toString();
            final assess = (d['diagnosisSummary'] ?? '').toString();
            final meds = (d['prescription'] ?? '').toString();

            final chips = <String>[
              if (clinic.isNotEmpty) clinic,
              if (vet.isNotEmpty) 'Vet: $vet',
            ];

            final notes = <String>[
              if (assess.isNotEmpty) 'Assessment: $assess',
              if (meds.isNotEmpty) 'Rx: $meds',
            ].join(' • ');

            return Card(
              child: ListTile(
                leading: const Icon(Icons.assignment),
                title: Text(date != null ? _fmt(date) : 'Unknown date'),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (chips.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2, bottom: 4),
                        child: Text(
                          chips.join(' • '),
                          style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                        ),
                      ),
                    if (notes.isNotEmpty)
                      Text(
                        notes,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
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
