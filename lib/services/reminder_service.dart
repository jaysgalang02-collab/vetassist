import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ReminderService {
  static const _collection = 'reminders';

  /// Creates a reminder compliant with your security rules:
  /// - uid == request.auth.uid
  /// - clinicId == myClinicId()
  /// - type in ['vaccine','followup','visit','custom']
  static Future<void> createReminder({
    required String type,
    required String title,
    required DateTime when,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('You must be signed in.');
    }

    // 1) normalize type to allowed lowercase tokens
    final t = _normalizeType(type);

    // 2) fetch clinicId of current user
    final uSnap = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    final clinicId = (uSnap.data() ?? const {})['clinicId'] as String?;
    if (clinicId == null || clinicId.isEmpty) {
      throw Exception('Your account has no clinic assigned.');
    }

    // 3) write
    final now = FieldValue.serverTimestamp();
    await FirebaseFirestore.instance.collection(_collection).add({
      'uid': user.uid,
      'type': t,                                // ✅ allowed token
      'title': title.trim(),
      'clinicId': clinicId,                     // ✅ equals myClinicId() in rules
      'when': Timestamp.fromDate(when),         // optional but useful
      'createdAt': now,
      'updatedAt': now,
    });
  }

  static String _normalizeType(String raw) {
    final v = raw.trim().toLowerCase();
    if (v.startsWith('follow')) return 'followup';
    if (v.startsWith('vacc')) return 'vaccine';
    if (v.startsWith('visit')) return 'visit';
    if (v == 'custom') return 'custom';
    // default safe fallback (still allowed)
    return 'custom';
  }
}
