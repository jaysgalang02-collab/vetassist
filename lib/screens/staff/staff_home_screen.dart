import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData; // <-- add this

// tabs
import 'tabs/patients_tab.dart';
import 'tabs/cdss_tab.dart';
import 'tabs/vaccines_reminders_tab.dart';
import 'tabs/visits_tab.dart';
import 'tabs/reports_tab.dart';
import 'tabs/comms_tab.dart';

// sign-out helper you already use elsewhere (falls back if Google not used)
import '../../utils/google_auth.dart';

class StaffHomeScreen extends StatefulWidget {
  static const route = '/staff';
  const StaffHomeScreen({super.key});

  @override
  State<StaffHomeScreen> createState() => _StaffHomeScreenState();
}

class _StaffHomeScreenState extends State<StaffHomeScreen>
    with SingleTickerProviderStateMixin {
  String? _myClinicId;
  String _myRole = 'staff';
  String? _myUid;

  late final TabController _tab;

  bool get _isAdmin => _myRole == 'admin' || _myRole == 'superadmin';

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 7, vsync: this);
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    _myUid = user.uid;

    final doc =
        await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    final data = doc.data() ?? {};
    if (!mounted) return;
    setState(() {
      _myClinicId = (data['clinicId'] as String?);
      _myRole = ((data['role'] as String?) ?? 'staff').toLowerCase();
    });
  }

  Future<void> _logout() async {
    final cs = Theme.of(context).colorScheme;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text('You will be returned to the portal screen.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: cs.error),
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

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_myClinicId == null || _myUid == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final isStaffish =
        _myRole == 'staff' || _myRole == 'vet' || _myRole == 'admin' || _myRole == 'superadmin';
    if (!isStaffish) {
      return const Scaffold(body: Center(child: Text('Staff/Vet access only')));
    }

    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('VetAssist — Staff/Vet'),
        actions: [
          IconButton(
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout),
            onPressed: _logout,
          ),
        ],
        bottom: TabBar(
          controller: _tab,
          isScrollable: true,
          tabs: const [
            Tab(icon: Icon(Icons.pets), text: 'Patients'),
            Tab(icon: Icon(Icons.psychology_alt), text: 'CDSS'),
            Tab(icon: Icon(Icons.vaccines), text: 'Vaccines & Reminders'),
            Tab(icon: Icon(Icons.healing), text: 'Visits / Treatments'),
            Tab(icon: Icon(Icons.bar_chart), text: 'Reports'),
            Tab(icon: Icon(Icons.chat), text: 'Communication'),
            Tab(icon: Icon(Icons.key), text: 'Staff Codes'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          PatientsTab(clinicId: _myClinicId!),
          const CdsTab(),
          VaccinesRemindersTab(clinicId: _myClinicId!),
          VisitsTab(clinicId: _myClinicId!),
          ReportsTab(clinicId: _myClinicId!),
          CommsTab(clinicId: _myClinicId!, staffUid: _myUid!),
          _StaffCodesTab(clinicId: _myClinicId!, isAdmin: _isAdmin),
        ],
      ),
      floatingActionButton: AnimatedBuilder(
        animation: _tab,
        builder: (_, __) {
          if (_tab.index != 6) return const SizedBox.shrink();
          return FloatingActionButton.extended(
            onPressed: () => _showCodeCreator(
              context,
              defaultClinicId: _myClinicId!,
              allowClinicPick: _isAdmin,
            ),
            icon: const Icon(Icons.key),
            label: const Text('New code'),
            backgroundColor: cs.primary,
          );
        },
      ),
    );
  }
}

/* ------------------------------ STAFF CODES TAB ------------------------------ */

class _StaffCodesTab extends StatelessWidget {
  final String clinicId;
  final bool isAdmin;
  const _StaffCodesTab({required this.clinicId, required this.isAdmin});

