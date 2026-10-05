import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'pet_form_screen.dart';
import 'pet_profile_tab.dart';
import 'pet_visits_tab.dart';
import 'pet_vaccines_tab.dart';

class PetDetailArgs {
  final String patientId;
  final String? name;
  const PetDetailArgs({required this.patientId, this.name});
}

class PetDetailScreen extends StatelessWidget {
  static const route = '/pet-detail';

  const PetDetailScreen({super.key});

  Future<void> _deletePatient(BuildContext context, String patientId) async {
    final db = FirebaseFirestore.instance;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete pet'),
        content: const Text(
            'This will remove the pet and related visits, vaccines and reminders. '
            'This action cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    final batch = db.batch();

    final visits = await db
        .collection('visits')
        .where('patientId', isEqualTo: patientId)
        .get();
    for (final d in visits.docs) {
      batch.delete(d.reference);
    }

    final vax = await db
        .collection('vaccines')
        .where('patientId', isEqualTo: patientId)
        .get();
    for (final d in vax.docs) {
      batch.delete(d.reference);
    }

    final rem = await db
        .collection('reminders')
        .where('patientId', isEqualTo: patientId)
        .get();
    for (final d in rem.docs) {
      batch.delete(d.reference);
    }

    batch.delete(db.collection('patients').doc(patientId));

    await batch.commit();

    if (context.mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pet deleted')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)!.settings.arguments;
    if (args is! PetDetailArgs) {
      return const Scaffold(body: Center(child: Text('Missing PetDetailArgs')));
    }

    final patientRef =
        FirebaseFirestore.instance.collection('patients').doc(args.patientId);

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: patientRef.snapshots(),
      builder: (ctx, snap) {
        final exists = snap.hasData && snap.data!.exists;
        final data = exists ? snap.data!.data()! : <String, dynamic>{};
        final petName = (data['name'] as String?)?.trim().isNotEmpty == true
            ? data['name'] as String
            : (args.name ?? 'Pet');

        return DefaultTabController(
          length: 3,
          child: Scaffold(
            appBar: AppBar(
              title: Text(petName),
              actions: [
                IconButton(
                  tooltip: 'Edit',
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () {
                    Navigator.pushNamed(
                      context,
                      PetFormScreen.route,
                      arguments: {'patientId': args.patientId},
                    );
                  },
                ),
                IconButton(
                  tooltip: 'Delete',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => _deletePatient(context, args.patientId),
                ),
                PopupMenuButton<String>(
                  onSelected: (v) {
                    if (v == 'edit') {
                      Navigator.pushNamed(
                        context,
                        PetFormScreen.route,
                        arguments: {'patientId': args.patientId},
                      );
                    } else if (v == 'delete') {
                      _deletePatient(context, args.patientId);
                    }
                  },
                  itemBuilder: (ctx) => const [
                    PopupMenuItem(
                        value: 'edit',
                        child: ListTile(
                            leading: Icon(Icons.edit), title: Text('Update'))),
                    PopupMenuItem(
                        value: 'delete',
                        child: ListTile(
                            leading: Icon(Icons.delete_outline),
                            title: Text('Delete'))),
                  ],
                ),
              ],
              bottom: const TabBar(
                tabs: [
                  Tab(text: 'Profile'),
                  Tab(text: 'Visits'),
                  Tab(text: 'Vaccines'),
                ],
              ),
            ),
            body: TabBarView(
              children: [
                PetProfileTab(patientId: args.patientId),
                PetVisitsTab(patientId: args.patientId),
                PetVaccinesTab(patientId: args.patientId),
              ],
            ),
            floatingActionButton: FloatingActionButton.extended(
              heroTag: 'editPetFab',
              onPressed: () {
                Navigator.pushNamed(
                  context,
                  PetFormScreen.route,
                  arguments: {'patientId': args.patientId},
                );
              },
              icon: const Icon(Icons.edit),
              label: const Text('Update'),
            ),
          ),
        );
      },
    );
  }
}
