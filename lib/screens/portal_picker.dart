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
            color: cs.surfaceContainerHighest.withOpacity(.6),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: (tint ?? cs.primary).withOpacity(.2),
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
            icon: Icon(Icons.admin_panel_settings_outlined, color: cs.onSurfaceVariant.withOpacity(.4)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
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
                      color: cs.onSurfaceVariant.withOpacity(.6),
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
