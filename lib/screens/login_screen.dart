import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/brand_widgets.dart';

import '../utils/toast.dart';
import '../utils/account_access.dart';
import '../utils/google_auth.dart';
import 'create_account_screen.dart';
import 'forgot_password_screen.dart';

import 'user/user.dart';
import 'staff/staff_home_screen.dart';
import 'admin/admin_home_screen.dart';

class CustomerLoginScreen extends StatelessWidget {
  static const route = '/login-customer';
  const CustomerLoginScreen({super.key});
  @override
  Widget build(BuildContext context) => const LoginScreen(portal: 'customer');
}

class StaffLoginScreen extends StatelessWidget {
  static const route = '/login-staff';
  const StaffLoginScreen({super.key});
  @override
  Widget build(BuildContext context) => const LoginScreen(portal: 'staff');
}

class LoginScreen extends StatefulWidget {
  final String portal;
  const LoginScreen({required this.portal, super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final emailCtrl = TextEditingController();
  final pwCtrl = TextEditingController();
  bool showPw = false;
  bool busy = false;

  @override
  void dispose() {
    emailCtrl.dispose();
    pwCtrl.dispose();
    super.dispose();
  }

  Future<void> _routeByRole(User user) async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final data = snap.data() ?? {};
      final role = (data['role'] as String?)?.toLowerCase() ?? 'customer';
      final bool isAdminUser = hasAdminAccess(data);
      final bool isStaffish = isAdminUser || role == 'staff' || role == 'vet';

      if (!mounted) return;
      final Widget dest = isAdminUser
          ? const AdminHomeScreen()
          : (isStaffish ? const StaffHomeScreen() : const UserDashboard());
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => dest),
        (_) => false,
      );
    } catch (_) {
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, '/auth', (_) => false);
    }
  }

  Future<void> _signInEmail() async {
    final email = emailCtrl.text.trim();
    final pw = pwCtrl.text;

    if (email.isEmpty) {
      toast(context, 'Enter email');
      return;
    }
    if (pw.isEmpty) {
      toast(context, 'Enter password');
      return;
    }

    setState(() => busy = true);
    try {
      final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: pw,
      );

      if (widget.portal == 'customer') {
        await _ensureCustomerHasClinic(cred.user!);
      } else if (widget.portal == 'admin') {
        final ok = await _isAdminUser(cred.user!.uid);
        if (!ok) {
          final details = await _adminRejectionDetails(cred.user!);
          await FirebaseAuth.instance.signOut();
          throw FirebaseAuthException(
            code: 'not-admin',
            message: details,
          );
        }
      } else {
        final ok = await _isStaffish(cred.user!.uid);
        if (!ok) {
          final assigned = await _handleStaffInviteFlow(cred.user!);
          if (!assigned) {
            await FirebaseAuth.instance.signOut();
            throw FirebaseAuthException(
              code: 'not-staff',
              message: 'This account is not registered as staff.',
            );
          }
        }
      }

      await _routeByRole(cred.user!);
    } on FirebaseAuthException catch (e) {
      if (mounted) await _showLoginError(e);
    } on FirebaseException catch (e) {
      if (mounted) toast(context, _profileReadError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _signInGoogle() async {
    setState(() => busy = true);
    try {
      final portal = widget.portal;
      final cred = await signInWithGoogleEnforcingRole(
        requiredRole: portal == 'admin' ? 'admin' : portal,
        createIfMissing: portal == 'customer',
      );
      if (cred == null) return;

      if (portal == 'customer') {
        await _ensureCustomerHasClinic(cred.user!);
      } else if (portal == 'admin') {
        final ok = await _isAdminUser(cred.user!.uid);
        if (!ok) {
          final details = await _adminRejectionDetails(cred.user!);
          await FirebaseAuth.instance.signOut();
          throw FirebaseAuthException(
            code: 'not-admin',
            message: details,
          );
        }
      } else {
        final ok = await _isStaffish(cred.user!.uid);
        if (!ok) {
          final assigned = await _handleStaffInviteFlow(cred.user!);
          if (!assigned) {
            await FirebaseAuth.instance.signOut();
            throw FirebaseAuthException(
              code: 'not-staff',
              message: 'This Google account is not registered as staff.',
            );
          }
        }
      }

      await _routeByRole(cred.user!);
    } on FirebaseAuthException catch (e) {
      if (mounted) await _showLoginError(e);
    } on FirebaseException catch (e) {
      if (mounted) toast(context, _profileReadError(e));
    } catch (e) {
      toast(context, 'Google sign-in failed: $e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<Map<String, dynamic>> _accessProfile(String uid) async {
    final snap = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get(const GetOptions(source: Source.server));
    final data = snap.data();
    if (data == null) {
      throw FirebaseAuthException(
        code: 'missing-profile',
        message: 'Account profile not found. Check that users/$uid matches '
            'the UID in Firebase Authentication.',
      );
    }
    return data;
  }

  Future<bool> _isStaffish(String uid) async =>
      hasStaffAccess(await _accessProfile(uid));

  Future<bool> _isAdminUser(String uid) async =>
      hasAdminAccess(await _accessProfile(uid));

  Future<String> _adminRejectionDetails(User user) async => adminAccessDetails(
        projectId: FirebaseFirestore.instance.app.options.projectId,
        uid: user.uid,
        email: user.email,
        profile: await _accessProfile(user.uid),
      );

  Future<void> _showLoginError(FirebaseAuthException e) async {
    if (e.code != 'not-admin' && e.code != 'missing-profile') {
      toast(context, _mapFirebaseCode(e));
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Check administrator account'),
        content: SingleChildScrollView(
          child: SelectableText(e.message ?? 'Administrator access denied.'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  String _providerOf(User user) {
    if (user.providerData.isNotEmpty) {
      final pid = user.providerData.first.providerId;
      if (pid.contains('google')) return 'google';
      if (pid.contains('password')) return 'password';
      return pid;
    }
    return 'unknown';
  }

  Future<void> _ensureCustomerHasClinic(User user) async {
    final users = FirebaseFirestore.instance.collection('users');
    final udoc = await users.doc(user.uid).get();
    final data = udoc.data();

    if (data == null || (data['clinicId'] as String?)?.isEmpty != false) {
      final clinic = await _pickClinic();
      if (clinic == null) {
        throw FirebaseAuthException(
          code: 'operation-cancelled',
          message: 'Please select a clinic to continue.',
        );
      }

      final payload = <String, dynamic>{
        'email': user.email,
        'displayName': user.displayName ?? user.email,
        'photoURL': user.photoURL,
        'provider': _providerOf(user),
        'role': 'customer',
        'clinicId': clinic.id,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (data == null) {
        payload['createdAt'] = FieldValue.serverTimestamp();
      }
      await users.doc(user.uid).set(payload, SetOptions(merge: true));
    }
  }

  Future<bool> _handleStaffInviteFlow(User user) async {
    final code = await _askInviteCode();
    if (code == null || code.trim().isEmpty) return false;

    final codeRef =
        FirebaseFirestore.instance.collection('staff_codes').doc(code.trim());
    final codeSnap = await codeRef.get();

    if (!codeSnap.exists) {
      if (mounted) toast(context, 'Invalid invite code.');
      return false;
    }

    final data = codeSnap.data()!;
    final clinicId = (data['clinicId'] as String?)?.trim();
    final active = (data['active'] as bool?) ?? true;
    final maxUses = (data['maxUses'] as num?)?.toInt();
    final used = (data['uses'] as num?)?.toInt() ?? 0;

    if (!active) {
      if (mounted) toast(context, 'This invite code is inactive.');
      return false;
    }
    if (maxUses != null && used >= maxUses) {
      if (mounted) toast(context, 'This invite code has reached its limit.');
      return false;
    }
    if (clinicId == null || clinicId.isEmpty) {
      if (mounted) toast(context, 'Invite code is misconfigured (no clinic).');
      return false;
    }

    final clinicSnap = await FirebaseFirestore.instance
        .collection('clinics')
        .doc(clinicId)
        .get();
    if (!clinicSnap.exists) {
      if (mounted) toast(context, 'Clinic not found for this code.');
      return false;
    }
    final clinicActive = (clinicSnap.data()?['active'] as bool?) ?? true;
    if (!clinicActive) {
      if (mounted) toast(context, 'Clinic is inactive.');
      return false;
    }

    final usersCol = FirebaseFirestore.instance.collection('users');
    final userDocSnap = await usersCol.doc(user.uid).get();
    final staffPayload = <String, dynamic>{
      'email': user.email,
      'displayName': user.displayName ?? user.email,
      'photoURL': user.photoURL,
      'provider': _providerOf(user),
      'role': 'staff',
      'clinicId': clinicId,
      'clinicCodeUsed': code.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (!userDocSnap.exists) {
      staffPayload['createdAt'] = FieldValue.serverTimestamp();
    }
    await usersCol.doc(user.uid).set(staffPayload, SetOptions(merge: true));

    await codeRef.set({
      'uses': FieldValue.increment(1),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    return true;
  }

  Future<_ClinicRef?> _pickClinic() async {
    return showModalBottomSheet<_ClinicRef>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        final q =
            FirebaseFirestore.instance.collection('clinics').orderBy('name');
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Select a Vet Clinic',
                    style: Theme.of(ctx).textTheme.titleMedium),
                const SizedBox(height: 8),
                Flexible(
                  child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: q.snapshots(),
                    builder: (ctx, snap) {
                      if (!snap.hasData) {
                        return const Padding(
                          padding: EdgeInsets.all(16),
                          child: LinearProgressIndicator(),
                        );
                      }
                      final docs = snap.data!.docs;
                      if (docs.isEmpty) {
                        return const Padding(
                          padding: EdgeInsets.all(24),
                          child: Text('No clinics available.'),
                        );
                      }
                      return ListView.separated(
                        shrinkWrap: true,
                        itemCount: docs.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (_, i) {
                          final d = docs[i].data();
                          final name = (d['name'] as String?)?.trim() ??
                              '(Unnamed clinic)';
                          final active = (d['active'] as bool?) ?? true;
                          return ListTile(
                            leading: Icon(Icons.local_hospital,
                                color:
                                    active ? cs.primary : cs.onSurfaceVariant),
                            title: Text(name),
                            subtitle: active
                                ? null
                                : const Text('Inactive',
                                    style: TextStyle(fontSize: 12)),
                            onTap: () => Navigator.pop(
                                ctx, _ClinicRef(id: docs[i].id, name: name)),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<String?> _askInviteCode() async {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        return AlertDialog(
          title: const Text('Enter Staff / Invite Code'),
          content: TextField(
            controller: ctrl,
            decoration: const InputDecoration(
              hintText: 'e.g., 9ZLAS2',
            ),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
              child: const Text('Continue'),
            ),
          ],
          backgroundColor: cs.surface,
        );
      },
    );
  }

  String _profileReadError(FirebaseException e) {
    if (e.code == 'permission-denied') {
      return 'Cannot read your account profile. Check Firestore rules for users/{uid}.';
    }
    return 'Cannot verify account access (${e.code}). Please try again.';
  }

  String _mapFirebaseCode(FirebaseAuthException e) {
    final code = e.code.toLowerCase();
    if (code == 'not-staff') return e.message ?? 'Not a staff account.';
    if (code == 'not-admin') {
      return e.message ?? 'Not an administrator account.';
    }
    if (code.contains('network')) {
      return 'Network error. Check your internet connection.';
    }
    if (code == 'user-not-found') return 'No account found for that email.';
    if (code == 'wrong-password') return 'Incorrect password.';
    if (code == 'invalid-email') return 'Invalid email address.';
    if (code == 'operation-cancelled') return e.message ?? 'Action cancelled.';
    return e.message ?? 'Authentication failed.';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final portal = widget.portal;
    final bool isStaffPortal = portal == 'staff';
    final bool isAdminPortal = portal == 'admin';

    String _title() {
      if (isAdminPortal) return 'Administrator Login';
      if (isStaffPortal) return 'Staff / Vet Login';
      return 'Customer Login';
    }

    String _heroTitle() {
      if (isAdminPortal) return 'Sign in as Administrator';
      if (isStaffPortal) return 'Your clinic, connected.';
      return 'Welcome back, pet parent.';
    }

    String _heroSubtitle() {
      if (isAdminPortal) {
        return 'Restricted control center for verified VetAssist administrators.';
      }
      return 'Welcome back. Enter your details to continue.';
    }

    String _switchLabel() {
      if (isAdminPortal) return 'Back to customer login';
      return isStaffPortal ? 'Customer login' : 'Staff login';
    }

    VoidCallback _switchAction() {
      if (isAdminPortal || isStaffPortal) {
        return () =>
            Navigator.pushReplacementNamed(context, CustomerLoginScreen.route);
      }
      return () =>
          Navigator.pushReplacementNamed(context, StaffLoginScreen.route);
    }

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        title: Text(_title()),
        actions: [
          if (!isAdminPortal)
            IconButton(
              tooltip: 'Create account',
              onPressed: () => Navigator.pushNamed(
                context,
                CreateAccountScreen.route,
                arguments: portal,
              ),
              icon: const Icon(Icons.person_add_alt_1_rounded),
            ),
        ],
      ),
      body: SafeArea(
        child: ContentFrame(
          maxWidth: 520,
          child: ListView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            children: [
              const Entrance(child: Center(child: BrandLogo(size: 88))),
              const SizedBox(height: 14),
              Column(
                children: [
                  Text(_heroTitle(),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineMedium),
                  const SizedBox(height: 6),
                  Text(_heroSubtitle(),
                      textAlign: TextAlign.center,
                      style:
                          TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
                ],
              ),
              const SizedBox(height: 16),
              Card(
                elevation: 0,
                color: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18)),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      _LabeledField(
                        label: 'Email',
                        child: TextField(
                          controller: emailCtrl,
                          autofillHints: const [AutofillHints.email],
                          autocorrect: false,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                              hintText: 'you@example.com',
                              prefixIcon: Icon(Icons.mail_outline_rounded)),
                        ),
                      ),
                      const SizedBox(height: 10),
                      _LabeledField(
                        label: 'Password',
                        child: TextField(
                          controller: pwCtrl,
                          autofillHints: const [AutofillHints.password],
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) {
                            if (!busy) _signInEmail();
                          },
                          obscureText: !showPw,
                          decoration: InputDecoration(
                            hintText: '••••••••',
                            suffixIcon: IconButton(
                              tooltip:
                                  showPw ? 'Hide password' : 'Show password',
                              onPressed: () => setState(() => showPw = !showPw),
                              icon: Icon(showPw
                                  ? Icons.visibility_off
                                  : Icons.visibility),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: busy ? null : _signInEmail,
                          child: busy
                              ? const SizedBox(
                                  height: 18,
                                  width: 18,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white))
                              : const Text('Sign in'),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(children: const [
                        Expanded(child: Divider()),
                        Flexible(
                          flex: 3,
                          child: Padding(
                            padding: EdgeInsets.symmetric(horizontal: 8.0),
                            child: Text('or continue with',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 12)),
                          ),
                        ),
                        Expanded(child: Divider()),
                      ]),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          icon:
                              const Icon(Icons.g_mobiledata_rounded, size: 22),
                          label: const Text('Google'),
                          onPressed: busy ? null : _signInGoogle,
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () => Navigator.pushNamed(
                              context, ForgotPasswordScreen.route),
                          child: const Text('Forgot password?',
                              style: TextStyle(fontSize: 12)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              if (!isAdminPortal)
                TextButton(
                  onPressed: () => Navigator.pushNamed(
                      context, CreateAccountScreen.route,
                      arguments: portal),
                  child: const Text('New here? Create an account',
                      textAlign: TextAlign.center),
                ),
              Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  const Text('Not this portal?  '),
                  TextButton(
                    onPressed: _switchAction(),
                    child: Text(_switchLabel()),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LabeledField extends StatelessWidget {
  final String label;
  final Widget child;
  const _LabeledField({required this.label, required this.child});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
        const SizedBox(height: 6),
        child,
      ],
    );
  }
}

class _ClinicRef {
  final String id;
  final String name;
  _ClinicRef({required this.id, required this.name});
}
