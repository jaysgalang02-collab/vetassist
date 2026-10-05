import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../services/local_cdss_service.dart';
import '../../services/symptom_engine.dart';
import '../../widgets/cdss_chat_box.dart';
import '../../widgets/brand_widgets.dart';
import '../../widgets/evaluation_card.dart';
import 'pet_form_screen.dart';
import 'pet_detail_screen.dart';
import 'reminders_screen.dart';
import 'profile_screen.dart';
import 'chat_screen.dart';
import 'book_visit_screen.dart';

class UserDashboard extends StatefulWidget {
  const UserDashboard({super.key});
  @override
  State<UserDashboard> createState() => _UserDashboardState();
}

String _partOfDay() {
  final h = DateTime.now().hour;
  if (h < 12) return 'morning';
  if (h < 18) return 'afternoon';
  return 'evening';
}

class _UserDashboardState extends State<UserDashboard> {
  int _tab = 0;
  String get _uid => FirebaseAuth.instance.currentUser!.uid;

  Stream<QuerySnapshot<Map<String, dynamic>>>
      _bookingStatusNotificationStream() {
    return FirebaseFirestore.instance
        .collection('notifications')
        .doc(_uid)
        .collection('items')
        .where('type', isEqualTo: 'booking_status')
        .where('read', isEqualTo: false)
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _chatNotificationStream() {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(_uid)
        .collection('inbox')
        .where('read', isEqualTo: false)
        .snapshots();
  }

  Future<void> _markBookingNotificationRead(String docId) async {
    await FirebaseFirestore.instance
        .collection('notifications')
        .doc(_uid)
        .collection('items')
        .doc(docId)
        .update({
      'read': true,
      'readAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _markChatNotificationRead(String docId) async {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(_uid)
        .collection('inbox')
        .doc(docId)
        .update({
      'read': true,
      'readAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _markAllBookingNotificationsRead(
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

  Future<void> _markAllChatNotificationsRead(
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

  Future<void> _openBookingStatusNotifications() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _bookingStatusNotificationStream(),
              builder: (context, bookingSnap) {
                return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: _chatNotificationStream(),
                  builder: (context, chatSnap) {
                    if (!bookingSnap.hasData || !chatSnap.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final bookingDocs = [...bookingSnap.data!.docs]
                      ..sort((a, b) {
                        final ta = (a.data()['createdAt'] as Timestamp?)
                                ?.millisecondsSinceEpoch ??
                            0;
                        final tb = (b.data()['createdAt'] as Timestamp?)
                                ?.millisecondsSinceEpoch ??
                            0;
                        return tb.compareTo(ta);
                      });
                    final chatDocs = chatSnap.data!.docs.where((d) {
                      final fromStaff =
                          (d.data()['fromStaffUid'] as String?)?.isNotEmpty ==
                              true;
                      return fromStaff;
                    }).toList()
                      ..sort((a, b) {
                        final ta = (a.data()['createdAt'] as Timestamp?)
                                ?.millisecondsSinceEpoch ??
                            0;
                        final tb = (b.data()['createdAt'] as Timestamp?)
                                ?.millisecondsSinceEpoch ??
                            0;
                        return tb.compareTo(ta);
                      });

                    final rows = <Map<String, dynamic>>[
                      ...bookingDocs.map((d) => {
                            'kind': 'booking',
                            'id': d.id,
                            'title': (d.data()['title'] as String?) ??
                                'Booking update',
                            'body': (d.data()['body'] as String?) ?? '',
                            'createdAt': d.data()['createdAt'] as Timestamp?,
                          }),
                      ...chatDocs.map((d) {
                        final data = d.data();
                        final title = (data['title'] as String?)?.trim();
                        return {
                          'kind': 'chat',
                          'id': d.id,
                          'title': (title != null && title.isNotEmpty)
                              ? title
                              : 'New message from clinic',
                          'body': (data['body'] as String?) ?? '',
                          'createdAt': data['createdAt'] as Timestamp?,
                        };
                      }),
                    ]..sort((a, b) {
                        final ta = (a['createdAt'] as Timestamp?)
                                ?.millisecondsSinceEpoch ??
                            0;
                        final tb = (b['createdAt'] as Timestamp?)
                                ?.millisecondsSinceEpoch ??
                            0;
                        return tb.compareTo(ta);
                      });

                    return Column(
                      children: [
                        Row(
                          children: [
                            const Expanded(
                              child: Text(
                                'Notifications',
                                style: TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.w700),
                              ),
                            ),
                            TextButton(
                              onPressed: rows.isEmpty
                                  ? null
                                  : () async {
                                      await _markAllBookingNotificationsRead(
                                          bookingDocs);
                                      await _markAllChatNotificationsRead(
                                          chatDocs);
                                    },
                              child: const Text('Mark all read'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        if (rows.isEmpty)
                          const Expanded(
                            child: Center(child: Text('No new notifications.')),
                          )
                        else
                          Expanded(
                            child: ListView.separated(
                              itemCount: rows.length,
                              separatorBuilder: (_, __) =>
                                  const Divider(height: 1),
                              itemBuilder: (_, i) {
                                final row = rows[i];
                                final isChat = row['kind'] == 'chat';
                                return ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: Icon(
                                    isChat
                                        ? Icons.chat_bubble_outline
                                        : Icons.notifications_active_outlined,
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
                                    style:
                                        Theme.of(context).textTheme.bodySmall,
                                  ),
                                  onTap: () {
                                    if (isChat) {
                                      final messageId = row['id'] as String;
                                      _markChatNotificationRead(messageId);
                                      Navigator.pop(ctx);
                                      Navigator.pushNamed(
                                        context,
                                        UserChatScreen.route,
                                        arguments: {
                                          'focusMessageId': messageId
                                        },
                                      );
                                    } else {
                                      _markBookingNotificationRead(
                                          row['id'] as String);
                                    }
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
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('VetAssist'),
        actions: [
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _bookingStatusNotificationStream(),
            builder: (context, bookingSnap) {
              return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: _chatNotificationStream(),
                builder: (context, chatSnap) {
                  final bookingCount = bookingSnap.data?.docs.length ?? 0;
                  final chatCount = chatSnap.data?.docs.where((d) {
                        final fromStaff =
                            (d.data()['fromStaffUid'] as String?)?.isNotEmpty ==
                                true;
                        return fromStaff;
                      }).length ??
                      0;
                  final count = bookingCount + chatCount;
                  final label = count > 9 ? '9+' : '$count';
                  return IconButton(
                    tooltip: 'Notifications',
                    onPressed: _openBookingStatusNotifications,
                    icon: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        const Icon(Icons.notifications_outlined),
                        if (count > 0)
                          Positioned(
                            right: -5,
                            top: -5,
                            child: Container(
                              constraints: const BoxConstraints(
                                  minWidth: 18, minHeight: 18),
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 4),
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
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (context.mounted) {
                Navigator.pushNamedAndRemoveUntil(
                    context, '/auth', (_) => false);
              }
            },
            icon: const Icon(Icons.logout),
          )
        ],
      ),
      body: MotionTabStack(
        index: _tab,
        children: [
          _HomeTab(onGoToTab: (i) => setState(() => _tab = i)),
          const _PetsTab(),
          const _UserCdssTab(),
          const RemindersScreen(),
          const ProfileScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home),
              label: 'Home'),
          NavigationDestination(
              icon: Icon(Icons.pets_outlined),
              selectedIcon: Icon(Icons.pets),
              label: 'My Pets'),
          NavigationDestination(
              icon: Icon(Icons.health_and_safety_outlined),
              selectedIcon: Icon(Icons.health_and_safety),
              label: 'AI Care'),
          NavigationDestination(
              icon: Icon(Icons.event_note_outlined),
              selectedIcon: Icon(Icons.event_note),
              label: 'Reminders'),
          NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person),
              label: 'Profile'),
        ],
      ),
      floatingActionButton: _tab == 1
          ? FloatingActionButton.extended(
              onPressed: () =>
                  Navigator.pushNamed(context, PetFormScreen.route),
              icon: const Icon(Icons.add),
              label: const Text('Add Pet'),
            )
          : null,
      backgroundColor: cs.surface,
    );
  }
}

class _UpcomingVaccinationsCard extends StatelessWidget {
  const _UpcomingVaccinationsCard();

  Future<List<String>> _patientIds(String uid) async {
    final q = await FirebaseFirestore.instance
        .collection('patients')
        .where('ownerUid', isEqualTo: uid)
        .get();
    return q.docs.map((e) => e.id).toList();
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final cs = Theme.of(context).colorScheme;
    return FutureBuilder<List<String>>(
      future: _patientIds(uid),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return Card(
            color: cs.surfaceContainerHighest.withValues(alpha: .6),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: const Padding(
              padding: EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Upcoming vaccinations',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                  SizedBox(height: 8),
                  LinearProgressIndicator(minHeight: 2),
                ],
              ),
            ),
          );
        }
        final ids = snap.data ?? const <String>[];
        if (ids.isEmpty) {
          return Card(
            color: cs.surfaceContainerHighest.withValues(alpha: .6),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: const Padding(
              padding: EdgeInsets.all(12),
              child: ListTile(
                leading: Icon(Icons.vaccines_outlined),
                title: Text('No upcoming vaccinations'),
                subtitle: Text(
                    'Great! You’re all up to date. We’ll remind you when the next one is due.'),
              ),
            ),
          );
        }

        final batch = ids.take(10).toList();
        final stream = FirebaseFirestore.instance
            .collection('reminders')
            .where('patientId', whereIn: batch)
            .where('type', isEqualTo: 'vaccine')
            .orderBy('dueAt')
            .snapshots();

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: stream,
          builder: (context, rSnap) {
            if (rSnap.connectionState == ConnectionState.waiting &&
                !(rSnap.hasData && rSnap.data!.docs.isNotEmpty)) {
              return Card(
                color: cs.surfaceContainerHighest.withValues(alpha: .6),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                child: const Padding(
                  padding: EdgeInsets.all(12),
                  child: LinearProgressIndicator(minHeight: 2),
                ),
              );
            }

            final docs = rSnap.data?.docs ?? const [];
            if (docs.isEmpty) {
              return Card(
                color: cs.surfaceContainerHighest.withValues(alpha: .6),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                child: const Padding(
                  padding: EdgeInsets.all(12),
                  child: ListTile(
                    leading: Icon(Icons.vaccines_outlined),
                    title: Text('No upcoming vaccinations'),
                    subtitle: Text(
                        'Great! You’re all up to date. We’ll remind you when the next one is due.'),
                  ),
                ),
              );
            }

            final now = DateTime.now();
            Map<String, dynamic>? first;
            for (final d in docs) {
              final data = d.data();
              final ts = data['dueAt'] ?? data['when'];
              if (ts is! Timestamp) continue;
              final dt = ts.toDate();
              if (dt.isAfter(now)) {
                first = data;
                break;
              }
            }

            if (first == null) {
              return Card(
                color: cs.surfaceContainerHighest.withValues(alpha: .6),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                child: const Padding(
                  padding: EdgeInsets.all(12),
                  child: ListTile(
                    leading: Icon(Icons.vaccines_outlined),
                    title: Text('No upcoming vaccinations'),
                    subtitle: Text(
                        'Great! You’re all up to date. We’ll remind you when the next one is due.'),
                  ),
                ),
              );
            }

            final pid = (first['patientId'] ?? '') as String;
            final due =
                ((first['dueAt'] ?? first['when']) as Timestamp).toDate();
            if (pid.isEmpty) {
              return Card(
                color: cs.surfaceContainerHighest.withValues(alpha: .6),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                child: ListTile(
                  leading: const Icon(Icons.vaccines),
                  title: const Text('Vaccine'),
                  subtitle: Text('Due on ${_fmt(due)}'),
                ),
              );
            }

            return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('patients')
                  .doc(pid)
                  .snapshots(),
              builder: (ctx, ps) {
                String petName = 'Pet';
                if (ps.hasData && ps.data!.exists) {
                  petName = (ps.data!.data()!['name'] ?? 'Pet') as String;
                }
                return Card(
                  color: cs.surfaceContainerHighest.withValues(alpha: .6),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  child: ListTile(
                    leading: const Icon(Icons.vaccines),
                    title: Text('$petName — Vaccine'),
                    subtitle: Text('Due on ${_fmt(due)}'),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

class _UpcomingRemindersCard extends StatelessWidget {
  final int limit;
  const _UpcomingRemindersCard({this.limit = 3});

  Future<List<String>> _patientIds(String uid) async {
    final q = await FirebaseFirestore.instance
        .collection('patients')
        .where('ownerUid', isEqualTo: uid)
        .get();
    return q.docs.map((e) => e.id).toList();
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final cs = Theme.of(context).colorScheme;
    return FutureBuilder<List<String>>(
      future: _patientIds(uid),
      builder: (ctx, idsSnap) {
        if (idsSnap.connectionState == ConnectionState.waiting) {
          return Card(
            color: cs.surfaceContainerHighest.withValues(alpha: .6),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: const Padding(
              padding: EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Upcoming reminders',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                  SizedBox(height: 8),
                  LinearProgressIndicator(minHeight: 2),
                ],
              ),
            ),
          );
        }
        final ids = idsSnap.data ?? const <String>[];
        if (ids.isEmpty) {
          return Card(
            color: cs.surfaceContainerHighest.withValues(alpha: .6),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: const Padding(
              padding: EdgeInsets.all(12),
              child: ListTile(
                leading: Icon(Icons.notifications_none),
                title: Text('No reminders yet'),
                subtitle: Text(
                    'Create visits or vaccinations to see reminders here.'),
              ),
            ),
          );
        }

        final stream = FirebaseFirestore.instance
            .collection('reminders')
            .where('patientId', whereIn: ids.take(10).toList())
            .orderBy('dueAt')
            .snapshots();

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: stream,
          builder: (context, snap) {
            final docs = snap.data?.docs ?? const [];
            final now = DateTime.now();
            final items = docs
                .map((d) => d.data())
                .where((m) => (m['dueAt'] ?? m['when']) is Timestamp)
                .map((m) {
                  final ts = (m['dueAt'] ?? m['when']) as Timestamp;
                  return _ReminderItem(
                    title: (m['title'] as String?)?.isNotEmpty == true
                        ? m['title'] as String
                        : (m['type'] as String? ?? 'Reminder'),
                    when: ts.toDate(),
                  );
                })
                .where((it) => it.when.isAfter(now))
                .toList()
              ..sort((a, b) => a.when.compareTo(b.when));

            final show = items.take(limit).toList();
            if (show.isEmpty) {
              return Card(
                color: cs.surfaceContainerHighest.withValues(alpha: .6),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                child: const Padding(
                  padding: EdgeInsets.all(12),
                  child: ListTile(
                    leading: Icon(Icons.notifications_none),
                    title: Text('No upcoming reminders'),
                  ),
                ),
              );
            }

            return Card(
              color: cs.surfaceContainerHighest.withValues(alpha: .6),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Upcoming reminders',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    for (final it in show)
                      ListTile(
                        leading:
                            const Icon(Icons.notifications_active_outlined),
                        title: Text(it.title),
                        subtitle: Text(_fmt(it.when)),
                      ),
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

class _ReminderItem {
  final String title;
  final DateTime when;
  _ReminderItem({required this.title, required this.when});
}

String _fmt(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

class _HomeTab extends StatelessWidget {
  final void Function(int) onGoToTab;
  const _HomeTab({required this.onGoToTab});
  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final cs = Theme.of(context).colorScheme;

    final userDoc =
        FirebaseFirestore.instance.collection('users').doc(uid).snapshots();
    final featuredPetQuery = FirebaseFirestore.instance
        .collection('patients')
        .where('ownerUid', isEqualTo: uid)
        .orderBy('name')
        .limit(1);

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: userDoc,
      builder: (ctx, meSnap) {
        String displayName =
            FirebaseAuth.instance.currentUser?.email ?? 'Customer';
        String? clinicId;
        if (meSnap.hasData && meSnap.data!.exists) {
          final d = meSnap.data!.data();
          final dn = (d?['displayName'] as String?)?.trim();
          if (dn != null && dn.isNotEmpty) displayName = dn;
          clinicId = (d?['clinicId'] as String?)?.trim();
        }

        return ContentFrame(
            maxWidth: 760,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text('Good ${_partOfDay()}, $displayName 👋',
                          style: Theme.of(context).textTheme.titleLarge),
                    ),
                    if (clinicId != null && clinicId.isNotEmpty)
                      Padding(
                        padding: EdgeInsets.zero,
                        child: _ClinicPill(clinicId: clinicId),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text("Here’s a quick look at your pets.",
                    style: TextStyle(color: cs.onSurfaceVariant)),
                const SizedBox(height: 12),
                _AsyncCard(
                  title: 'Your pet',
                  stream: featuredPetQuery.snapshots(),
                  builder: (qs) {
                    final d = qs.docs.first.data() as Map<String, dynamic>;
                    final name = (d['name'] ?? 'Pet') as String;
                    final species = (d['species'] ?? '') as String;
                    final pid = qs.docs.first.id;
                    final lastCheckupStream = FirebaseFirestore.instance
                        .collection('visits')
                        .where('patientId', isEqualTo: pid)
                        .orderBy('date', descending: true)
                        .limit(1)
                        .snapshots();
                    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: lastCheckupStream,
                      builder: (ctx, vSnap) {
                        String lastCheck = '—';
                        if (vSnap.hasData && vSnap.data!.docs.isNotEmpty) {
                          final m = vSnap.data!.docs.first.data();
                          final dt = (m['date'] as Timestamp?)?.toDate();
                          if (dt != null) lastCheck = _fmt(dt);
                        }
                        return _PetHeroCard(
                          name: name,
                          species: species,
                          lastCheckupText: lastCheck,
                          onTap: () => Navigator.pushNamed(
                              context, PetDetailScreen.route,
                              arguments:
                                  PetDetailArgs(patientId: pid, name: name)),
                        );
                      },
                    );
                  },
                  empty: _EmptyHeroCard(
                      onAdd: () =>
                          Navigator.pushNamed(context, PetFormScreen.route)),
                ),
                const SizedBox(height: 12),
                Entrance(
                  child: CareHero(
                    eyebrow: 'CARE, ONE VISIT AT A TIME',
                    title: 'Make time for their wellbeing.',
                    subtitle:
                        'Choose a time and request a visit with your clinic. Follow the approval in your booking updates.',
                    action: FilledButton.icon(
                      style: FilledButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor:
                              Theme.of(context).colorScheme.primary),
                      onPressed: () =>
                          Navigator.pushNamed(context, BookVisitScreen.route),
                      icon: const Icon(Icons.calendar_month_rounded),
                      label: const Text('Book a visit'),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () =>
                      Navigator.pushNamed(context, PetFormScreen.route),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Add a pet'),
                ),
                const SizedBox(height: 12),
                AdaptiveActions(children: [
                  OutlinedButton.icon(
                    onPressed: () =>
                        Navigator.pushNamed(context, RemindersScreen.route),
                    icon: const Icon(Icons.vaccines_outlined),
                    label: const Text('Vaccinations'),
                  ),
                  _ChatQuickAction(uid: uid),
                ]),
                const SizedBox(height: 12),
                const _CareChecklist(),
                const SizedBox(height: 12),
                const _UpcomingVaccinationsCard(),
                const SizedBox(height: 12),
                const _UpcomingRemindersCard(limit: 3),
                const EvaluationCard(topPadding: 16),
              ],
            ));
      },
    );
  }
}

class _ChatQuickAction extends StatelessWidget {
  final String uid;
  const _ChatQuickAction({required this.uid});

  @override
  Widget build(BuildContext context) {
    final stream = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('inbox')
        .where('read', isEqualTo: false)
        .snapshots();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snap) {
        if (snap.hasError) {
          return OutlinedButton.icon(
            onPressed: () => Navigator.pushNamed(context, UserChatScreen.route),
            icon: const Icon(Icons.chat_bubble_outline),
            label: const Text('Chat'),
          );
        }
        final unreadCount = snap.data?.docs.length ?? 0;
        final showBadge = unreadCount > 0;

        Widget icon = const Icon(Icons.chat_bubble_outline);
        if (showBadge) {
          final badgeText = unreadCount > 9 ? '9+' : unreadCount.toString();
          icon = Stack(
            clipBehavior: Clip.none,
            children: [
              const Icon(Icons.chat_bubble_outline),
              Positioned(
                right: -6,
                top: -6,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.red.shade600,
                    shape: BoxShape.rectangle,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white, width: 1.5),
                    boxShadow: const [
                      BoxShadow(
                          color: Colors.black26,
                          blurRadius: 4,
                          offset: Offset(0, 1))
                    ],
                  ),
                  child: Text(
                    badgeText,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          );
        }

        return OutlinedButton.icon(
          onPressed: () => Navigator.pushNamed(context, UserChatScreen.route),
          icon: icon,
          label: const Text('Chat'),
        );
      },
    );
  }
}

class _AsyncCard extends StatelessWidget {
  final String title;
  final Stream<QuerySnapshot> stream;
  final Widget Function(QuerySnapshot) builder;
  final Widget? empty;
  const _AsyncCard(
      {required this.title,
      required this.stream,
      required this.builder,
      this.empty});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final emptyWidget = empty ?? const SizedBox.shrink();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          StreamBuilder<QuerySnapshot>(
            stream: stream,
            builder: (ctx, snap) {
              if (snap.hasError) {
                return Text(
                    'We could not load this update. Please check your connection and try again.',
                    style: TextStyle(color: cs.onSurfaceVariant));
              }
              if (snap.connectionState == ConnectionState.waiting) {
                return const LinearProgressIndicator(minHeight: 2);
              }
              if (!snap.hasData || snap.data!.docs.isEmpty) return emptyWidget;
              return builder(snap.data!);
            },
          ),
        ]),
      ),
    );
  }
}

class _PetHeroCard extends StatelessWidget {
  final String name;
  final String species;
  final String lastCheckupText;
  final VoidCallback onTap;
  const _PetHeroCard(
      {required this.name,
      required this.species,
      required this.lastCheckupText,
      required this.onTap});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      color: cs.surfaceContainerHighest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        leading: CircleAvatar(
            backgroundColor: cs.primaryContainer,
            child: const Icon(Icons.pets)),
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle:
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (species.isNotEmpty) Text(species),
          const SizedBox(height: 4),
          Text('Last check-up: $lastCheckupText',
              style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
        ]),
        trailing: const Icon(Icons.arrow_forward_rounded, size: 20),
        onTap: onTap,
      ),
    );
  }
}

class _EmptyHeroCard extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyHeroCard({required this.onAdd});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      color: cs.surfaceContainerHighest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        leading: CircleAvatar(
            backgroundColor: cs.primaryContainer,
            child: const Icon(Icons.pets)),
        title: const Text('Add your first pet'),
        subtitle: const Text('Start by creating a pet profile.'),
        trailing: const Icon(Icons.chevron_right),
        onTap: onAdd,
      ),
    );
  }
}

class _ClinicPill extends StatelessWidget {
  final String clinicId;
  const _ClinicPill({required this.clinicId});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('clinics')
          .doc(clinicId)
          .snapshots(),
      builder: (ctx, snap) {
        if (!snap.hasData || !snap.data!.exists) return const SizedBox.shrink();
        final name = (snap.data!.data()!['name'] as String?)?.trim();
        if (name == null || name.isEmpty) return const SizedBox.shrink();
        return InputChip(
          label: Text(name, maxLines: 2, overflow: TextOverflow.ellipsis),
          avatar: Icon(Icons.add_business, size: 18, color: cs.primary),
          onPressed: null,
          backgroundColor: cs.surfaceContainerHighest,
          labelStyle: const TextStyle(fontWeight: FontWeight.w600),
          visualDensity: VisualDensity.compact,
        );
      },
    );
  }
}

class _CareChecklist extends StatelessWidget {
  const _CareChecklist();
  @override
  Widget build(BuildContext context) {
    return Card(
      child: const Padding(
        padding: EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Care checklist',
                style: TextStyle(fontWeight: FontWeight.w700)),
            SizedBox(height: 8),
            _ChecklistTile(
                text: 'Keep vaccination card updated after each vet visit.'),
            _ChecklistTile(
                text:
                    'Review reminders for deworming and tick/flea prevention.'),
            _ChecklistTile(
                text:
                    'Record your pet’s weight and medications after each visit.')
          ],
        ),
      ),
    );
  }
}