  @override
  Widget build(BuildContext context) {
    // Query ordered by createdAt; filter to clinic in memory to avoid composite index.
    final q = FirebaseFirestore.instance
        .collection('staff_codes')
        .orderBy('createdAt', descending: true);

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: q.snapshots(),
      builder: (ctx, snap) {
        if (snap.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Couldn’t load invite codes.\n${snap.error}',
                  textAlign: TextAlign.center),
            ),
          );
        }
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final all = snap.data?.docs ?? const [];
        final docs = isAdmin
            ? all
            : all.where((d) => (d.data()['clinicId'] as String?) == clinicId).toList();

        if (docs.isEmpty) {
          return const Center(
            child: Text('No invite codes yet. Tap “New code” to generate one.'),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (_, i) {
            final ref = docs[i].reference;
            final d = docs[i].data();
            final code = docs[i].id;
            final active = (d['active'] as bool?) ?? true;
            final uses = (d['uses'] as num?)?.toInt() ?? 0;
            final maxUses = (d['maxUses'] as num?)?.toInt();
            final cid = (d['clinicId'] as String?) ?? '';

            final badge = active ? 'ACTIVE' : 'INACTIVE';
            final limit = maxUses == null ? '∞' : '$maxUses';

            return Card(
              child: ListTile(
                leading: CircleAvatar(child: Text(code.substring(0, 2))),
                title: Row(
                  children: [
                    Expanded(child: Text('Code: $code')),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: active ? Colors.green.withOpacity(.12) : Colors.red.withOpacity(.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        badge,
                        style: TextStyle(
                          fontSize: 11,
                          color: active ? Colors.green[900] : Colors.red[900],
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                subtitle: Text('Uses: $uses / $limit   •   Clinic: $cid'),
                trailing: PopupMenuButton<String>(
                  onSelected: (v) async {
                    if (v == 'copy') {
                      await Clipboard.setData(ClipboardData(text: code));
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Code copied')),
                        );
                      }
                    } else if (v == 'toggle') {
                      await ref.update({
                        'active': !active,
                        'updatedAt': FieldValue.serverTimestamp(),
                      });
                    } else if (v == 'setMax') {
                      final value = await _askNumber(
                        context,
                        title: 'Set Maximum Uses',
                        hint: 'Leave blank to remove limit',
                      );
                      if (value == null) return;
                      await ref.update({
                        'maxUses': value,
                        'updatedAt': FieldValue.serverTimestamp(),
                      });
                    } else if (v == 'delete') {
                      final ok = await _confirm(
                        context,
                        'Delete code?',
                        'This cannot be undone.',
                      );
                      if (ok == true) await ref.delete();
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'copy', child: Text('Copy code')),
                    PopupMenuItem(value: 'toggle', child: Text('Deactivate/Activate')),
                    PopupMenuItem(value: 'setMax', child: Text('Set max uses')),
                    PopupMenuDivider(),
                    PopupMenuItem(value: 'delete', child: Text('Delete')),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

/* ------------------------------- DIALOGS/UTILS ------------------------------ */

Future<void> _showCodeCreator(
  BuildContext context, {
  required String defaultClinicId,
  required bool allowClinicPick,
}) async {
  final codeCtrl = TextEditingController(text: _genCode(6));
  String selectedClinicId = defaultClinicId;
  int? maxUses;

  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) {
      return Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 8,
          bottom: 16 + MediaQuery.of(ctx).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('New Invite Code', style: Theme.of(ctx).textTheme.titleMedium),
            const SizedBox(height: 12),
            _L(
              label: 'Code',
              child: TextField(
                controller: codeCtrl,
                textCapitalization: TextCapitalization.characters,
              ),
            ),
            const SizedBox(height: 6),
            if (allowClinicPick)
              _ClinicDropdown(
                initialId: defaultClinicId,
                onSelected: (id) => selectedClinicId = id,
              )
            else
              FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                future: FirebaseFirestore.instance
                    .collection('clinics')
                    .doc(defaultClinicId)
                    .get(),
                builder: (_, s) {
                  final name = s.data?.data()?['name'] as String? ?? defaultClinicId;
                  return _L(
                    label: 'Clinic',
                    child: TextFormField(
                      initialValue: name,
                      readOnly: true,
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.local_hospital),
                      ),
                    ),
                  );
                },
              ),
            const SizedBox(height: 6),
            _L(
              label: 'Max uses (optional)',
              child: TextField(
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(hintText: 'e.g., 5'),
                onChanged: (v) =>
                    maxUses = v.trim().isEmpty ? null : int.tryParse(v.trim()),
              ),
            ),
            const SizedBox(height: 10),
            FilledButton.icon(
              icon: const Icon(Icons.key),
              label: const Text('Create code'),
              onPressed: () async {
                final code = codeCtrl.text.trim().toUpperCase();
                if (code.isEmpty || selectedClinicId.isEmpty) return;
                final data = {
                  'clinicId': selectedClinicId,
                  'active': true,
                  'uses': 0,
                  if (maxUses != null) 'maxUses': maxUses,
                  'createdAt': FieldValue.serverTimestamp(),
                  'updatedAt': FieldValue.serverTimestamp(),
                };
                await FirebaseFirestore.instance
                    .collection('staff_codes')
                    .doc(code)
                    .set(data, SetOptions(merge: false));
                if (context.mounted) Navigator.pop(ctx);
              },
            ),
          ],
        ),
      );
    },
  );
}

class _ClinicDropdown extends StatelessWidget {
  final String? initialId;
  final void Function(String clinicId) onSelected;
  const _ClinicDropdown({this.initialId, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    String? _value = initialId;
    final stream = FirebaseFirestore.instance
        .collection('clinics')
        .orderBy('name')
        .snapshots();
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: stream,
      builder: (_, s) {
        final items = s.data?.docs ?? const [];
        if (items.isEmpty) {
          return const ListTile(
            title: Text('No clinics available.'),
            subtitle: Text('Create a clinic first.'),
          );
        }
        return _L(
          label: 'Clinic',
          child: StatefulBuilder(
            builder: (_, setLocal) => DropdownButtonFormField<String>(
              value: _value,
              items: items
                  .map((d) => DropdownMenuItem(
                        value: d.id,
                        child: Text((d.data()['name'] as String?)?.trim() ?? d.id),
                      ))
                  .toList(),
              onChanged: (v) {
                setLocal(() => _value = v);
                if (v != null) onSelected(v);
              },
              hint: const Text('Select clinic'),
            ),
          ),
        );
      },
    );
  }
}

class _L extends StatelessWidget {
  final String label;
  final Widget child;
  const _L({required this.label, required this.child});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
          const SizedBox(height: 6),
          child,
        ],
      ),
    );
  }
}

Future<bool?> _confirm(BuildContext context, String title, String msg) {
  return showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(msg),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Continue')),
      ],
    ),
  );
}

Future<int?> _askNumber(
  BuildContext context, {
  required String title,
  String? hint,
}) async {
  final ctrl = TextEditingController();
  final res = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: ctrl,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(hintText: hint),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(ctx, ctrl.text.trim()), child: const Text('Save')),
      ],
    ),
  );
  if (res == null || res.isEmpty) return null;
  return int.tryParse(res);
}

String _genCode(int len) {
  const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // avoid O/0/I/1
  final rnd = Random.secure();
  return List.generate(len, (_) => chars[rnd.nextInt(chars.length)]).join();
}
