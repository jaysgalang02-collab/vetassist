import 'package:flutter/material.dart';
import '../../theme/vet_theme.dart';
import '../../widgets/brand_widgets.dart';

const adminLabels = ['Overview', 'Customers', 'Pets', 'Team', 'Clinics'];
const adminIcons = [
  Icons.space_dashboard_outlined,
  Icons.people_outline_rounded,
  Icons.pets_outlined,
  Icons.badge_outlined,
  Icons.local_hospital_outlined,
];

class AdminWorkspace extends StatelessWidget {
  final int index;
  final ValueChanged<int> onSelect;
  final VoidCallback onSignOut;
  final VoidCallback onCreateClinic;
  final VoidCallback? onSettings;
  final List<Widget> pages;
  const AdminWorkspace(
      {super.key,
      required this.index,
      required this.onSelect,
      required this.onSignOut,
      required this.onCreateClinic,
      this.onSettings,
      required this.pages});

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, size) {
        final wide = size.maxWidth >= 900;
        final largeText = MediaQuery.textScalerOf(context).scale(14) > 20;
        return Scaffold(
          appBar: AppBar(
            toolbarHeight: 76,
            title: Row(children: [
              const BrandLogo(size: 42),
              const SizedBox(width: 12),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    const Text('VetAssist',
                        style: TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 19)),
                    Text('ADMIN WORKSPACE',
                        style: TextStyle(
                            fontSize: 9,
                            letterSpacing: 1.8,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant)),
                  ])),
            ]),
            actions: [
              if (onSettings != null)
                IconButton(
                    onPressed: onSettings,
                    tooltip: 'App settings',
                    icon: const Icon(Icons.settings_outlined)),
              IconButton(
                  onPressed: onSignOut,
                  tooltip: 'Sign out',
                  icon: const Icon(Icons.logout_rounded)),
              const SizedBox(width: 12)
            ],
          ),
          body: SafeArea(
              top: false,
              child: Row(children: [
                if (wide)
                  Container(
                    width: 216,
                    margin: const EdgeInsets.fromLTRB(20, 8, 0, 20),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(26),
                        border: Border.all(color: const Color(0xFFE1E8E2))),
                    child: Column(children: [
                      const Padding(
                          padding: EdgeInsets.fromLTRB(12, 16, 12, 18),
                          child: Align(
                              alignment: Alignment.centerLeft,
                              child: Text('MANAGE',
                                  style: TextStyle(
                                      fontSize: 10,
                                      letterSpacing: 1.8,
                                      color: Color(0xFF67786D))))),
                      for (var i = 0; i < adminLabels.length; i++)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: AnimatedContainer(
                              duration: Duration(
                                  milliseconds:
                                      MediaQuery.disableAnimationsOf(context)
                                          ? 0
                                          : 240),
                              decoration: BoxDecoration(
                                  color: i == index
                                      ? VetTheme.mint
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(16)),
                              child: ListTile(
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16)),
                                  leading: Icon(adminIcons[i],
                                      color: i == index
                                          ? VetTheme.forest
                                          : const Color(0xFF67786D)),
                                  title: Text(adminLabels[i],
                                      style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: i == index
                                              ? FontWeight.w700
                                              : FontWeight.w500)),
                                  onTap: () => onSelect(i))),
                        ),
                      const Spacer(),
                      const Padding(
                          padding: EdgeInsets.all(12),
                          child: Text(
                              'Better care starts with\na connected team.',
                              style: TextStyle(
                                  fontSize: 12,
                                  height: 1.6,
                                  color: Color(0xFF67786D)))),
                    ]),
                  ),
                Expanded(
                    child: ContentFrame(
                        maxWidth: 1200,
                        child: _PageMotion(index: index, children: pages))),
              ])),
          bottomNavigationBar: wide ||
                  MediaQuery.viewInsetsOf(context).bottom > 0
              ? null
              : NavigationBar(
                  selectedIndex: index,
                  labelBehavior: largeText
                      ? NavigationDestinationLabelBehavior.onlyShowSelected
                      : NavigationDestinationLabelBehavior.alwaysShow,
                  animationDuration: Duration(
                      milliseconds:
                          MediaQuery.disableAnimationsOf(context) ? 0 : 320),
                  onDestinationSelected: onSelect,
                  destinations: [
                    for (var i = 0; i < adminLabels.length; i++)
                      NavigationDestination(
                          icon: Icon(adminIcons[i]), label: adminLabels[i])
                  ],
                ),
          floatingActionButton: index == 4
              ? FloatingActionButton.extended(
                  onPressed: onCreateClinic,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('New clinic'))
              : null,
        );
      });
}

