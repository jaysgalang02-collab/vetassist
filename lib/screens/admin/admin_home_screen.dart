import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../utils/google_auth.dart';
import '../../utils/account_access.dart';
import 'admin_workspace.dart';
import 'admin_clinic_editor.dart';
import 'evaluation_settings_screen.dart';

class AdminHomeScreen extends StatefulWidget {
  static const route = '/admin';
  const AdminHomeScreen({super.key});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  int _index = 0;
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _usersStream;
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _petsStream;
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _clinicsStream;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _clinicWatcher;
  Map<String, String> _clinicNames = const {};

  final _customerSearch = TextEditingController();
  final _petSearch = TextEditingController();
  final _staffSearch = TextEditingController();
  final _clinicSearch = TextEditingController();

  @override
  void initState() {
    super.initState();
    _usersStream = FirebaseFirestore.instance.collection('users').snapshots();
    _petsStream = FirebaseFirestore.instance.collection('patients').snapshots();
    _clinicsStream =
        FirebaseFirestore.instance.collection('clinics').snapshots();
    _clinicWatcher = _clinicsStream.listen(
      (snap) {
        if (!mounted) return;
        final next = <String, String>{};
        for (final doc in snap.docs) {
          final name = (doc.data()['name'] as String?)?.trim();
          next[doc.id] = (name == null || name.isEmpty) ? doc.id : name;
        }
        setState(() => _clinicNames = next);
      },
      onError: (Object error) {},
    );
  }

  @override
  void dispose() {
    _clinicWatcher?.cancel();

    _customerSearch.dispose();
    _petSearch.dispose();
    _staffSearch.dispose();
    _clinicSearch.dispose();
    super.dispose();
  }

