import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class ClinicPicker extends StatefulWidget {
  final String? initialClinicId;
  const ClinicPicker({super.key, this.initialClinicId});

  @override
  State<ClinicPicker> createState() => _ClinicPickerState();
}

class _ClinicPickerState extends State<ClinicPicker> {
  String? _clinicId;

  @override
  void initState() {
    _clinicId = widget.initialClinicId;
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final q = FirebaseFirestore.instance
        .collection('clinics')
        .where('active', isEqualTo: true)
        .orderBy('name');

    return AlertDialog(
      title: const Text('Choose your vet clinic'),
      content: SizedBox(
        width: 360, height: 360,
        child: StreamBuilder<QuerySnapshot>(
          stream: q.snapshots(),
          builder: (ctx, snap) {
            if (!snap.hasData) return const Center(child: CircularProgressIndicator());
            final docs = snap.data!.docs;
            if (docs.isEmpty) {
              return const Center(child: Text('No clinics yet. Please ask your clinic to register.'));
            }
            return ListView.separated(
              itemCount: docs.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final d = docs[i].data() as Map<String, dynamic>;
                final id = docs[i].id;
                final name = (d['name'] ?? 'Clinic') as String;
                final address = (d['address'] ?? '') as String;
                final selected = _clinicId == id;
                return ListTile(
                  leading: Icon(selected ? Icons.radio_button_checked : Icons.radio_button_off),
                  title: Text(name),
                  subtitle: Text(address),
                  onTap: () => setState(() => _clinicId = id),
                );
              },
            );
          },
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: _clinicId == null ? null : () => Navigator.pop(context, _clinicId),
          child: const Text('Select'),
        ),
      ],
    );
  }
}

/// helper to open picker and return id (or null on cancel)
Future<String?> pickClinic(BuildContext context, {String? initial}) async {
  return showDialog<String>(
    context: context,
    builder: (_) => ClinicPicker(initialClinicId: initial),
  );
}