class _PageMotion extends StatefulWidget {
  final int index;
  final List<Widget> children;
  const _PageMotion({required this.index, required this.children});
  @override
  State<_PageMotion> createState() => _PageMotionState();
}

class _PageMotionState extends State<_PageMotion>
    with SingleTickerProviderStateMixin {
  late final AnimationController _motion = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 320), value: 1);
  late final Animation<double> _curve =
      CurvedAnimation(parent: _motion, curve: Curves.easeOutCubic);
  @override
  void didUpdateWidget(covariant _PageMotion oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.index != widget.index) {
      FocusManager.instance.primaryFocus?.unfocus();
      if (MediaQuery.disableAnimationsOf(context)) {
        _motion.value = 1;
      } else {
        _motion.forward(from: 0);
      }
    }
  }

  @override
  void dispose() {
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
      opacity: _curve,
      child: SlideTransition(
          position:
              Tween<Offset>(begin: const Offset(0, 0.025), end: Offset.zero)
                  .animate(_curve),
          child: IndexedStack(index: widget.index, children: [
            for (var i = 0; i < widget.children.length; i++)
              TickerMode(enabled: i == widget.index, child: widget.children[i]),
          ])));
}

class AdminOverview extends StatelessWidget {
  final List<int?> totals;
  final List<String> clinics;
  final int? activeClinics;
  final String name;
  final ValueChanged<int> onSelect;
  final VoidCallback onCreateClinic;
  final bool hasError;
  const AdminOverview(
      {super.key,
      required this.totals,
      required this.clinics,
      required this.activeClinics,
      required this.name,
      required this.onSelect,
      required this.onCreateClinic,
      this.hasError = false});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        children: [
          Entrance(
              child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                gradient: const LinearGradient(
                    colors: [Color(0xFF103D30), Color(0xFF2B7056)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight),
                boxShadow: [
                  BoxShadow(
                      color: VetTheme.forest.withValues(alpha: 0.13),
                      blurRadius: 24,
                      offset: const Offset(0, 10))
                ]),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Row(children: [
                Icon(Icons.shield_outlined, color: Color(0xFFBFE2CF), size: 18),
                SizedBox(width: 8),
                Expanded(
                    child: Text('YOUR CARE NETWORK',
                        style: TextStyle(
                            color: Color(0xFFBFE2CF),
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.8)))
              ]),
              const SizedBox(height: 22),
              Text('Welcome back, $name.',
                  style: theme.textTheme.headlineMedium
                      ?.copyWith(color: Colors.white)),
              const SizedBox(height: 10),
              const Text(
                  'One place to connect your clinics, people, and patient care.',
                  style: TextStyle(color: Color(0xFFDCECE3), height: 1.6)),
              const SizedBox(height: 22),
              FilledButton.icon(
                  onPressed: onCreateClinic,
                  style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFE1F0DC),
                      foregroundColor: VetTheme.forest),
                  icon: const Icon(Icons.add_business_outlined, size: 20),
                  label: const Text('Register a clinic')),
            ]),
          )),
          const SizedBox(height: 28),
          Text('At a glance', style: theme.textTheme.titleLarge),
          const SizedBox(height: 6),
          Text(
              hasError
                  ? 'Some totals are unavailable. Check your connection or account permissions.'
                  : 'A live view of your care community.',
              style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
          const SizedBox(height: 16),
          LayoutBuilder(builder: (context, size) {
            final columns = size.maxWidth >= 760
                ? 4
                : (size.maxWidth >= 300 &&
                        MediaQuery.textScalerOf(context).scale(14) < 23
                    ? 2
                    : 1);
            final width = (size.maxWidth - 12 * (columns - 1)) / columns;
            return Wrap(spacing: 12, runSpacing: 12, children: [
              for (var i = 0; i < 4; i++)
                SizedBox(
                    width: width,
                    child: Entrance(
                        milliseconds: 420 + i * 70,
                        child: _Metric(
                            label: adminLabels[i + 1],
                            icon: adminIcons[i + 1],
                            value: totals[i],
                            onTap: () => onSelect(i + 1)))),
            ]);
          }),
          const SizedBox(height: 28),
          Text('Quick access', style: theme.textTheme.titleLarge),
          const SizedBox(height: 12),
          AdaptiveActions(children: [
            _QuickAction(
                icon: Icons.manage_accounts_outlined,
                title: 'Manage your team',
                subtitle: 'Roles and clinic assignments',
                onTap: () => onSelect(3)),
            _QuickAction(
                icon: Icons.people_outline,
                title: 'Customer directory',
                subtitle: 'People across your network',
                onTap: () => onSelect(1)),
          ]),
          const SizedBox(height: 28),
          Row(children: [
            Expanded(
                child:
                    Text('Clinic network', style: theme.textTheme.titleLarge)),
            TextButton(
                onPressed: () => onSelect(4), child: const Text('View all'))
          ]),
          const SizedBox(height: 8),
          Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: theme.colorScheme.outlineVariant)),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AdminBadge(
                        label: activeClinics == null
                            ? 'Status unavailable'
                            : '$activeClinics active clinics'),
                    const SizedBox(height: 16),
                    if (clinics.isEmpty)
                      Text(
                          totals[3] == null
                              ? 'Your clinic network will appear here.'
                              : 'Start your network by registering your first clinic.',
                          style: theme.textTheme.bodyMedium),
                    for (final clinic in clinics.take(3))
                      Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Row(children: [
                            const _RecordIcon(
                                icon: Icons.local_hospital_outlined),
                            const SizedBox(width: 12),
                            Expanded(
                                child: Text(clinic,
                                    style: theme.textTheme.titleMedium))
                          ])),
                  ])),
        ]);
  }
}