  Future<void> _signOut() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text('You will be returned to the portal picker.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await signOutGoogleAndFirebase();
    } catch (_) {
      await FirebaseAuth.instance.signOut();
    }
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil('/auth', (_) => false);
  }

  Future<void> _assignClinicDialog(String uid, {String? current}) async {
    final messenger = ScaffoldMessenger.of(context);
    String? selection = _clinicNames.containsKey(current) ? current : null;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Assign clinic'),
        content: DropdownButtonFormField<String?>(
          isExpanded: true,
          value: selection,
          items: [
            const DropdownMenuItem<String?>(
                value: null, child: Text('Unassigned')),
            ..._clinicNames.entries.map((e) =>
                DropdownMenuItem<String?>(value: e.key, child: Text(e.value))),
          ],
          onChanged: (v) => selection = v,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _updateUserClinic(uid, selection);
              messenger
                  .showSnackBar(const SnackBar(content: Text('Clinic saved.')));
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _updateUserClinic(String uid, String? clinicId) {
    final payload = <String, dynamic>{
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (clinicId == null || clinicId.isEmpty) {
      payload['clinicId'] = FieldValue.delete();
    } else {
      payload['clinicId'] = clinicId;
    }
    return FirebaseFirestore.instance.collection('users').doc(uid).set(
          payload,
          SetOptions(merge: true),
        );
  }

  Future<void> _toggleAdmin(String uid, bool value) {
    return FirebaseFirestore.instance.collection('users').doc(uid).update({
      'adminusertype': value,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _changeRole(String uid, String role) {
    return FirebaseFirestore.instance.collection('users').doc(uid).update({
      'role': role,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _openClinicEditor(
      {DocumentSnapshot<Map<String, dynamic>>? clinic}) async {
    final messenger = ScaffoldMessenger.of(context);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => FractionallySizedBox(
          heightFactor: 0.92,
          child: AdminClinicEditor(
              initial: clinic?.data(),
              onSave: (data) async {
                final ref = FirebaseFirestore.instance.collection('clinics');
                await ref.doc(clinic?.id ?? ref.doc().id).set({
                  ...data,
                  'updatedAt': FieldValue.serverTimestamp(),
                  if (clinic == null) 'createdAt': FieldValue.serverTimestamp(),
                }, SetOptions(merge: true));
                messenger.showSnackBar(SnackBar(
                    content: Text(clinic == null
                        ? 'Clinic created.'
                        : 'Clinic updated.')));
              })),
    );
  }

  @override
  Widget build(BuildContext context) => AdminWorkspace(
        index: _index,
        onSelect: (index) {
          FocusManager.instance.primaryFocus?.unfocus();
          setState(() => _index = index);
        },
        onSignOut: _signOut,
        onSettings: () => Navigator.of(context).push(MaterialPageRoute<void>(
            builder: (_) => const EvaluationSettingsScreen())),
        onCreateClinic: () => _openClinicEditor(),
        pages: [
          _buildOverview(),
          _buildCustomersTab(),
          _buildPetsTab(),
          _buildStaffTab(),
          _buildClinicsTab()
        ],
      );

  Widget _buildOverview() => StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _usersStream,
        builder: (context, users) =>
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _petsStream,
          builder: (context, pets) =>
              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _clinicsStream,
            builder: (context, clinics) {
              final accounts = users.data?.docs;
              final network = clinics.data?.docs;
              final user = FirebaseAuth.instance.currentUser;
              final display = user?.displayName?.trim();
              return AdminOverview(
                totals: [
                  users.hasError
                      ? null
                      : accounts
                          ?.where((d) => accountRole(d.data()) == 'customer')
                          .length,
                  pets.hasError ? null : pets.data?.docs.length,
                  users.hasError
                      ? null
                      : accounts?.where((d) => hasStaffAccess(d.data())).length,
                  clinics.hasError ? null : network?.length,
                ],
                clinics: clinics.hasError
                    ? []
                    : (network
                            ?.map((d) =>
                                (d.data()['name'] as String?) ??
                                'Unnamed clinic')
                            .toList() ??
                        [])
                  ..sort(),
                activeClinics: clinics.hasError
                    ? null
                    : network?.where((d) => d.data()['active'] == true).length,
                name: display?.isNotEmpty == true
                    ? display!.split(' ').first
                    : 'Admin',
                hasError: users.hasError || pets.hasError || clinics.hasError,
                onSelect: (index) => setState(() => _index = index),
                onCreateClinic: () => _openClinicEditor(),
              );
            },
          ),
        ),
      );

  Widget _directorySearch(TextEditingController controller, String title,
          String subtitle, String hint) =>
      Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 18),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (MediaQuery.viewInsetsOf(context).bottom == 0) ...[
              Text(title, style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 6),
              Text(subtitle,
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant)),
              const SizedBox(height: 20),
            ],
            TextField(
                controller: controller,
                decoration: InputDecoration(
                    hintText: hint,
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: controller.text.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Clear search',
                            icon: const Icon(Icons.close_rounded),
                            onPressed: () =>
                                setState(() => controller.clear()))),
                onChanged: (_) => setState(() {})),
          ]));
  Widget _buildCustomersTab() {
    return Column(
      children: [
        _directorySearch(_customerSearch, 'Customers',
            'People connected to your care network.', 'Search name or email'),
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _usersStream,
            builder: (ctx, snap) {
              if (snap.hasError) {
                return const AdminState(
                    title: 'Unable to load records',
                    message: 'Check your connection and account permissions.',
                    error: true);
              }
              if (!snap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final q = _customerSearch.text.trim().toLowerCase();
              final docs = snap.data!.docs.where((doc) {
                if (accountRole(doc.data()) != 'customer') return false;
                if (q.isEmpty) return true;
                final data = doc.data();
                final name =
                    ((data['displayName'] as String?) ?? '').toLowerCase();
                final email = ((data['email'] as String?) ?? '').toLowerCase();
                return name.contains(q) || email.contains(q);
              }).toList()
                ..sort((a, b) {
                  final dataA = a.data();
                  final dataB = b.data();
                  final labelA = ((dataA['displayName'] as String?) ??
                          (dataA['email'] as String?) ??
                          a.id)
                      .toLowerCase();
                  final labelB = ((dataB['displayName'] as String?) ??
                          (dataB['email'] as String?) ??
                          b.id)
                      .toLowerCase();
                  return labelA.compareTo(labelB);
                });
              if (docs.isEmpty) {
                return const AdminState(
                    title: 'No customers found',
                    message:
                        'Try another name or email. Registered customers will appear here.');
              }
              return ListView.separated(
                itemCount: docs.length,
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 96),
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (ctx, i) {
                  final doc = docs[i];
                  final data = doc.data();
                  final label = (data['displayName'] as String?)?.trim();
                  final email = (data['email'] as String?) ?? doc.id;
                  final clinicId = data['clinicId'] as String?;
                  final clinicName = clinicId == null
                      ? 'Unassigned'
                      : _clinicNames[clinicId] ?? clinicId;
                  final displayLabel =
                      (label?.isNotEmpty == true ? label! : email);
                  return AdminRecordCard(
                    title: displayLabel,
                    subtitle: '$email\nClinic: $clinicName',
                    icon: Icons.person_outline_rounded,
                    badge: AdminBadge(
                        label: clinicId == null ? 'Unassigned' : 'Connected',
                        muted: clinicId == null),
                    actions: Row(mainAxisSize: MainAxisSize.min, children: [
                      TextButton.icon(
                          icon: const Icon(Icons.edit_outlined, size: 18),
                          label: const Text('Assign clinic'),
                          onPressed: () =>
                              _assignClinicDialog(doc.id, current: clinicId)),
                      IconButton(
                          icon: const Icon(Icons.delete_outline),
                          tooltip: 'Delete customer',
                          onPressed: () =>
                              _confirmDeleteUser(doc.id, label: displayLabel)),
                    ]),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPetsTab() {
    return Column(
      children: [
        _directorySearch(_petSearch, 'Pet directory',
            'Patient records across every clinic.', 'Search pet name or breed'),
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _petsStream,
            builder: (ctx, snap) {
              if (snap.hasError) {
                return const AdminState(
                    title: 'Unable to load records',
                    message: 'Check your connection and account permissions.',
                    error: true);
              }
              if (!snap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final q = _petSearch.text.trim().toLowerCase();
              final docs = snap.data!.docs.where((doc) {
                if (q.isEmpty) return true;
                final data = doc.data();
                final name = ((data['name'] as String?) ?? '').toLowerCase();
                final breed = ((data['breed'] as String?) ?? '').toLowerCase();
                return name.contains(q) || breed.contains(q);
              }).toList();
              if (docs.isEmpty) {
                return const AdminState(
                    title: 'No pets found',
                    message:
                        'Try another search. Clinic patient records will appear here.');
              }
              return ListView.separated(
                itemCount: docs.length,
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 96),
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (ctx, i) {
                  final doc = docs[i];
                  final data = doc.data();
                  final clinicId = data['clinicId'] as String?;
                  final clinicName = clinicId == null
                      ? 'No clinic'
                      : _clinicNames[clinicId] ?? clinicId;
                  return AdminRecordCard(
                    title: (data['name'] as String?) ?? 'Unnamed pet',
                    subtitle:
                        '${data['species'] ?? 'Unknown species'} · ${data['breed'] ?? 'Breed not recorded'}\nClinic: $clinicName',
                    icon: Icons.pets_outlined,
                    actions: IconButton(
                        icon: const Icon(Icons.delete_outline),
                        tooltip: 'Delete pet record',
                        onPressed: () => _confirmDeletePet(doc.id)),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _confirmDeletePet(String id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete pet record?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(ctx).colorScheme.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await FirebaseFirestore.instance.collection('patients').doc(id).delete();
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Pet deleted.')));
  }

  Future<void> _confirmDeleteUser(String uid, {required String label}) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete account?'),
        content: Text('Remove "$label" permanently?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(ctx).colorScheme.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await FirebaseFirestore.instance.collection('users').doc(uid).delete();
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Account deleted.')));
  }

  Widget _buildStaffTab() {
    return Column(
      children: [
        _directorySearch(
            _staffSearch,
            'Your team',
            'Manage roles, access, and clinic assignments.',
            'Search name or email'),
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _usersStream,
            builder: (ctx, snap) {
              if (snap.hasError) {
                return const AdminState(
                    title: 'Unable to load records',
                    message: 'Check your connection and account permissions.',
                    error: true);
              }
              if (!snap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final q = _staffSearch.text.trim().toLowerCase();
              final docs = snap.data!.docs.where((doc) {
                if (!hasStaffAccess(doc.data())) return false;
                if (q.isEmpty) return true;
                final data = doc.data();
                final name =
                    ((data['displayName'] as String?) ?? '').toLowerCase();
                final email = ((data['email'] as String?) ?? '').toLowerCase();
                return name.contains(q) || email.contains(q);
              }).toList();

              if (docs.isEmpty) {
                return const AdminState(
                    title: 'No team members found',
                    message:
                        'Try another name or email. Staff and veterinarians will appear here.');
              }

              return ListView.separated(
                itemCount: docs.length,
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 96),
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (ctx, i) {
                  final doc = docs[i];
                  final data = doc.data();
                  final label = (data['displayName'] as String?)?.trim();
                  final email = (data['email'] as String?) ?? doc.id;
                  final role = (data['role'] as String?) ?? 'staff';
                  final clinicId = data['clinicId'] as String?;
                  final clinicName = clinicId == null
                      ? 'No clinic'
                      : _clinicNames[clinicId] ?? clinicId;
                  final isAdmin = data['adminusertype'] == true;
                  final displayLabel =
                      label?.isNotEmpty == true ? label! : email;
                  return AdminRecordCard(
                    title: displayLabel,
                    subtitle: '$email\nClinic: $clinicName',
                    icon: Icons.badge_outlined,
                    badge: AdminBadge(label: role.toUpperCase()),
                    actions: Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          const Text('Admin flag',
                              style: TextStyle(fontSize: 12)),
                          Switch.adaptive(
                              value: isAdmin,
                              onChanged: (v) async {
                                await _toggleAdmin(doc.id, v);
                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                    content: Text(v
                                        ? 'Admin flag enabled.'
                                        : 'Admin flag disabled. Role-based access still applies.')));
                              }),
                          PopupMenuButton<String>(
                              tooltip: 'Manage team member',
                              onSelected: (value) {
                                if (value == 'assign') {
                                  _assignClinicDialog(doc.id,
                                      current: clinicId);
                                } else {
                                  _changeRole(doc.id, value);
                                }
                              },
                              itemBuilder: (ctx) => const [
                                    PopupMenuItem(
                                        value: 'assign',
                                        child: Text('Assign clinic')),
                                    PopupMenuItem(
                                        value: 'staff',
                                        child: Text('Set role: Staff')),
                                    PopupMenuItem(
                                        value: 'vet',
                                        child: Text('Set role: Vet')),
                                    PopupMenuItem(
                                        value: 'admin',
                                        child: Text('Set role: Admin')),
                                  ]),
                          IconButton(
                              icon: const Icon(Icons.delete_outline),
                              tooltip: 'Delete account',
                              onPressed: () => _confirmDeleteUser(doc.id,
                                  label: displayLabel)),
                        ]),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildClinicsTab() {
    return Column(
      children: [
        _directorySearch(
            _clinicSearch,
            'Clinic network',
            'Keep your clinics connected and up to date.',
            'Search name or address'),
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _clinicsStream,
            builder: (ctx, snap) {
              if (snap.hasError) {
                return const AdminState(
                    title: 'Unable to load records',
                    message: 'Check your connection and account permissions.',
                    error: true);
              }
              if (!snap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final q = _clinicSearch.text.trim().toLowerCase();
              final docs = snap.data!.docs.where((doc) {
                if (q.isEmpty) return true;
                final data = doc.data();
                final name = ((data['name'] as String?) ?? '').toLowerCase();
                final address =
                    ((data['address'] as String?) ?? '').toLowerCase();
                return name.contains(q) || address.contains(q);
              }).toList();

              if (docs.isEmpty) {
                return const AdminState(
                    title: 'No clinics found',
                    message: 'Try another search or register a new clinic.');
              }

              return ListView.separated(
                itemCount: docs.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 96),
                itemBuilder: (ctx, i) {
                  final doc = docs[i];
                  final data = doc.data();
                  final active = data['active'] == true;
                  return AdminRecordCard(
                    title: (data['name'] as String?) ?? 'Clinic',
                    subtitle: [
                      if ((data['address'] as String?)?.isNotEmpty == true)
                        data['address'] as String,
                      if ((data['phone'] as String?)?.isNotEmpty == true)
                        'Phone: ${data['phone']}',
                      if ((data['email'] as String?)?.isNotEmpty == true)
                        data['email'] as String,
                      if ((data['hours'] as String?)?.isNotEmpty == true)
                        'Hours: ${data['hours']}',
                    ].join('\n'),
                    icon: Icons.local_hospital_outlined,
                    badge: AdminBadge(
                        label: active ? 'Active' : 'Inactive', muted: !active),
                    actions: PopupMenuButton<String>(
                        tooltip: 'Manage clinic',
                        onSelected: (value) {
                          if (value == 'edit') {
                            _openClinicEditor(clinic: doc);
                          } else if (value == 'toggle') {
                            _toggleClinicActive(doc.id, !active);
                          } else {
                            _confirmDeleteClinic(doc.id,
                                name: (data['name'] as String?) ?? doc.id);
                          }
                        },
                        itemBuilder: (ctx) => [
                              const PopupMenuItem(
                                  value: 'edit', child: Text('Edit clinic')),
                              PopupMenuItem(
                                  value: 'toggle',
                                  child: Text(
                                      active ? 'Mark inactive' : 'Activate')),
                              const PopupMenuItem(
                                  value: 'delete',
                                  child: Text('Delete clinic')),
                            ]),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _toggleClinicActive(String id, bool value) {
    return FirebaseFirestore.instance.collection('clinics').doc(id).update({
      'active': value,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _confirmDeleteClinic(String id, {required String name}) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete clinic?'),
        content: Text('Clinic "$name" and its record will be removed.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(ctx).colorScheme.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await FirebaseFirestore.instance.collection('clinics').doc(id).delete();
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Clinic deleted.')));
  }
}