class _ChecklistTile extends StatelessWidget {
  final String text;
  const _ChecklistTile({required this.text});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Row(
        children: [
          Icon(Icons.task_alt, size: 18, color: cs.primary),
          const SizedBox(width: 8),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}

class _PetsTab extends StatefulWidget {
  const _PetsTab();
  @override
  State<_PetsTab> createState() => _PetsTabState();
}

class _PetsTabState extends State<_PetsTab> {
  String _query = '';
  Timer? _deb;
  @override
  void dispose() {
    _deb?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final baseQuery = FirebaseFirestore.instance
        .collection('patients')
        .where('ownerUid', isEqualTo: uid)
        .orderBy('name');
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: TextField(
          decoration: const InputDecoration(
              hintText: 'Search pets by name…', prefixIcon: Icon(Icons.search)),
          onChanged: (v) {
            _deb?.cancel();
            _deb = Timer(const Duration(milliseconds: 300), () {
              if (!mounted) return;
              setState(() => _query = v.trim().toLowerCase());
            });
          },
        ),
      ),
      Expanded(
        child: StreamBuilder<QuerySnapshot>(
          stream: baseQuery.snapshots(),
          builder: (ctx, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (!snap.hasData || snap.data!.docs.isEmpty) {
              return const _EmptyPets();
            }
            final items = snap.data!.docs.where((doc) {
              if (_query.isEmpty) return true;
              final name = ((doc.data() as Map)['name'] ?? '') as String;
              return name.toLowerCase().contains(_query);
            }).toList();
            if (items.isEmpty) {
              return const Center(child: Text('No pets match your search.'));
            }
            return ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 6),
              itemBuilder: (_, i) {
                final d = items[i].data() as Map<String, dynamic>;
                final id = items[i].id;
                final name = (d['name'] ?? 'Pet') as String;
                final species = (d['species'] ?? '') as String;
                final breed = (d['breed'] ?? '') as String;
                return Card(
                  child: ListTile(
                    leading: const Icon(Icons.pets),
                    title: Text(name),
                    subtitle: Text(
                        '${species.isEmpty ? '' : species}${breed.isEmpty ? '' : ' • $breed'}'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.pushNamed(
                        context, PetDetailScreen.route,
                        arguments: PetDetailArgs(patientId: id, name: name)),
                  ),
                );
              },
            );
          },
        ),
      ),
    ]);
  }
}

