import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../utils/google_auth.dart';

class AdminHomeScreen extends StatefulWidget {
  static const route = '/admin';
  const AdminHomeScreen({super.key});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _clinicWatcher;
  Map<String, String> _clinicNames = const {};

  final _customerSearch = TextEditingController();
  final _petSearch = TextEditingController();
  final _staffSearch = TextEditingController();
  final _clinicSearch = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 4, vsync: this)..addListener(() => setState(() {}));
    _clinicWatcher = FirebaseFirestore.instance.collection('clinics').snapshots().listen(
      (snap) {
        if (!mounted) return;
        final next = <String, String>{};
        for (final doc in snap.docs) {
          final name = (doc.data()['name'] as String?)?.trim();
          next[doc.id] = (name == null || name.isEmpty) ? doc.id : name;
        }
        setState(() => _clinicNames = next);
      },
    );
  }

  @override
  void dispose() {
    _clinicWatcher?.cancel();
    _tab.dispose();
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
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
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
    String? selection = current;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Assign clinic'),
        content: DropdownButtonFormField<String?>(
          value: selection,
          items: [
            const DropdownMenuItem<String?>(value: null, child: Text('Unassigned')),
            ..._clinicNames.entries
                .map((e) => DropdownMenuItem<String?>(value: e.key, child: Text(e.value))),
          ],
          onChanged: (v) => selection = v,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _updateUserClinic(uid, selection);
              messenger.showSnackBar(const SnackBar(content: Text('Clinic saved.')));
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

  Future<void> _openClinicEditor({DocumentSnapshot<Map<String, dynamic>>? clinic}) async {
    final messenger = ScaffoldMessenger.of(context);
    final data = clinic?.data();
    final nameCtrl = TextEditingController(text: (data?['name'] as String?) ?? '');
    final addressCtrl = TextEditingController(text: (data?['address'] as String?) ?? '');
    final phoneCtrl = TextEditingController(text: (data?['phone'] as String?) ?? '');
    final emailCtrl = TextEditingController(text: (data?['email'] as String?) ?? '');
    final hoursCtrl = TextEditingController(text: (data?['hours'] as String?) ?? '');
    bool active = (data?['active'] as bool?) ?? true;
    bool busy = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          left: 20,
          right: 20,
          top: 24,
        ),
        child: StatefulBuilder(
          builder: (ctx, setLocal) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                clinic == null ? 'Register clinic' : 'Edit clinic',
                style: Theme.of(ctx).textTheme.titleLarge,
              ),
              const SizedBox(height: 14),
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Clinic name'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: addressCtrl,
                decoration: const InputDecoration(labelText: 'Address'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: phoneCtrl,
                decoration: const InputDecoration(labelText: 'Phone'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: emailCtrl,
                decoration: const InputDecoration(labelText: 'Email'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: hoursCtrl,
                decoration: const InputDecoration(labelText: 'Operating hours'),
              ),
              SwitchListTile.adaptive(
                value: active,
                contentPadding: EdgeInsets.zero,
                title: const Text('Clinic is active'),
                onChanged: (v) => setLocal(() => active = v),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: busy
                      ? null
                      : () async {
                          if (nameCtrl.text.trim().isEmpty) {
                            messenger.showSnackBar(
                              const SnackBar(content: Text('Clinic name is required.')),
                            );
                            return;
                          }
                          setLocal(() => busy = true);
                          final ref = FirebaseFirestore.instance.collection('clinics');
                          final id = clinic?.id ?? ref.doc().id;
                          final payload = <String, dynamic>{
                            'name': nameCtrl.text.trim(),
                            'address': addressCtrl.text.trim(),
                            'phone': phoneCtrl.text.trim(),
                            'email': emailCtrl.text.trim(),
                            'hours': hoursCtrl.text.trim(),
                            'active': active,
                            'updatedAt': FieldValue.serverTimestamp(),
                          };
                          if (clinic == null) {
                            payload['createdAt'] = FieldValue.serverTimestamp();
                          }
                          await ref.doc(id).set(payload, SetOptions(merge: true));
                          if (!mounted) return;
                          Navigator.pop(ctx);
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text(clinic == null ? 'Clinic created.' : 'Clinic updated.'),
                            ),
                          );
                        },
                  icon: busy
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.save),
                  label: Text(clinic == null ? 'Create clinic' : 'Save changes'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Administrator Console'),
        actions: [
          IconButton(icon: const Icon(Icons.logout), tooltip: 'Sign out', onPressed: _signOut),
        ],
        bottom: TabBar(
          controller: _tab,
          isScrollable: true,
          tabs: const [
            Tab(icon: Icon(Icons.people_alt_outlined), text: 'Customers'),
            Tab(icon: Icon(Icons.pets_outlined), text: 'Pets'),
            Tab(icon: Icon(Icons.badge_outlined), text: 'Staff & Vets'),
            Tab(icon: Icon(Icons.local_hospital_outlined), text: 'Clinics'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          _buildCustomersTab(),
          _buildPetsTab(),
          _buildStaffTab(),
          _buildClinicsTab(),
        ],
      ),
      floatingActionButton: _tab.index == 3
          ? FloatingActionButton.extended(
              onPressed: () => _openClinicEditor(),
              icon: const Icon(Icons.add_business),
              label: const Text('Register clinic'),
            )
          : null,
    );
  }

  Widget _buildCustomersTab() {
    final query = FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'customer');

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12.0),
          child: TextField(
            controller: _customerSearch,
            decoration: InputDecoration(
              hintText: 'Search customers',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _customerSearch.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () => setState(() => _customerSearch.clear()),
                    ),
            ),
            onChanged: (_) => setState(() {}),
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: query.snapshots(),
            builder: (ctx, snap) {
              if (snap.hasError) {
                return Center(
                  child: Text('Failed to load customers: ${snap.error}'),
                );
              }
              if (!snap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final q = _customerSearch.text.trim().toLowerCase();
              final docs = snap.data!.docs.where((doc) {
                if (q.isEmpty) return true;
                final data = doc.data();
                final name = ((data['displayName'] as String?) ?? '').toLowerCase();
                final email = ((data['email'] as String?) ?? '').toLowerCase();
                return name.contains(q) || email.contains(q);
              }).toList()
                ..sort((a, b) {
                  final dataA = a.data();
                  final dataB = b.data();
                  final labelA = ((dataA['displayName'] as String?) ?? (dataA['email'] as String?) ?? a.id)
                      .toLowerCase();
                  final labelB = ((dataB['displayName'] as String?) ?? (dataB['email'] as String?) ?? b.id)
                      .toLowerCase();
                  return labelA.compareTo(labelB);
                });
              if (docs.isEmpty) {
                return const Center(child: Text('No customers matched.'));
              }
              return ListView.separated(
                itemCount: docs.length,
                separatorBuilder: (_, __) => const Divider(height: 0),
                itemBuilder: (ctx, i) {
                  final doc = docs[i];
                  final data = doc.data();
                  final label = (data['displayName'] as String?)?.trim();
                  final email = (data['email'] as String?) ?? doc.id;
                  final clinicId = data['clinicId'] as String?;
                  final clinicName = clinicId == null
                      ? 'Unassigned'
                      : _clinicNames[clinicId] ?? clinicId;
                  final displayLabel = (label?.isNotEmpty == true ? label! : email);
                  return ListTile(
                    leading: CircleAvatar(child: Text(displayLabel[0].toUpperCase())),
                    title: Text(displayLabel),
                    subtitle: Text('Clinic: $clinicName'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit),
                          tooltip: 'Assign clinic',
                          onPressed: () => _assignClinicDialog(doc.id, current: clinicId),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline),
                          tooltip: 'Delete customer',
                          onPressed: () => _confirmDeleteUser(doc.id, label: displayLabel),
                        ),
                      ],
                    ),
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
    final query = FirebaseFirestore.instance.collection('patients').orderBy('name');

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12.0),
          child: TextField(
            controller: _petSearch,
            decoration: InputDecoration(
              hintText: 'Search pets',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _petSearch.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () => setState(() => _petSearch.clear()),
                    ),
            ),
            onChanged: (_) => setState(() {}),
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: query.snapshots(),
            builder: (ctx, snap) {
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
                return const Center(child: Text('No pets found.'));
              }
              return ListView.separated(
                itemCount: docs.length,
                separatorBuilder: (_, __) => const Divider(height: 0),
                itemBuilder: (ctx, i) {
                  final doc = docs[i];
                  final data = doc.data();
                  final clinicId = data['clinicId'] as String?;
                  final clinicName = clinicId == null
                      ? 'No clinic'
                      : _clinicNames[clinicId] ?? clinicId;
                  return ListTile(
                    title: Text((data['name'] as String?) ?? 'Unnamed pet'),
                    subtitle: Text(
                      '${(data['species'] as String?) ?? 'Unknown species'} · Clinic: $clinicName',
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => _confirmDeletePet(doc.id),
                    ),
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
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Theme.of(ctx).colorScheme.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await FirebaseFirestore.instance.collection('patients').doc(id).delete();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pet deleted.')));
  }

  Future<void> _confirmDeleteUser(String uid, {required String label}) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete account?'),
        content: Text('Remove "$label" permanently?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
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
    final query = FirebaseFirestore.instance
        .collection('users')
        .where('role', whereIn: ['staff', 'vet', 'admin'])
        .orderBy('displayName');

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12.0),
          child: TextField(
            controller: _staffSearch,
            decoration: InputDecoration(
              hintText: 'Search staff / vets',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _staffSearch.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () => setState(() => _staffSearch.clear()),
                    ),
            ),
            onChanged: (_) => setState(() {}),
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: query.snapshots(),
            builder: (ctx, snap) {
              if (!snap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final q = _staffSearch.text.trim().toLowerCase();
              final docs = snap.data!.docs.where((doc) {
                if (q.isEmpty) return true;
                final data = doc.data();
                final name = ((data['displayName'] as String?) ?? '').toLowerCase();
                final email = ((data['email'] as String?) ?? '').toLowerCase();
                return name.contains(q) || email.contains(q);
              }).toList();

              if (docs.isEmpty) {
                return const Center(child: Text('No staff accounts.'));
              }

              return ListView.separated(
                itemCount: docs.length,
                separatorBuilder: (_, __) => const Divider(height: 0),
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
                  final displayLabel = label?.isNotEmpty == true ? label! : email;
                  return ListTile(
                    title: Text(displayLabel),
                    subtitle: Text('Role: ${role.toUpperCase()} · Clinic: $clinicName'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Switch.adaptive(
                          value: isAdmin,
                          onChanged: (v) {
                            _toggleAdmin(doc.id, v).then((_) {
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                      v ? 'Admin access granted.' : 'Admin access removed.'),
                                ),
                              );
                            });
                          },
                        ),
                        PopupMenuButton<String>(
                          onSelected: (value) {
                            if (value == 'assign') {
                              _assignClinicDialog(doc.id, current: clinicId);
                            } else {
                              _changeRole(doc.id, value).then((_) {
                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                      content:
                                          Text('Role updated to ${value.toUpperCase()}')),
                                );
                              });
                            }
                          },
                          itemBuilder: (ctx) => const [
                            PopupMenuItem(value: 'assign', child: Text('Assign clinic')),
                            PopupMenuItem(value: 'staff', child: Text('Set role: Staff')),
                            PopupMenuItem(value: 'vet', child: Text('Set role: Vet')),
                            PopupMenuItem(value: 'admin', child: Text('Set role: Admin')),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline),
                          tooltip: 'Delete account',
                          onPressed: () =>
                              _confirmDeleteUser(doc.id, label: displayLabel),
                        ),
                      ],
                    ),
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
    final query = FirebaseFirestore.instance.collection('clinics').orderBy('name');

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12.0),
          child: TextField(
            controller: _clinicSearch,
            decoration: InputDecoration(
              hintText: 'Search clinics',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _clinicSearch.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () => setState(() => _clinicSearch.clear()),
                    ),
            ),
            onChanged: (_) => setState(() {}),
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: query.snapshots(),
            builder: (ctx, snap) {
              if (!snap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final q = _clinicSearch.text.trim().toLowerCase();
              final docs = snap.data!.docs.where((doc) {
                if (q.isEmpty) return true;
                final data = doc.data();
                final name = ((data['name'] as String?) ?? '').toLowerCase();
                final address = ((data['address'] as String?) ?? '').toLowerCase();
                return name.contains(q) || address.contains(q);
              }).toList();

              if (docs.isEmpty) {
                return const Center(child: Text('No clinics registered.'));
              }

              return ListView.separated(
                itemCount: docs.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                padding: const EdgeInsets.all(16),
                itemBuilder: (ctx, i) {
                  final doc = docs[i];
                  final data = doc.data();
                  final active = data['active'] == true;
                  return Card(
                    child: ListTile(
                      title: Text((data['name'] as String?) ?? 'Clinic'),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if ((data['address'] as String?)?.isNotEmpty == true)
                            Text(data['address'] as String),
                          if ((data['phone'] as String?)?.isNotEmpty == true)
                            Text('Phone: ${data['phone']}'),
                          if ((data['email'] as String?)?.isNotEmpty == true)
                            Text('Email: ${data['email']}'),
                        ],
                      ),
                      trailing: PopupMenuButton<String>(
                        onSelected: (value) {
                          if (value == 'edit') {
                            _openClinicEditor(clinic: doc);
                          } else if (value == 'toggle') {
                            _toggleClinicActive(doc.id, !active);
                          } else if (value == 'delete') {
                            _confirmDeleteClinic(doc.id,
                                name: (data['name'] as String?) ?? doc.id);
                          }
                        },
                        itemBuilder: (ctx) => [
                          const PopupMenuItem(value: 'edit', child: Text('Edit')),
                          PopupMenuItem(
                            value: 'toggle',
                            child: Text(active ? 'Mark inactive' : 'Activate'),
                          ),
                          const PopupMenuItem(value: 'delete', child: Text('Delete')),
                        ],
                      ),
                      leading: Icon(
                        active ? Icons.verified : Icons.pause_circle_outline,
                        color: active
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.outline,
                      ),
                    ),
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
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
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