class _Metric extends StatelessWidget {
  final String label;
  final IconData icon;
  final int? value;
  final VoidCallback onTap;
  const _Metric(
      {required this.label,
      required this.icon,
      required this.value,
      required this.onTap});
  @override
  Widget build(BuildContext context) => Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side:
              BorderSide(color: Theme.of(context).colorScheme.outlineVariant)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
          onTap: onTap,
          child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Icon(icon, color: VetTheme.forest, size: 22),
                      const Spacer(),
                      const Icon(Icons.north_east_rounded,
                          size: 16, color: Color(0xFF899A90))
                    ]),
                    const SizedBox(height: 18),
                    TweenAnimationBuilder<double>(
                        key: ValueKey(value),
                        tween: Tween(begin: 0, end: (value ?? 0).toDouble()),
                        duration: Duration(
                            milliseconds:
                                MediaQuery.disableAnimationsOf(context)
                                    ? 0
                                    : 600),
                        curve: Curves.easeOutCubic,
                        builder: (context, count, _) => Text(
                            value == null ? '—' : '${count.round()}',
                            style: const TextStyle(
                                fontSize: 30,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -1,
                                color: VetTheme.ink))),
                    const SizedBox(height: 4),
                    Text(label,
                        style: TextStyle(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant)),
                  ]))));
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  final VoidCallback onTap;
  const _QuickAction(
      {required this.icon,
      required this.title,
      required this.subtitle,
      required this.onTap});
  @override
  Widget build(BuildContext context) => Material(
      color: const Color(0xFFEAF0E9),
      borderRadius: BorderRadius.circular(22),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
          onTap: onTap,
          child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(icon, color: VetTheme.forest),
                    const SizedBox(height: 16),
                    Text(title, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text(subtitle,
                        style: const TextStyle(
                            fontSize: 12, color: Color(0xFF5C6D64))),
                  ]))));
}

class AdminBadge extends StatelessWidget {
  final String label;
  final bool muted;
  const AdminBadge({super.key, required this.label, this.muted = false});
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
          color: muted ? const Color(0xFFF0F1ED) : VetTheme.mint,
          borderRadius: BorderRadius.circular(9)),
      child: Text(label,
          style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: muted ? const Color(0xFF67786D) : VetTheme.forest)));
}

class _RecordIcon extends StatelessWidget {
  final IconData icon;
  const _RecordIcon({required this.icon});
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: VetTheme.mint, borderRadius: BorderRadius.circular(14)),
      child: Icon(icon, size: 22, color: VetTheme.forest));
}

class AdminRecordCard extends StatelessWidget {
  final String title, subtitle;
  final IconData icon;
  final Widget? badge, actions;
  const AdminRecordCard(
      {super.key,
      required this.title,
      required this.subtitle,
      required this.icon,
      this.badge,
      this.actions});
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border:
              Border.all(color: Theme.of(context).colorScheme.outlineVariant)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _RecordIcon(icon: icon),
          const SizedBox(width: 14),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 5),
                Text(subtitle,
                    style: TextStyle(
                        fontSize: 12,
                        height: 1.6,
                        color: Theme.of(context).colorScheme.onSurfaceVariant)),
              ])),
        ]),
        if (badge != null || actions != null) ...[
          const SizedBox(height: 12),
          Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (badge != null) badge!,
                if (actions != null) actions!
              ])
        ],
      ]));
}

class AdminState extends StatelessWidget {
  final String title, message;
  final bool error;
  const AdminState(
      {super.key,
      required this.title,
      required this.message,
      this.error = false});
  @override
  Widget build(BuildContext context) => Center(
      child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(error ? Icons.cloud_off_rounded : Icons.search_rounded,
                size: 42, color: VetTheme.forest),
            const SizedBox(height: 18),
            Text(title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(message,
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ])));
}
