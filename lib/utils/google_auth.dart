import 'account_access.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

const String kWebClientId =
    '1066739816321-nu6qmv825q1bnj25e8smprebsqp9ql02.apps.googleusercontent.com';

final GoogleSignIn _googleSignIn = GoogleSignIn(
  serverClientId: kWebClientId,
  scopes: <String>['email'],
);

Future<UserCredential?> signInWithGoogleEnforcingRole({
  required String requiredRole,
  required bool createIfMissing,
  String? clinicCode,
}) async {
  final GoogleSignInAccount? gUser = await _googleSignIn.signIn();
  if (gUser == null) return null;

  final gAuth = await gUser.authentication;

  final credential = GoogleAuthProvider.credential(
    idToken: gAuth.idToken,
    accessToken: gAuth.accessToken,
  );
  final userCred = await FirebaseAuth.instance.signInWithCredential(credential);
  final user = userCred.user!;
  final uid = user.uid;

  final users = FirebaseFirestore.instance.collection('users');
  final doc = await users.doc(uid).get(const GetOptions(source: Source.server));

  final now = FieldValue.serverTimestamp();

  if (!doc.exists) {
    if (requiredRole == 'staff' && !createIfMissing) {
      await _forceSignOut();
      throw FirebaseAuthException(
        code: 'not-staff',
        message:
            'This Google account is not registered as staff. Please contact the clinic admin.',
      );
    }
    if (requiredRole == 'admin') {
      final details = adminAccessDetails(
        projectId: FirebaseFirestore.instance.app.options.projectId,
        uid: uid,
        email: user.email,
        profile: null,
      );
      await _forceSignOut();
      throw FirebaseAuthException(
        code: 'not-admin',
        message: details,
      );
    }

    await users.doc(uid).set({
      'email': user.email,
      'displayName': user.displayName,
      'photoURL': user.photoURL,
      'role': 'customer',
      'provider': 'google',
      if (clinicCode != null) 'clinicCodeUsed': clinicCode,
      'createdAt': now,
      'updatedAt': now,
    });
  } else {
    final data = doc.data() as Map<String, dynamic>;
    final bool isAdminUser = hasAdminAccess(data);
    final bool isStaffish = hasStaffAccess(data);
    if (requiredRole == 'admin' && !isAdminUser) {
      final details = adminAccessDetails(
        projectId: FirebaseFirestore.instance.app.options.projectId,
        uid: uid,
        email: user.email,
        profile: data,
      );
      await _forceSignOut();
      throw FirebaseAuthException(
        code: 'not-admin',
        message: details,
      );
    }
    if (requiredRole == 'staff' && !isStaffish) {
      await _forceSignOut();
      throw FirebaseAuthException(
        code: 'not-staff',
        message:
            'This Google account is not registered as staff. Please use Customer login or contact admin.',
      );
    }

    await users.doc(uid).update({
      if (!(data.containsKey('displayName')) || data['displayName'] == null)
        'displayName': user.displayName,
      if (!(data.containsKey('photoURL')) || data['photoURL'] == null)
        'photoURL': user.photoURL,
      if (!(data.containsKey('email')) || data['email'] == null)
        'email': user.email,
      'updatedAt': now,
    });
  }

  return userCred;
}

Future<void> _forceSignOut() async {
  try {
    await FirebaseAuth.instance.signOut();
  } catch (_) {}
  try {
    await _googleSignIn.disconnect();
  } catch (_) {}
  try {
    await _googleSignIn.signOut();
  } catch (_) {}
}

Future<void> signOutGoogleAndFirebase() => _forceSignOut();
