import 'package:flutter/material.dart';
import '../../widgets/medical_record_list.dart';

class PetVisitsTab extends StatelessWidget {
  const PetVisitsTab({super.key, required this.patientId});
  final String patientId;

  @override
  Widget build(BuildContext context) => MedicalRecordList(patientId: patientId);
}
