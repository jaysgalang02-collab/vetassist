import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../utils/account_access.dart';

Uri? googleFormUri(String value) {
  final uri = Uri.tryParse(value.trim());
  if (uri == null ||
      uri.scheme != 'https' ||
      uri.userInfo.isNotEmpty ||
      uri.hasPort ||
      RegExp(r'\s').hasMatch(value.trim())) {
    return null;
  }
  if (uri.host == 'forms.gle' &&
      uri.pathSegments.length == 1 &&
      uri.pathSegments.first.isNotEmpty) {
    return uri;
  }
  if (uri.host == 'docs.google.com' &&
      uri.path.startsWith('/forms/') &&
      uri.pathSegments.length >= 4 &&
      uri.path.endsWith('/viewform')) {
    return uri;
  }
  return null;
}

class EvaluationSettings {
  final String url;
  final bool enabled;
  const EvaluationSettings({this.url = '', this.enabled = false});

  factory EvaluationSettings.fromMap(Map<String, dynamic>? data) =>
      EvaluationSettings(
        url: data?['url'] is String ? (data!['url'] as String).trim() : '',
        enabled: data?['enabled'] == true,
      );

  Uri? get publicUri => enabled ? googleFormUri(url) : null;
}

class EvaluationSettingsService {
  DocumentReference<Map<String, dynamic>> get _document =>
      FirebaseFirestore.instance.collection('app_settings').doc('evaluation');

  Stream<EvaluationSettings> watch() => _document
      .snapshots()
      .map((snapshot) => EvaluationSettings.fromMap(snapshot.data()));

  Future<EvaluationSettings> load() async {
    final snapshot = await _document.get().timeout(const Duration(seconds: 15));
    return EvaluationSettings.fromMap(snapshot.data());
  }

  Future<void> save(EvaluationSettings settings) async {
    if (settings.url.isNotEmpty && googleFormUri(settings.url) == null) {
      throw const FormatException(
          'Enter a valid Google Forms respondent link.');
    }
    if (settings.enabled && settings.url.isEmpty) {
      throw const FormatException('Add a Google Form link before enabling it.');
    }
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw StateError('Sign in as an administrator to save.');
    final profile = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get(const GetOptions(source: Source.server))
        .timeout(const Duration(seconds: 15));
    if (!hasAdminAccess(profile.data() ?? {})) {
      throw StateError('Only administrators can update app settings.');
    }
    await _document.set({
      'url': settings.url.trim(),
      'enabled': settings.enabled,
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': user.uid,
    }, SetOptions(merge: true));
  }
}
