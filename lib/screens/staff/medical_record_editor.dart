import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../models/soap_record.dart';
import 'medical_record_form.dart';

Future<void> openMedicalRecordEditor(
  BuildContext context, {
  required String clinicId,
  required String patientId,
}) async {
  final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
          builder: (_) =>
              _MedicalRecordLoader(clinicId: clinicId, patientId: patientId)));
  if (saved == true && context.mounted) {
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Medical record saved.')));
  }
}

class _MedicalRecordLoader extends StatefulWidget {
  const _MedicalRecordLoader({required this.clinicId, required this.patientId});
  final String clinicId, patientId;
  @override
  State<_MedicalRecordLoader> createState() => _MedicalRecordLoaderState();
}

class _MedicalRecordLoaderState extends State<_MedicalRecordLoader> {
  late final _record = FirebaseFirestore.instance.collection('visits').doc();
  late Future<Map<String, dynamic>> _details = _load();

  Future<Map<String, dynamic>> _load() async {
    final db = FirebaseFirestore.instance;
    final patientDoc = await db
        .collection('patients')
        .doc(widget.patientId)
        .get()
        .timeout(const Duration(seconds: 15));
    final patient = patientDoc.data();
    if (patient == null ||
        patient['clinicId'] != widget.clinicId ||
        recordText(patient['ownerUid']).isEmpty) {
      throw StateError(
          'The patient is unavailable or no longer belongs to this clinic.');
    }
    final documents = await Future.wait([
      db.collection('users').doc(recordText(patient['ownerUid'])).get(),
      db.collection('clinics').doc(widget.clinicId).get(),
    ]).timeout(const Duration(seconds: 15));
    return {
      'patient': patient,
      'owner': documents[0].data() ?? <String, dynamic>{},
      'clinic': documents[1].data() ?? <String, dynamic>{}
    };
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Map<String, dynamic>>(
        future: _details,
        builder: (context, snapshot) {
          final uid = FirebaseAuth.instance.currentUser?.uid;
          if (snapshot.hasError || uid == null) {
            return Scaffold(
              appBar: AppBar(title: const Text('New medical record')),
              body: Center(
                  child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.cloud_off_outlined, size: 40),
                          const SizedBox(height: 12),
                          const Text(
                              'Patient details could not load. Check your connection and clinic access.',
                              textAlign: TextAlign.center),
                          TextButton.icon(
                              onPressed: () =>
                                  setState(() => _details = _load()),
                              icon: const Icon(Icons.refresh),
                              label: const Text('Retry')),
                        ],
                      ))),
            );
          }
          if (!snapshot.hasData) {
            return Scaffold(
                appBar: AppBar(title: const Text('New medical record')),
                body: const Center(child: CircularProgressIndicator()));
          }
          final patient = recordMap(snapshot.data!['patient']);
          final owner = recordMap(snapshot.data!['owner']);
          final clinic = recordMap(snapshot.data!['clinic']);
          return MedicalRecordForm(
            recordId: _record.id,
            clinicId: widget.clinicId,
            clinicName: recordText(clinic['name']).isEmpty
                ? 'Your clinic'
                : recordText(clinic['name']),
            patientId: widget.patientId,
            ownerUid: recordText(patient['ownerUid']),
            authorUid: uid,
            initialValues: patientRecordDefaults(patient, owner),
            onSave: (data) async {
              if (FirebaseAuth.instance.currentUser?.uid != uid) {
                throw StateError('Please sign in again.');
              }
              await FirebaseFirestore.instance
                  .runTransaction((transaction) async {
                final current = await transaction.get(FirebaseFirestore.instance
                    .collection('patients')
                    .doc(widget.patientId));
                final existing = await transaction.get(_record);
                if (current.data()?['clinicId'] != widget.clinicId ||
                    current.data()?['ownerUid'] != data['ownerUid']) {
                  throw StateError(
                      'Patient assignment has changed. Reopen the medical record.');
                }
                if (existing.exists && existing.data()?['createdBy'] != uid) {
                  throw StateError('This record belongs to another author.');
                }
                transaction.set(_record, {
                  ...data,
                  if (existing.exists)
                    'createdAt': existing.data()?['createdAt'],
                });
              }).timeout(const Duration(seconds: 20));
            },
          );
        },
      );
}
