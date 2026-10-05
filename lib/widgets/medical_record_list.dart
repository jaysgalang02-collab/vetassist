import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/soap_record.dart';
import 'medical_record_view.dart';

class MedicalRecordList extends StatefulWidget {
  const MedicalRecordList({super.key, this.clinicId, this.patientId})
      : assert((clinicId == null) != (patientId == null));
  final String? clinicId, patientId;
  @override
  State<MedicalRecordList> createState() => _MedicalRecordListState();
}

class _MedicalRecordListState extends State<MedicalRecordList> {
  static const _pageSize = 10;
  int _page = 0;
  late Stream<QuerySnapshot<Map<String, dynamic>>> _stream = _query();
  final Map<String, Future<Map<String, dynamic>>> _patients = {};

  Stream<QuerySnapshot<Map<String, dynamic>>> _query() => FirebaseFirestore
      .instance
      .collection('visits')
      .where(widget.clinicId != null ? 'clinicId' : 'patientId',
          isEqualTo: widget.clinicId ?? widget.patientId)
      .snapshots();

  @override
  void didUpdateWidget(covariant MedicalRecordList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.clinicId != widget.clinicId ||
        oldWidget.patientId != widget.patientId) {
      _stream = _query();
      _page = 0;
      _patients.clear();
    }
  }

  Future<Map<String, dynamic>> _patient(Map<String, dynamic> data) {
    final id = recordText(data['patientId']);
    if (id.isEmpty || recordText(data['patientName']).isNotEmpty) {
      return Future.value(<String, dynamic>{});
    }
    return _patients.putIfAbsent(id, () async {
      try {
        return (await FirebaseFirestore.instance
                    .collection('patients')
                    .doc(id)
                    .get()
                    .timeout(const Duration(seconds: 10)))
                .data() ??
            {};
      } catch (_) {
        return {};
      }
    });
  }

  @override
  Widget build(BuildContext context) =>
      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _stream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
                child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.cloud_off_outlined, size: 36),
                        const SizedBox(height: 12),
                        const Text(
                            'Medical records could not load. Check your connection and try again.',
                            textAlign: TextAlign.center),
                        TextButton(
                            onPressed: () => setState(() => _stream = _query()),
                            child: const Text('Retry')),
                      ],
                    )));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final records = [...snapshot.data!.docs]..sort((a, b) {
              DateTime date(Map<String, dynamic> d) =>
                  recordDate(d['date']) ??
                  recordDate(d['createdAt']) ??
                  DateTime(1970);
              final order = date(b.data()).compareTo(date(a.data()));
              return order == 0 ? b.id.compareTo(a.id) : order;
            });
          if (records.isEmpty) {
            return const Center(
                child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.assignment_outlined, size: 42),
                        SizedBox(height: 12),
                        Text('No medical records yet.'),
                        SizedBox(height: 6),
                        Text('Saved visits will appear here.',
                            textAlign: TextAlign.center),
                      ],
                    )));
          }
          final pages = (records.length / _pageSize).ceil();
          final page = _page.clamp(0, pages - 1);
          final visible =
              records.skip(page * _pageSize).take(_pageSize).toList();
          return Column(children: [
            Expanded(
                child: ListView.separated(
              key: ValueKey(
                  'records-${widget.clinicId ?? widget.patientId}-$page'),
              padding: const EdgeInsets.all(16),
              itemCount: visible.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final doc = visible[index];
                final data = doc.data();
                final soap = readableSoap(data);
                final assessment =
                    recordText(soap['assessment']!['primaryDiagnosis']);
                return FutureBuilder<Map<String, dynamic>>(
                  future: _patient(data),
                  builder: (context, patientSnapshot) {
                    final patient = patientSnapshot.data ?? {};
                    final name = recordText(data['patientName']).isNotEmpty
                        ? recordText(data['patientName'])
                        : recordText(patient['name']);
                    return Card(
                        margin: EdgeInsets.zero,
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          leading: CircleAvatar(
                              backgroundColor: Theme.of(context)
                                  .colorScheme
                                  .primaryContainer,
                              child: const Icon(Icons.description_outlined)),
                          title: Text(name.isEmpty ? 'Visit record' : name,
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                          subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(recordDateLabel(recordDate(data['date']) ??
                                    recordDate(data['createdAt']))),
                                if (assessment.isNotEmpty)
                                  Text(assessment,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis),
                                if (recordText(data['ownerName']).isNotEmpty)
                                  Text(recordText(data['ownerName']),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis),
                                const SizedBox(height: 6),
                                Text(
                                    data['recordType'] == 'soap'
                                        ? 'SOAP medical record'
                                        : 'Previous visit',
                                    style: TextStyle(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary)),
                              ]),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => MedicalRecordView(
                                          recordId: doc.id,
                                          visit: {
                                            ...data,
                                            if (recordText(data['patientName'])
                                                    .isEmpty &&
                                                name.isNotEmpty)
                                              'patientName': name,
                                          }))),
                        ));
                  },
                );
              },
            )),
            if (pages > 1)
              SafeArea(
                  top: false,
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          IconButton(
                              tooltip: 'Previous page',
                              onPressed: page > 0
                                  ? () => setState(() => _page = page - 1)
                                  : null,
                              icon: const Icon(Icons.chevron_left)),
                          Flexible(
                              child: Text('Page ${page + 1} of $pages',
                                  textAlign: TextAlign.center)),
                          IconButton(
                              tooltip: 'Next page',
                              onPressed: page + 1 < pages
                                  ? () => setState(() => _page = page + 1)
                                  : null,
                              icon: const Icon(Icons.chevron_right)),
                        ]),
                  )),
          ]);
        },
      );
}
