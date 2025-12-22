import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'pet_form_screen.dart';

class PetProfileTab extends StatelessWidget {
  final String patientId;
  const PetProfileTab({super.key, required this.patientId});

  Future<void> _confirmAndDelete(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete pet'),
        content: const Text(
          'This will permanently remove the pet and its related visits, vaccines, '
          'and reminders. This action cannot be undone.'
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    final db = FirebaseFirestore.instance;
    final batch = db.batch();

    // cascade delete related docs
    for (final col in ['visits', 'vaccines', 'reminders']) {
      final q = await db.collection(col).where('patientId', isEqualTo: patientId).get();
      for (final d in q.docs) {
        batch.delete(d.reference);
      }
    }
    batch.delete(db.collection('patients').doc(patientId));
    await batch.commit();

    if (context.mounted) {
      Navigator.pop(context); // pop PetDetail screen
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pet deleted')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ref = FirebaseFirestore.instance.collection('patients').doc(patientId);

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: ref.snapshots(),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snap.hasData || !snap.data!.exists) {
          return const Center(child: Text('Pet not found.'));
        }

        final d = snap.data!.data()!;
        String _s(String key) {
          final v = d[key];
          if (v == null) return '—';
          final s = '$v'.trim();
          return s.isEmpty ? '—' : s;
        }

        final rows = <_ProfileRow>[
          _ProfileRow('Species', _s('species')),
          _ProfileRow('Breed', _s('breed')),
          _ProfileRow('Sex', _s('sex')),
          _ProfileRow('Color/Markings', _s('colorMarkings')),
          _ProfileRow('Weight', d['weightKg'] == null ? '—' : '${d['weightKg']} kg'),
          _ProfileRow('Allergies', _s('allergies')),
          _ProfileRow('Notes', _s('notes')),
        ];

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          itemCount: rows.length + 1, // +1 actions
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (_, i) {
            if (i == 0) {
              // ACTIONS: Update / Delete
              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest.withOpacity(.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () {
                          // Push via constructor so edit mode always works
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => PetFormScreen(editPatientId: patientId),
                              settings: const RouteSettings(name: PetFormScreen.route),
                            ),
                          );
                        },
                        icon: const Icon(Icons.edit),
                        label: const Text('Update'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: cs.error,
                          side: BorderSide(color: cs.error),
                        ),
                        onPressed: () => _confirmAndDelete(context),
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('Delete'),
                      ),
                    ),
                  ],
                ),
              );
            }

            final r = rows[i - 1];
            return Container(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest.withOpacity(.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 140,
                    child: Text(
                      r.label,
                      style: TextStyle(
                        color: cs.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      r.value,
                      textAlign: TextAlign.left,
                      style: const TextStyle(fontSize: 15),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _ProfileRow {
  final String label;
  final String value;
  _ProfileRow(this.label, this.value);
}
