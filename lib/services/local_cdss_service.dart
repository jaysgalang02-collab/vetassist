import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';

import 'symptom_engine.dart';

Future<void> _requireCdssRole({required bool firstAidOnly}) async {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) throw StateError('Please sign in again.');
  final profile = await FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .get()
      .timeout(const Duration(seconds: 12));
  final role = (profile.data()?['role'] as String?)?.trim().toLowerCase();
  if (!(firstAidOnly ? role == 'customer' : role == 'staff')) {
    throw StateError(firstAidOnly
        ? 'First Aid guidance is available to customer accounts only.'
        : 'Clinical decision support is available to staff accounts only.');
  }
}

Future<SymptomEngine> loadSymptomEngine() async {
  final data =
      jsonDecode(await rootBundle.loadString('lib/assets/symptom_model.json'))
          as Map<String, dynamic>;
  if (data['datasetKind'] == 'synthetic_demo') {
    throw const FormatException(
        'Synthetic demo models cannot be used for patient decision support.');
  }
  return SymptomEngine(model: data);
}

class LocalPetPhotoService {
  Future<Map<String, dynamic>> analyzePetImage(
      {required File file,
      required String speciesHint,
      bool firstAidOnly = false}) async {
    await _requireCdssRole(firstAidOnly: firstAidOnly);
    if (!await file.exists()) {
      throw StateError('The selected photo is unavailable.');
    }
    return {
      'findings': [
        'Photo attached only. No trained image assessment model is installed; select or describe symptoms.'
      ],
      'inferred_symptoms': <String>[],
      'differentials': <Map<String, dynamic>>[],
      'red_flags': <String>[],
      'suggested_tests': <String>[],
      'triage': 'unknown',
    };
  }
}

class VetChatMessage {
  final String role, text;
  final List<File> images;
  VetChatMessage({required this.role, required this.text, List<File>? images})
      : images = images ?? const [];
}

class LocalVetChatService {
  Future<String> sendChat(
      {required List<VetChatMessage> history,
      required String speciesHint,
      bool firstAidOnly = false}) async {
    await _requireCdssRole(firstAidOnly: firstAidOnly);
    final latest = history.where((m) => m.role == 'user').lastOrNull;
    if (latest == null) return 'Describe your pet\'s current symptoms.';
    final engine = await loadSymptomEngine();
    return engine.reply(latest.text, speciesHint,
        firstAidOnly: firstAidOnly, hasImages: latest.images.isNotEmpty);
  }
}
