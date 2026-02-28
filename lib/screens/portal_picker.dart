import 'package:flutter/material.dart';

import 'login_screen.dart';
import 'create_account_screen.dart';
import 'admin/admin_login_screen.dart';

class PortalPicker extends StatefulWidget {
  static const route = '/portal';
  const PortalPicker({super.key});

  @override
  State<PortalPicker> createState() => _PortalPickerState();
}

class _PortalPickerState extends State<PortalPicker> {
  static const _logoAsset = 'lib/assets/logo.png';
  int _secretTap = 0;

  void _triggerAdminAccess() {
    _secretTap++;
    if (_secretTap >= 5) {
      _secretTap = 0;
      Navigator.pushNamed(context, AdminLoginScreen.route);
    } else {
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) _secretTap = 0;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    Widget tile({
      required IconData leading,
      required String title,
      required String subtitle,
      required IconData trailing,
      required VoidCallback onTap,
      Color? tint,
    }) {
      return InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 8),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: (tint ?? cs.primary).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(leading, color: tint ?? cs.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(subtitle, style: TextStyle(color: cs.onSurfaceVariant)),
                  ],
                ),
              ),
              Icon(trailing, color: cs.onSurfaceVariant),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Choose Portal'),
        actions: [
          IconButton(
            tooltip: 'Support',
            onPressed: () => Navigator.pushNamed(context, AdminLoginScreen.route),
            icon: Icon(Icons.admin_panel_settings_outlined, color: cs.onSurfaceVariant.withValues(alpha: 0.4)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Image.asset(
                    _logoAsset,
                    width: 64,
                    height: 64,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: cs.primaryContainer,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(Icons.pets_rounded, color: cs.primary),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'VetAssist',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: cs.onSurface,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'One app for pet owners and clinics',
                        style: TextStyle(
                          color: cs.onSurfaceVariant,
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: LinearGradient(
                colors: [
                  cs.primaryContainer.withValues(alpha: 0.85),
                  cs.secondaryContainer.withValues(alpha: 0.75),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Why use VetAssist?',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: cs.onPrimaryContainer,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Faster pet care, clearer communication, and organized records in one app.',
                  style: TextStyle(
                    color: cs.onPrimaryContainer.withValues(alpha: 0.92),
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 10),
                _PromoBullet(
                  text: 'Book visits, track reminders, and chat with your clinic anytime.',
                  color: cs.onPrimaryContainer,
                ),
                _PromoBullet(
                  text: 'For staff: manage appointments, patient records, and customer messages in one workflow.',
                  color: cs.onPrimaryContainer,
                ),
                _PromoBullet(
                  text: 'Real-time notifications so you never miss important updates.',
                  color: cs.onPrimaryContainer,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          tile(
            leading: Icons.play_arrow_rounded,
            title: 'Customer',
            subtitle: 'Pet owner portal',
            trailing: Icons.pets_outlined,
            onTap: () => Navigator.pushNamed(context, CustomerLoginScreen.route),
          ),
          tile(
            leading: Icons.play_arrow_rounded,
            title: 'Staff / Vet',
            subtitle: 'Clinic portal',
            trailing: Icons.badge_outlined,
            onTap: () => Navigator.pushNamed(context, StaffLoginScreen.route),
          ),
          const SizedBox(height: 24),
          Center(
            child: Column(
              children: [
                TextButton(
                  onPressed: () => Navigator.pushNamed(
                    context,
                    CreateAccountScreen.route,
                    arguments: 'customer',
                  ),
                  child: const Text('Create a new account'),
                ),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: _triggerAdminAccess,
                  child: Text(
                    'Need elevated support?',
                    style: TextStyle(
                      fontSize: 12,
                      color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PromoBullet extends StatelessWidget {
  final String text;
  final Color color;
  const _PromoBullet({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.check_circle_rounded, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: color),
            ),
          ),
        ],
      ),
    );
  }
}
