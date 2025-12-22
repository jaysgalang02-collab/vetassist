import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../services/openai_service.dart';
import '../../widgets/cdss_chat_box.dart';
import 'pet_form_screen.dart';
import 'pet_detail_screen.dart';
import 'reminders_screen.dart';
import 'profile_screen.dart';
import 'chat_screen.dart';

class UserDashboard extends StatefulWidget {
  const UserDashboard({super.key});
  @override
  State<UserDashboard> createState() => _UserDashboardState();
}

class _UserDashboardState extends State<UserDashboard> {
  int _tab = 0; // 0=Home, 1=My Pets, 2=CDSS, 3=Reminders, 4=Profile

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('VetAssist — Customer'),
        actions: [
          IconButton(
            tooltip: 'Notifications',
            onPressed: () => Navigator.pushNamed(context, RemindersScreen.route),
            icon: const Icon(Icons.notifications_outlined),
          ),
          IconButton(
            tooltip: 'Sign out',
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (context.mounted) {
                Navigator.pushNamedAndRemoveUntil(context, '/auth', (_) => false);
              }
            },
            icon: const Icon(Icons.logout),
          )
        ],
      ),
      body: IndexedStack(
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
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.pets_outlined), selectedIcon: Icon(Icons.pets), label: 'My Pets'),
          NavigationDestination(icon: Icon(Icons.health_and_safety_outlined), selectedIcon: Icon(Icons.health_and_safety), label: 'CDSS'),
          NavigationDestination(icon: Icon(Icons.event_note_outlined), selectedIcon: Icon(Icons.event_note), label: 'Reminders'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
      floatingActionButton: _tab == 1
          ? FloatingActionButton.extended(
              onPressed: () => Navigator.pushNamed(context, PetFormScreen.route),
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
            color: cs.surfaceContainerHighest.withOpacity(.6),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: const Padding(
              padding: EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Upcoming vaccinations', style: TextStyle(fontWeight: FontWeight.w700)),
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
            color: cs.surfaceContainerHighest.withOpacity(.6),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: const Padding(
              padding: EdgeInsets.all(12),
              child: ListTile(
                leading: Icon(Icons.vaccines_outlined),
                title: Text('No upcoming vaccinations'),
                subtitle: Text('Great! You’re all up to date. We’ll remind you when the next one is due.'),
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
                color: cs.surfaceContainerHighest.withOpacity(.6),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: const Padding(
                  padding: EdgeInsets.all(12),
                  child: LinearProgressIndicator(minHeight: 2),
                ),
              );
            }

            final docs = rSnap.data?.docs ?? const [];
            if (docs.isEmpty) {
              return Card(
                color: cs.surfaceContainerHighest.withOpacity(.6),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: const Padding(
                  padding: EdgeInsets.all(12),
                  child: ListTile(
                    leading: Icon(Icons.vaccines_outlined),
                    title: Text('No upcoming vaccinations'),
                    subtitle: Text('Great! You’re all up to date. We’ll remind you when the next one is due.'),
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
                color: cs.surfaceContainerHighest.withOpacity(.6),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: const Padding(
                  padding: EdgeInsets.all(12),
                  child: ListTile(
                    leading: Icon(Icons.vaccines_outlined),
                    title: Text('No upcoming vaccinations'),
                    subtitle: Text('Great! You’re all up to date. We’ll remind you when the next one is due.'),
                  ),
                ),
              );
            }

            final pid = (first['patientId'] ?? '') as String;
            final due = ((first['dueAt'] ?? first['when']) as Timestamp).toDate();
            if (pid.isEmpty) {
              return Card(
                color: cs.surfaceContainerHighest.withOpacity(.6),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: ListTile(
                  leading: const Icon(Icons.vaccines),
                  title: const Text('Vaccine'),
                  subtitle: Text('Due on ${_fmt(due)}'),
                ),
              );
            }

            return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance.collection('patients').doc(pid).snapshots(),
              builder: (ctx, ps) {
                String petName = 'Pet';
                if (ps.hasData && ps.data!.exists) {
                  petName = (ps.data!.data()!['name'] ?? 'Pet') as String;
                }
                return Card(
                  color: cs.surfaceContainerHighest.withOpacity(.6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
            color: cs.surfaceContainerHighest.withOpacity(.6),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: const Padding(
              padding: EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Upcoming reminders', style: TextStyle(fontWeight: FontWeight.w700)),
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
            color: cs.surfaceContainerHighest.withOpacity(.6),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: const Padding(
              padding: EdgeInsets.all(12),
              child: ListTile(
                leading: Icon(Icons.notifications_none),
                title: Text('No reminders yet'),
                subtitle: Text('Create visits or vaccinations to see reminders here.'),
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
                color: cs.surfaceContainerHighest.withOpacity(.6),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
              color: cs.surfaceContainerHighest.withOpacity(.6),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Upcoming reminders', style: TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    for (final it in show)
                      ListTile(
                        leading: const Icon(Icons.notifications_active_outlined),
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

String _fmt(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/* ---------------- HOME TAB ---------------- */
class _HomeTab extends StatelessWidget {
  final void Function(int) onGoToTab;
  const _HomeTab({required this.onGoToTab});
  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final cs = Theme.of(context).colorScheme;

    final userDoc = FirebaseFirestore.instance.collection('users').doc(uid).snapshots();
    final featuredPetQuery = FirebaseFirestore.instance
        .collection('patients')
        .where('ownerUid', isEqualTo: uid)
        .orderBy('name')
        .limit(1);

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: userDoc,
      builder: (ctx, meSnap) {
        String displayName = FirebaseAuth.instance.currentUser?.email ?? 'Customer';
        String? clinicId;
        if (meSnap.hasData && meSnap.data!.exists) {
          final d = meSnap.data!.data();
          final dn = (d?['displayName'] as String?)?.trim();
          if (dn != null && dn.isNotEmpty) displayName = dn;
          clinicId = (d?['clinicId'] as String?)?.trim();
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Greeting + clinic pill
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Text('Good ${_partOfDay()}, $displayName 👋',
                      style: Theme.of(context).textTheme.titleLarge),
                ),
                if (clinicId != null && clinicId!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(left: 8.0),
                    child: _ClinicPill(clinicId: clinicId!),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text("Here’s a quick look at your pets.", style: TextStyle(color: cs.onSurfaceVariant)),

            const SizedBox(height: 12),

            // Featured pet hero with last check-up
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
                      onTap: () => Navigator.pushNamed(context, PetDetailScreen.route, arguments: PetDetailArgs(patientId: pid, name: name)),
                    );
                  },
                );
              },
              empty: _EmptyHeroCard(onAdd: () => Navigator.pushNamed(context, PetFormScreen.route)),
            ),

            const SizedBox(height: 12),

            // Quick actions
            Row(children: [
              Expanded(child: FilledButton.tonal(onPressed: ()=>Navigator.pushNamed(context, PetFormScreen.route), child: const Row(mainAxisSize: MainAxisSize.min, children:[Icon(Icons.pets), SizedBox(width:6), Text('Add pet')]))),
              const SizedBox(width: 8),
              Expanded(child: FilledButton.tonal(onPressed: (){ ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Book visit coming soon'))); }, child: const Row(mainAxisSize: MainAxisSize.min, children:[Icon(Icons.add_box_outlined), SizedBox(width:6), Text('Book visit')]))),
            ]),

            const SizedBox(height: 12),

            // Large shortcuts
            Row(children: [
              Expanded(child: OutlinedButton.icon(onPressed: ()=>Navigator.pushNamed(context, RemindersScreen.route), icon: const Icon(Icons.vaccines_outlined), label: const Text('Vaccinations'))),
              const SizedBox(width: 8),
              _ChatQuickAction(uid: uid),
            ]),

            const SizedBox(height: 12),
            const _CareChecklist(),
            const SizedBox(height: 12),
            const _UpcomingVaccinationsCard(),
            const SizedBox(height: 12),
            const _UpcomingRemindersCard(limit: 3),
          ],
        );
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

    return Expanded(
      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
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
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.red.shade600,
                      shape: BoxShape.rectangle,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white, width: 1.5),
                      boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 1))],
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
      ),
    );
  }
}

// Helper async card used above
class _AsyncCard extends StatelessWidget {
  final String title;
  final Stream<QuerySnapshot> stream;
  final Widget Function(QuerySnapshot) builder;
  final Widget? empty;
  const _AsyncCard({required this.title, required this.stream, required this.builder, this.empty});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final emptyWidget = empty ?? const SizedBox.shrink();
    return Card(
      color: cs.surfaceContainerHighest.withOpacity(.6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children:[
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          StreamBuilder<QuerySnapshot>(
            stream: stream,
            builder: (ctx, snap) {
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
  const _PetHeroCard({required this.name, required this.species, required this.lastCheckupText, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      color: cs.surfaceContainerHighest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        leading: CircleAvatar(backgroundColor: cs.primaryContainer, child: const Icon(Icons.pets)),
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(species.isEmpty ? '—' : species),
        trailing: Column(mainAxisAlignment: MainAxisAlignment.center, children:[
          Text('Last check-up', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
          const SizedBox(height: 4),
          Row(mainAxisSize: MainAxisSize.min, children:[const Icon(Icons.event_note, size: 14), const SizedBox(width: 4), Text(lastCheckupText)]),
        ]),
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
        leading: CircleAvatar(backgroundColor: cs.primaryContainer, child: const Icon(Icons.pets)),
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
      stream: FirebaseFirestore.instance.collection('clinics').doc(clinicId).snapshots(),
      builder: (ctx, snap) {
        if (!snap.hasData || !snap.data!.exists) return const SizedBox.shrink();
        final name = (snap.data!.data()!['name'] as String?)?.trim();
        if (name == null || name.isEmpty) return const SizedBox.shrink();
        return InputChip(
          label: Text(name),
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

/* ---------------- CARE CHECKLIST ---------------- */
class _CareChecklist extends StatelessWidget {
  const _CareChecklist();
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      color: cs.surfaceContainerHighest.withOpacity(.6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: const Padding(
        padding: EdgeInsets.fromLTRB(12, 12, 12, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Care checklist', style: TextStyle(fontWeight: FontWeight.w700)),
            SizedBox(height: 8),
            _ChecklistTile(text: 'Keep vaccination card updated after each vet visit.'),
            _ChecklistTile(text: 'Review reminders for deworming and tick/flea prevention.'),
            _ChecklistTile(text: 'Record your pet’s weight and medications after each visit.')
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

/* ---------------- PETS TAB ---------------- */
class _PetsTab extends StatefulWidget {
  const _PetsTab();
  @override
  State<_PetsTab> createState() => _PetsTabState();
}

class _PetsTabState extends State<_PetsTab> {
  String _query = '';
  Timer? _deb;
  @override
  void dispose() { _deb?.cancel(); super.dispose(); }
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
          decoration: const InputDecoration(hintText: 'Search pets by name…', prefixIcon: Icon(Icons.search)),
          onChanged: (v) {
            _deb?.cancel();
            _deb = Timer(const Duration(milliseconds: 300), () { if (!mounted) return; setState(() => _query = v.trim().toLowerCase()); });
          },
        ),
      ),
      Expanded(
        child: StreamBuilder<QuerySnapshot>(
          stream: baseQuery.snapshots(),
          builder: (ctx, snap) {
            if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
            if (!snap.hasData || snap.data!.docs.isEmpty) {
              return const _EmptyPets();
            }
            final items = snap.data!.docs.where((doc) {
              if (_query.isEmpty) return true;
              final name = ((doc.data() as Map)['name'] ?? '') as String;
              return name.toLowerCase().contains(_query);
            }).toList();
            if (items.isEmpty) return const Center(child: Text('No pets match your search.'));
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
                    subtitle: Text('${species.isEmpty ? '' : species}${breed.isEmpty ? '' : ' • $breed'}'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.pushNamed(context, PetDetailScreen.route, arguments: PetDetailArgs(patientId: id, name: name)),
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

/* ---------------- CDSS TAB ---------------- */
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

  List<_CdsSuggestion> _computeSuggestions() {
    final selected = symptoms.entries.where((e) => e.value).map((e) => e.key).toSet();
    final rules = <String, Map<String, dynamic>>{
      'parvovirus': {'species': 'canine', 'symptoms': ['vomiting','diarrhea','lethargy','loss_of_appetite','fever'], 'notes': 'Severe vomiting/diarrhea. Supportive care + vet.'},
      'distemper': {'species': 'canine', 'symptoms': ['cough','nasal_discharge','ocular_discharge','fever','neurologic_signs'], 'notes': 'Respiratory + neuro signs. See vet.'},
      'heartworm': {'species': 'canine', 'symptoms': ['cough','respiratory_distress','lethargy','weight_loss'], 'notes': 'Consider antigen test; exercise restriction.'},
      'feline_leukemia': {'species': 'feline', 'symptoms': ['lethargy','weight_loss','fever','pale_gums'], 'notes': 'FeLV antigen test. Manage infections.'},
      'fiv': {'species': 'feline', 'symptoms': ['weight_loss','fever','lethargy'], 'notes': 'FIV antibody test. Supportive care.'},
      'feline_uri': {'species': 'feline', 'symptoms': ['cough','nasal_discharge','ocular_discharge','fever','loss_of_appetite'], 'notes': 'Supportive care; meds if indicated.'},
    };
    final out = <_CdsSuggestion>[];
    rules.forEach((disease, meta) {
      if (meta['species'] != species) return;
      final need = (meta['symptoms'] as List).cast<String>().toSet();
      final matched = need.intersection(selected).length;
      if (matched > 0) {
        out.add(_CdsSuggestion(
          disease: disease.replaceAll('_', ' ').toUpperCase(),
          score: matched / need.length,
          notes: meta['notes'] as String,
          matched: matched,
          total: need.length,
          source: 'Rules',
        ));
      }
    });
    final aiDiffs = _ai?['differentials'];
    if (aiDiffs is List) {
      for (final d in aiDiffs) {
        final name = (d['name'] ?? '').toString();
        if (name.isEmpty) continue;
        final conf = (d['confidence'] is num) ? (d['confidence'] as num).toDouble() : 0.0;
        final rationale = (d['rationale'] ?? '').toString();
        final idx = out.indexWhere((s) => s.disease.toLowerCase() == name.toLowerCase());
        if (idx >= 0) {
          final m = out[idx];
          out[idx] = m.copyWith(score: m.score > conf ? m.score : conf, notes: '${m.notes}\n\nAI: $rationale', source: 'Rules+AI');
        } else {
          out.add(_CdsSuggestion(disease: name[0].toUpperCase()+name.substring(1), score: conf.clamp(0.0,1.0), notes: 'AI: $rationale', matched: 0, total: 0, source: 'AI'));
        }
      }
    }
    out.sort((a,b)=>b.score.compareTo(a.score));
    return out;
  }

  Future<void> _pickAndAnalyze(ImageSource src) async {
    final picker = ImagePicker();
    final x = await picker.pickImage(source: src, imageQuality: 92, maxWidth: 1800);
    if (x == null) return;
    setState(() { _photo = File(x.path); _ai = null; _loading = true; });
    try {
      final result = await OpenAiVisionService().analyzePetImage(file: _photo!, speciesHint: species);
      setState(() => _ai = result);
      final inferred = (_ai?['inferred_symptoms'] ?? []) as List;
      for (final key in symptoms.keys) {
        final hit = inferred.any((i) => i.toString().toLowerCase() == key.toLowerCase());
        if (hit) symptoms[key] = true;
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Image analysis failed: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showPicker() {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (_) => SafeArea(child: Wrap(children: [
        ListTile(leading: const Icon(Icons.photo_camera), title: const Text('Take photo'), onTap: () { Navigator.pop(context); _pickAndAnalyze(ImageSource.camera); }),
        ListTile(leading: const Icon(Icons.photo_library), title: const Text('Choose from gallery'), onTap: () { Navigator.pop(context); _pickAndAnalyze(ImageSource.gallery); }),
      ])),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final sugg = _computeSuggestions();
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
              onSelectionChanged: (s) => setState(() => species = s.first),
            ),
            FilledButton.icon(
              onPressed: _loading ? null : _showPicker,
              icon: const Icon(Icons.camera_alt_rounded, size: 18),
              label: const Text('Analyze Photo'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_photo != null || _loading || _ai != null)
          Card(
            color: cs.surfaceContainerHighest,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (_photo != null)
                  ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.file(_photo!, height: 180, fit: BoxFit.cover, width: double.infinity)),
                if (_loading) ...[
                  const SizedBox(height: 12), const LinearProgressIndicator(), const SizedBox(height: 6), const Text('Analyzing photo…'),
                ],
                if (!_loading && _ai != null) ...[
                  const SizedBox(height: 12),
                  Text('AI Findings', style: TextStyle(fontWeight: FontWeight.w700, color: cs.primary)),
                  const SizedBox(height: 6),
                  if ((_ai!['findings'] as List?)?.isNotEmpty == true)
                    Wrap(spacing: 8, runSpacing: -8, children: (_ai!['findings'] as List).map((f)=>Chip(label: Text(f.toString()))).toList()),
                  if ((_ai!['red_flags'] as List?)?.isNotEmpty == true) ...[
                    const SizedBox(height: 8), Text('Red flags', style: TextStyle(fontWeight: FontWeight.w600, color: cs.error)), const SizedBox(height: 4),
                    ...(_ai!['red_flags'] as List).map((e)=>Row(crossAxisAlignment: CrossAxisAlignment.start, children:[Icon(Icons.warning_amber_rounded, color: cs.error, size: 16), const SizedBox(width:6), Expanded(child: Text(e.toString()))]))
                  ],
                ],
              ]),
            ),
          ),
        const SizedBox(height: 8),
        Text('Select symptoms', style: TextStyle(fontWeight: FontWeight.w700, color: cs.primary)),
        const SizedBox(height: 6),
        Wrap(spacing: 8, runSpacing: -8, children: symptoms.keys.map((k){ final v = symptoms[k]!; return FilterChip(label: Text(k.replaceAll('_',' ')), selected: v, onSelected: (sel)=>setState(()=>symptoms[k]=sel)); }).toList()),
        const SizedBox(height: 14),
        if (sugg.isEmpty) const Text('No suggestions yet. Select symptoms or analyze a photo.')
        else Column(crossAxisAlignment: CrossAxisAlignment.start, children:[
          const Text('Suggestions', style: TextStyle(fontWeight: FontWeight.bold)), const SizedBox(height: 8),
          ...sugg.map((s)=>Card(child: ListTile(
            leading: CircleAvatar(child: Text('${(s.score*100).round()}%')),
            title: Text(s.disease),
            subtitle: Text(([ if (s.matched>0 && s.total>0) 'Matched ${s.matched}/${s.total}', s.source ]..removeWhere((x)=>x==null || (x is String && x.isEmpty))).join(' • ')),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: (){
              final advice = _firstAidAdvice(s.disease, species);
              showModalBottomSheet(
                context: context,
                showDragHandle: true,
                builder: (_)=>Padding(
                  padding: const EdgeInsets.all(16),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children:[
                        Text(s.disease, style: Theme.of(context).textTheme.titleLarge),
                        const SizedBox(height:8),
                        Text(s.notes),
                        const SizedBox(height:12),
                        Text('First Aid', style: TextStyle(fontWeight: FontWeight.w700, color: Theme.of(context).colorScheme.primary)),
                        const SizedBox(height:6),
                        Text(advice),
                      ],
                    ),
                  ),
                ),
              );
            },
          )))
        ]),
        const SizedBox(height: 24),
        CDSSChatBox(species: species, firstAidOnly: true),
      ]),
    );
  }
}

class _CdsSuggestion {
  final String disease; final double score; final String notes; final int matched; final int total; final String source;
  _CdsSuggestion({required this.disease, required this.score, required this.notes, required this.matched, required this.total, required this.source});
  _CdsSuggestion copyWith({String? disease,double? score,String? notes,int? matched,int? total,String? source})=> _CdsSuggestion(disease: disease??this.disease, score: score??this.score, notes: notes??this.notes, matched: matched??this.matched, total: total??this.total, source: source??this.source);
}

String _firstAidAdvice(String disease, String species) {
  final d = disease.toLowerCase();
  if (d.contains('parvo') || d.contains('parvovirus')) {
    return 'Isolate your pet, keep them warm, offer small sips of clean water or oral rehydration, and clean up vomit/stool promptly. Go to the vet immediately if vomiting/diarrhea persists, stool is bloody, or your pet is weak.';
  }
  if (d.contains('distemper')) {
    return 'Limit activity, keep your dog warm and hydrated, wipe nasal/eye discharge with clean cloths, and avoid contact with other dogs. See a vet urgently if breathing is labored, seizures or twitching appear, or appetite stops.';
  }
  if (d.contains('heartworm')) {
    return 'Strict rest and no exercise to reduce strain on the heart and lungs. Provide calm, cool environment and fresh water. See your vet quickly for testing and staging—do not start exercise until cleared.';
  }
  if (d.contains('feline') && d.contains('uri')) {
    return 'Use a steamy bathroom or humidifier to ease congestion, gently clean eye/nose discharge, offer warmed aromatic food and fresh water. See a vet if breathing is difficult, eyes are swollen, or the cat stops eating.';
  }
  if (d.contains('fiv') || d.contains('feline leukemia') || d.contains('leukemia')) {
    return 'Keep your cat indoors, reduce stress, ensure clean water and palatable food, and monitor gums/breathing. Schedule a vet visit to confirm diagnosis and manage secondary infections.';
  }
  return 'Keep your ${species == 'canine' ? 'dog' : 'cat'} rested, hydrated with small frequent sips of water, and monitor breathing, appetite, and energy. Seek a vet promptly if breathing is hard, gums are pale/blue, vomiting/diarrhea persists, or your pet becomes weak.';
}

// Small helper used in greeting
String _partOfDay() {
  final h = DateTime.now().hour;
  if (h < 12) return 'morning';
  if (h < 18) return 'afternoon';
  return 'evening';
}
