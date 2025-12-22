import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../staff_common.dart';

class ReportsTab extends StatefulWidget {
  final String clinicId;
  const ReportsTab({super.key, required this.clinicId});

  @override
  State<ReportsTab> createState() => _ReportsTabState();
}

class _ReportsTabState extends State<ReportsTab> {
  DateTimeRange _range = DateTimeRange(
    start: DateTime.now().subtract(const Duration(days: 90)),
    end: DateTime.now(),
  );

  Future<Map<String, int>> _loadCounts() async {
    final clinicId = widget.clinicId;

    final patients = await FirebaseFirestore.instance
        .collection('patients')
        .where('clinicId', isEqualTo: clinicId)
        .get();

    final visits = await FirebaseFirestore.instance
        .collection('visits')
        .where('clinicId', isEqualTo: clinicId)
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(_range.start))
        .where('date', isLessThanOrEqualTo: Timestamp.fromDate(_range.end))
        .get();

    final vaccines = await FirebaseFirestore.instance
        .collection('vaccines')
        .where('clinicId', isEqualTo: clinicId)
        .where('dateGiven', isGreaterThanOrEqualTo: Timestamp.fromDate(_range.start))
        .where('dateGiven', isLessThanOrEqualTo: Timestamp.fromDate(_range.end))
        .get();

    final canine = patients.docs.where((d) => d['species'] == 'canine').length;
    final feline = patients.docs.where((d) => d['species'] == 'feline').length;

    return {
      'patients_total': patients.size,
      'patients_canine': canine,
      'patients_feline': feline,
      'visits': visits.size,
      'vaccines': vaccines.size,
    };
  }

  Future<void> _copyCsv() async {
    final clinicId = widget.clinicId;

    final visits = await FirebaseFirestore.instance
        .collection('visits')
        .where('clinicId', isEqualTo: clinicId)
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(_range.start))
        .where('date', isLessThanOrEqualTo: Timestamp.fromDate(_range.end))
        .get();

    final rows = <List<String>>[
      ['visitId', 'patientId', 'ownerUid', 'date', 'diagnosis'],
      ...visits.docs.map((d) {
        final x = d.data();
        return [
          d.id,
          (x['patientId'] ?? '').toString(),
          (x['ownerUid'] ?? '').toString(),
          fmtTs(x['date'] as Timestamp?),
          (x['diagnosis'] ?? '').toString(),
        ];
      }),
    ];
    final csv = toCsv(rows);
    await Clipboard.setData(ClipboardData(text: csv));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Visits CSV copied to clipboard')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Section(
      title: 'Reports & Analytics',
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'Change date range',
            icon: const Icon(Icons.date_range),
            onPressed: () async {
              final picked = await showDateRangePicker(
                context: context,
                firstDate: DateTime(2010),
                lastDate: DateTime(2100),
                initialDateRange: _range,
              );
              if (picked != null) {
                setState(() => _range = picked);
              }
            },
          ),
          IconButton(
            tooltip: 'Copy Visits CSV',
            icon: const Icon(Icons.copy),
            onPressed: _copyCsv,
          ),
        ],
      ),
      child: FutureBuilder<Map<String, int>>(
        future: _loadCounts(),
        builder: (ctx, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final m = snap.data!;
          return Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _MetricCard(label: 'Patients (total)', value: m['patients_total']!),
              _MetricCard(label: 'Canine', value: m['patients_canine']!),
              _MetricCard(label: 'Feline', value: m['patients_feline']!),
              _MetricCard(label: 'Visits', value: m['visits']!),
              _MetricCard(label: 'Vaccines', value: m['vaccines']!),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Text(
                    'Date range: ${_range.start.toLocal().toString().split(".").first} → '
                    '${_range.end.toLocal().toString().split(".").first}',
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String label;
  final int value;
  const _MetricCard({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: SizedBox(
        width: 220,
        height: 90,
        child: Center(
          child: ListTile(
            title: Text(label),
            subtitle: Text(
              '$value',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 24),
            ),
          ),
        ),
      ),
    );
  }
}
