import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../../../models/soap_record.dart';
import '../../../../widgets/medical_record_list.dart';
import '../medical_record_editor.dart';

class VisitsTab extends StatelessWidget {
  const VisitsTab({super.key, required this.clinicId});
  final String clinicId;

  Future<void> _newRecord(BuildContext context) async {
    final patientId = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => FractionallySizedBox(
          heightFactor: .85, child: _MedicalPatientPicker(clinicId: clinicId)),
    );
    if (patientId == null || !context.mounted) return;
    await openMedicalRecordEditor(context,
        clinicId: clinicId, patientId: patientId);
  }

  @override
  Widget build(BuildContext context) => Column(children: [
        Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Medical records',
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Text('A clear history of every patient visit.',
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant)),
                const SizedBox(height: 16),
                FilledButton.icon(
                    onPressed: () => _newRecord(context),
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('New SOAP record')),
              ],
            )),
        Expanded(child: MedicalRecordList(clinicId: clinicId)),
      ]);
}

class _MedicalPatientPicker extends StatefulWidget {
  const _MedicalPatientPicker({required this.clinicId});
  final String clinicId;
  @override
  State<_MedicalPatientPicker> createState() => _MedicalPatientPickerState();
}

class _MedicalPatientPickerState extends State<_MedicalPatientPicker> {
  String _search = '';
  late Stream<QuerySnapshot<Map<String, dynamic>>> _patients = _query();
  final Map<String, Future<String>> _owners = {};

  Stream<QuerySnapshot<Map<String, dynamic>>> _query() =>
      FirebaseFirestore.instance
          .collection('patients')
          .where('clinicId', isEqualTo: widget.clinicId)
          .snapshots();

  Future<String> _owner(String uid) {
    if (uid.isEmpty) return Future.value('Owner not recorded');
    return _owners.putIfAbsent(uid, () async {
      try {
        final user = (await FirebaseFirestore.instance
                    .collection('users')
                    .doc(uid)
                    .get()
                    .timeout(const Duration(seconds: 10)))
                .data() ??
            {};
        return recordText(user['displayName']).isNotEmpty
            ? recordText(user['displayName'])
            : recordText(user['email']);
      } catch (_) {
        return 'Owner details load when opened';
      }
    });
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.fromLTRB(
            16, 0, 16, MediaQuery.viewInsetsOf(context).bottom),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('Choose a patient',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          TextField(
              decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Search patient name'),
              onChanged: (value) =>
                  setState(() => _search = value.trim().toLowerCase())),
          const SizedBox(height: 12),
          Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _patients,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Text('Patients could not load.'),
                  TextButton(
                      onPressed: () => setState(() => _patients = _query()),
                      child: const Text('Retry')),
                ]));
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final patients = snapshot.data!.docs
                  .where((d) => recordText(d.data()['name'])
                      .toLowerCase()
                      .contains(_search))
                  .toList()
                ..sort((a, b) => recordText(a.data()['name'])
                    .toLowerCase()
                    .compareTo(recordText(b.data()['name']).toLowerCase()));
              if (patients.isEmpty) {
                return const Center(child: Text('No patients found.'));
              }
              return ListView.builder(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                itemCount: patients.length,
                itemBuilder: (context, i) {
                  final doc = patients[i];
                  final data = doc.data();
                  return ListTile(
                    leading:
                        const CircleAvatar(child: Icon(Icons.pets_outlined)),
                    title: Text(recordText(data['name']),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: FutureBuilder<String>(
                        future: _owner(recordText(data['ownerUid'])),
                        builder: (_, owner) => Text(
                            [
                              recordText(data['species']),
                              owner.data ?? 'Loading owner...'
                            ].where((s) => s.isNotEmpty).join(' · '),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis)),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.pop(context, doc.id),
                  );
                },
              );
            },
          )),
        ]),
      );
}