class _EmptyPets extends StatelessWidget {
  const _EmptyPets();
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: const [
        Icon(Icons.pets, size: 48, color: Colors.grey),
        SizedBox(height: 8),
        Text('No pets yet'),
      ]),
    );
  }
}

class _UserCdssTab extends StatefulWidget {
  const _UserCdssTab();
  @override
  State<_UserCdssTab> createState() => _UserCdssTabState();
}

class _UserCdssTabState extends State<_UserCdssTab> {
  String species = 'canine';
  File? _photo;
  bool _loading = false;
  Map<String, dynamic>? _ai;
  final Map<String, bool> symptoms = {
    'fever': false,
    'vomiting': false,
    'diarrhea': false,
    'cough': false,
    'nasal_discharge': false,
    'ocular_discharge': false,
    'lethargy': false,
    'loss_of_appetite': false,
    'weight_loss': false,
    'respiratory_distress': false,
    'pale_gums': false,
    'neurologic_signs': false,
  };

  Future<void> _pickAndAnalyze(ImageSource src) async {
    final picker = ImagePicker();
    final x =
        await picker.pickImage(source: src, imageQuality: 92, maxWidth: 1800);
    if (x == null) return;
    setState(() {
      _photo = File(x.path);
      _ai = null;
      _loading = true;
    });
    try {
      final result = await LocalPetPhotoService().analyzePetImage(
        file: _photo!,
        speciesHint: species,
        firstAidOnly: true,
      );
      setState(() => _ai = result);
      final inferred = (_ai?['inferred_symptoms'] ?? []) as List;
      for (final key in symptoms.keys) {
        final hit = inferred
            .any((i) => i.toString().toLowerCase() == key.toLowerCase());
        if (hit) symptoms[key] = true;
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Image analysis failed: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showPicker() {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (_) => SafeArea(
          child: Wrap(children: [
        ListTile(
            leading: const Icon(Icons.photo_camera),
            title: const Text('Take photo'),
            onTap: () {
              Navigator.pop(context);
              _pickAndAnalyze(ImageSource.camera);
            }),
        ListTile(
            leading: const Icon(Icons.photo_library),
            title: const Text('Choose from gallery'),
            onTap: () {
              Navigator.pop(context);
              _pickAndAnalyze(ImageSource.gallery);
            }),
      ])),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final hasSymptoms = symptoms.values.any((value) => value);
    return Padding(
      padding: const EdgeInsets.all(12),
      child: ListView(children: [
        Wrap(
          spacing: 12,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            const Text('Species:'),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'canine', label: Text('Dog')),
                ButtonSegment(value: 'feline', label: Text('Cat')),
              ],
              selected: {species},
              onSelectionChanged: (s) => setState(() {
                species = s.first;
                _ai = null;
                for (final key in symptoms.keys) {
                  symptoms[key] = false;
                }
              }),
            ),
            FilledButton.icon(
              onPressed: _loading ? null : _showPicker,
              icon: const Icon(Icons.camera_alt_rounded, size: 18),
              label: const Text('Attach Photo'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_photo != null || _loading || _ai != null)
          Card(
            color: cs.surfaceContainerHighest,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_photo != null)
                      ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.file(_photo!,
                              height: 180,
                              fit: BoxFit.cover,
                              width: double.infinity)),
                    if (_loading) ...[
                      const SizedBox(height: 12),
                      const LinearProgressIndicator(),
                      const SizedBox(height: 6),
                      const Text('Attaching photo…'),
                    ],
                    if (!_loading && _ai != null) ...[
                      const SizedBox(height: 12),
                      Text('Photo attached',
                          style: TextStyle(
                              fontWeight: FontWeight.w700, color: cs.primary)),
                      const SizedBox(height: 6),
                      const Text(
                          'Photo attached only. Describe or select symptoms; photos are not analyzed.'),
                      if ((_ai!['red_flags'] as List?)?.isNotEmpty == true) ...[
                        const SizedBox(height: 8),
                        Text('Red flags',
                            style: TextStyle(
                                fontWeight: FontWeight.w600, color: cs.error)),
                        const SizedBox(height: 4),
                        ...(_ai!['red_flags'] as List).map((e) => Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(Icons.warning_amber_rounded,
                                      color: cs.error, size: 16),
                                  const SizedBox(width: 6),
                                  Expanded(child: Text(e.toString()))
                                ]))
                      ],
                    ],
                  ]),
            ),
          ),
        const SizedBox(height: 8),
        Text('Select symptoms',
            style: TextStyle(fontWeight: FontWeight.w700, color: cs.primary)),
        const SizedBox(height: 6),
        Wrap(
            spacing: 8,
            runSpacing: -8,
            children: symptoms.keys.map((k) {
              final v = symptoms[k]!;
              return FilterChip(
                  label: Text(k.replaceAll('_', ' ')),
                  selected: v,
                  onSelected: (sel) => setState(() => symptoms[k] = sel));
            }).toList()),
        const SizedBox(height: 14),
        if (!hasSymptoms)
          const Text('Select symptoms to see First Aid guidance.')
        else
          Card(
              child: ListTile(
            leading: const CircleAvatar(
                child: Icon(Icons.health_and_safety_outlined)),
            title: const Text('First Aid guidance'),
            subtitle: const Text(
                'Safe immediate steps and signs that require veterinary care.'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () {
              final advice = SymptomEngine().reply(
                  symptoms.entries
                      .where((e) => e.value)
                      .map((e) => e.key)
                      .join(', '),
                  species,
                  firstAidOnly: true);
              showModalBottomSheet(
                context: context,
                showDragHandle: true,
                builder: (_) => Padding(
                  padding: const EdgeInsets.all(16),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('First Aid',
                            style: Theme.of(context).textTheme.titleLarge),
                        const SizedBox(height: 6),
                        Text(advice),
                      ],
                    ),
                  ),
                ),
              );
            },
          )),
        const SizedBox(height: 24),
        CDSSChatBox(species: species, firstAidOnly: true),
      ]),
    );
  }
}
