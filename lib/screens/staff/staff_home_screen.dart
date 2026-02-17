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
import 'package:vetassist/screens/staff/tabs/schedule_tab.dart';

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
  final GlobalKey<CommsTabState> _commsTabKey = GlobalKey<CommsTabState>();

  late final TabController _tab;

  bool get _isAdmin => _myRole == 'admin' || _myRole == 'superadmin';

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 8, vsync: this);
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

  Stream<QuerySnapshot<Map<String, dynamic>>> _bookingNotificationStream() {
    return FirebaseFirestore.instance
        .collection('clinic_notifications')
        .doc(_myClinicId)
        .collection('items')
        .where('type', isEqualTo: 'booking_request')
        .where('read', isEqualTo: false)
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _chatNotificationStream() {
    return FirebaseFirestore.instance
        .collection('clinic_inbox')
        .doc(_myClinicId)
        .collection('messages')
        .where('read', isEqualTo: false)
        .snapshots();
  }

  Future<void> _markClinicNotificationRead(String docId) async {
    final clinicId = _myClinicId;
    if (clinicId == null) return;
    await FirebaseFirestore.instance
        .collection('clinic_notifications')
        .doc(clinicId)
        .collection('items')
        .doc(docId)
        .update({
      'read': true,
      'readAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _markClinicChatMessageRead(String docId) async {
    final clinicId = _myClinicId;
    if (clinicId == null) return;
    await FirebaseFirestore.instance
        .collection('clinic_inbox')
        .doc(clinicId)
        .collection('messages')
        .doc(docId)
        .update({
      'read': true,
      'readAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _markAllClinicNotificationsRead(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) async {
    if (docs.isEmpty) return;
    final batch = FirebaseFirestore.instance.batch();
    for (final d in docs) {
      batch.update(d.reference, {
        'read': true,
        'readAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  }

  Future<void> _markAllClinicChatRead(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) async {
    if (docs.isEmpty) return;
    final batch = FirebaseFirestore.instance.batch();
    for (final d in docs) {
      batch.update(d.reference, {
        'read': true,
        'readAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  }

  String _tsLabel(Timestamp? ts) {
    if (ts == null) return '';
    final dt = ts.toDate();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(dt.year, dt.month, dt.day);
    final hh = (dt.hour % 12 == 0 ? 12 : dt.hour % 12).toString();
    final mm = dt.minute.toString().padLeft(2, '0');
    final suffix = dt.hour >= 12 ? 'PM' : 'AM';
    if (d == today) return '$hh:$mm $suffix';
    return '${dt.month}/${dt.day} $hh:$mm $suffix';
  }

  Future<void> _openBookingNotifications() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _bookingNotificationStream(),
              builder: (context, bookingSnap) {
                return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: _chatNotificationStream(),
                  builder: (context, chatSnap) {
                    if (!bookingSnap.hasData || !chatSnap.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final bookingDocs = [...bookingSnap.data!.docs]
                      ..sort((a, b) {
                        final ta = (a.data()['createdAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
                        final tb = (b.data()['createdAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
                        return tb.compareTo(ta);
                      });
                    final chatDocs = chatSnap.data!.docs.where((d) {
                      final fromOwner = (d.data()['fromOwnerUid'] as String?)?.isNotEmpty == true;
                      return fromOwner;
                    }).toList()
                      ..sort((a, b) {
                        final ta = (a.data()['createdAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
                        final tb = (b.data()['createdAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
                        return tb.compareTo(ta);
                      });

                    final rows = <Map<String, dynamic>>[
                      ...bookingDocs.map((d) => {
                            'kind': 'booking',
                            'id': d.id,
                            'title': (d.data()['title'] as String?) ?? 'Booking request',
                            'body': (d.data()['body'] as String?) ?? '',
                            'createdAt': d.data()['createdAt'] as Timestamp?,
                          }),
                      ...chatDocs.map((d) {
                        final data = d.data();
                        final ownerName = (data['ownerName'] as String?)?.trim();
                        final body = (data['body'] as String?) ?? '';
                        return {
                          'kind': 'chat',
                          'id': d.id,
                          'title': ownerName?.isNotEmpty == true
                              ? 'New message from $ownerName'
                              : 'New customer message',
                          'body': body,
                          'createdAt': data['createdAt'] as Timestamp?,
                        };
                      }),
                    ]..sort((a, b) {
                        final ta = (a['createdAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
                        final tb = (b['createdAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
                        return tb.compareTo(ta);
                      });

                    return Column(
                      children: [
                        Row(
                          children: [
                            const Expanded(
                              child: Text(
                                'Notifications',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                              ),
                            ),
                            TextButton(
                              onPressed: rows.isEmpty
                                  ? null
                                  : () async {
                                      await _markAllClinicNotificationsRead(bookingDocs);
                                      await _markAllClinicChatRead(chatDocs);
                                    },
                              child: const Text('Mark all read'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        if (rows.isEmpty)
                          const Expanded(
                            child: Center(
                              child: Text('No new notifications.'),
                            ),
                          )
                        else
                          Expanded(
                            child: ListView.separated(
                              itemCount: rows.length,
                              separatorBuilder: (_, __) => const Divider(height: 1),
                              itemBuilder: (_, i) {
                                final row = rows[i];
                                final isChat = row['kind'] == 'chat';
                                return ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: Icon(
                                    isChat ? Icons.chat_bubble_outline : Icons.event_note_outlined,
                                  ),
                                  title: Text(
                                    row['title'] as String,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  subtitle: Text(
                                    row['body'] as String,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  trailing: Text(
                                    _tsLabel(row['createdAt'] as Timestamp?),
                                    style: Theme.of(context).textTheme.bodySmall,
                                  ),
                                  onTap: () async {
                                    if (isChat) {
                                      final messageId = row['id'] as String;
                                      await _markClinicChatMessageRead(messageId);
                                      _tab.index = 5;
                                      WidgetsBinding.instance.addPostFrameCallback((_) {
                                        _commsTabKey.currentState
                                            ?.focusMessageFromNotification(messageId);
                                      });
                                    } else {
                                      await _markClinicNotificationRead(row['id'] as String);
                                      _tab.index = 6;
                                    }
                                    if (!context.mounted) return;
                                    Navigator.pop(ctx);
                                  },
                                );
                              },
                            ),
                          ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
        );
      },
    );
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
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _bookingNotificationStream(),
            builder: (context, bookingSnap) {
              return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: _chatNotificationStream(),
                builder: (context, chatSnap) {
                  final bookingCount = bookingSnap.data?.docs.length ?? 0;
                  final chatCount = chatSnap.data?.docs.where((d) {
                        final fromOwner =
                            (d.data()['fromOwnerUid'] as String?)?.isNotEmpty == true;
                        return fromOwner;
                      }).length ??
                      0;
                  final count = bookingCount + chatCount;
                  final label = count > 9 ? '9+' : '$count';
                  return IconButton(
                    tooltip: 'Notifications',
                    onPressed: _openBookingNotifications,
                    icon: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        const Icon(Icons.notifications_none_rounded),
                        if (count > 0)
                          Positioned(
                            right: -5,
                            top: -5,
                            child: Container(
                              constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.error,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                label,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
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
            Tab(icon: Icon(Icons.event_available), text: 'Schedule'),
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
          CommsTab(
            key: _commsTabKey,
            clinicId: _myClinicId!,
            staffUid: _myUid!,
          ),
          ScheduleTab(clinicId: _myClinicId!, staffUid: _myUid!),
          _StaffCodesTab(clinicId: _myClinicId!, isAdmin: _isAdmin),
        ],
      ),
      floatingActionButton: AnimatedBuilder(
        animation: _tab,
        builder: (_, __) {
            if (_tab.index != 7) return const SizedBox.shrink();
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
                        color: active
                            ? Colors.green.withValues(alpha: 0.12)
                            : Colors.red.withValues(alpha: 0.12),
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
    String? selectedValue = initialId;
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
              value: selectedValue,
              items: items
                  .map((d) => DropdownMenuItem(
                        value: d.id,
                        child: Text((d.data()['name'] as String?)?.trim() ?? d.id),
                      ))
                  .toList(),
              onChanged: (v) {
                setLocal(() => selectedValue = v);
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
