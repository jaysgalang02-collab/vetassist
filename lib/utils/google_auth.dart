import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Your Web OAuth Client ID (…apps.googleusercontent.com)
const String kWebClientId = '1066739816321-nu6qmv825q1bnj25e8smprebsqp9ql02.apps.googleusercontent.com';

final GoogleSignIn _googleSignIn = GoogleSignIn(
  serverClientId: kWebClientId, // critical so idToken is returned on Android
  scopes: <String>['email'],
);

/// Sign in with Google and enforce portal rules.
/// - requiredRole: 'customer', 'staff', or 'admin'
/// - createIfMissing: true -> create a profile if none exists (used for customer)
/// - clinicCode: optional, only relevant if you later allow staff self-onboarding via code
Future<UserCredential?> signInWithGoogleEnforcingRole({
  required String requiredRole,
  required bool createIfMissing,
  String? clinicCode,
}) async {
  // 1) Ask user to pick a Google account
  final GoogleSignInAccount? gUser = await _googleSignIn.signIn();
  if (gUser == null) return null; // user cancelled

  // 2) Tokens
  final gAuth = await gUser.authentication;

  // 3) Firebase sign-in
  final credential = GoogleAuthProvider.credential(
    idToken: gAuth.idToken,
    accessToken: gAuth.accessToken,
  );
  final userCred = await FirebaseAuth.instance.signInWithCredential(credential);
  final user = userCred.user!;
  final uid = user.uid;

  // 4) Check profile
  final users = FirebaseFirestore.instance.collection('users');
  final doc = await users.doc(uid).get();

  final now = FieldValue.serverTimestamp();

  if (!doc.exists) {
    // No profile yet
    if (requiredRole == 'staff' && !createIfMissing) {
      // Staff portal forbids creating a new profile unless you implement invite code flow
      await _forceSignOut();
      throw FirebaseAuthException(
        code: 'not-staff',
        message: 'This Google account is not registered as staff. Please contact the clinic admin.',
      );
    }
    if (requiredRole == 'admin') {
      await _forceSignOut();
      throw FirebaseAuthException(
        code: 'not-admin',
        message: 'This Google account is not authorized as an administrator.',
      );
    }

    // Customer portal: create a customer profile
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

    // If staff self-onboarding with code is something you add later,
    // you can swap 'customer' for 'staff' above after validating the code.
  } else {
    // Profile exists: enforce role-based portals
    bool _adminFlag(dynamic value) {
      if (value is bool) return value;
      if (value is String) return value.toLowerCase() == 'true';
      if (value is num) return value != 0;
      return false;
    }

    final data = doc.data() as Map<String, dynamic>;
    final role = (data['role'] as String?)?.toLowerCase();
    final bool isAdminRole = role == 'admin';
    final bool isAdminUser = isAdminRole || _adminFlag(data['adminusertype']);
    final bool isStaffish = isAdminUser || role == 'staff' || role == 'vet';

    if (requiredRole == 'admin' && !isAdminUser) {
      await _forceSignOut();
      throw FirebaseAuthException(
        code: 'not-admin',
        message: 'This Google account is not authorized as an administrator.',
      );
    }
    if (requiredRole == 'staff' && !isStaffish) {
      await _forceSignOut();
      throw FirebaseAuthException(
        code: 'not-staff',
        message: 'This Google account is not registered as staff. Please use Customer login or contact admin.',
      );
    }

    // Update basic fields if missing and bump timestamp
    await users.doc(uid).update({
      if (!(data.containsKey('displayName')) || data['displayName'] == null) 'displayName': user.displayName,
      if (!(data.containsKey('photoURL'))    || data['photoURL'] == null)    'photoURL': user.photoURL,
      if (!(data.containsKey('email'))       || data['email'] == null)       'email': user.email,
      'updatedAt': now,
    });
  }

  return userCred;
}

Future<void> _forceSignOut() async {
  try { await FirebaseAuth.instance.signOut(); } catch (_) {}
  try { await _googleSignIn.disconnect(); } catch (_) {}
  try { await _googleSignIn.signOut(); } catch (_) {}
}

/// Optional: unified sign-out you can use from your Home screens
Future<void> signOutGoogleAndFirebase() => _forceSignOut();
