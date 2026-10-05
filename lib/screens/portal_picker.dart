import 'package:flutter/material.dart';

import '../widgets/brand_widgets.dart';
import 'login_screen.dart';
import 'create_account_screen.dart';
import 'admin/admin_login_screen.dart';

class PortalPicker extends StatelessWidget {
  static const route = '/portal';
  const PortalPicker({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('VetAssist'),
        actions: [
          IconButton(
            tooltip: 'Administrator sign in',
            onPressed: () =>
                Navigator.pushNamed(context, AdminLoginScreen.route),
            icon: const Icon(Icons.admin_panel_settings_outlined),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: ContentFrame(
          maxWidth: 1040,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
            child: LayoutBuilder(builder: (context, constraints) {
              final intro = Entrance(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const BrandLogo(size: 64),
                      const SizedBox(height: 18),
                      Text('A little care.\nA happier companion.',
                          style: theme.textTheme.headlineMedium),
                      const SizedBox(height: 12),
                      Text(
                          'Keep your pet\'s care close. Connect with your clinic, plan a visit, and stay on top of the little things.',
                          style: theme.textTheme.bodyLarge?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant)),
                    ]),
              );
              final choices = Entrance(
                milliseconds: 560,
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('How will you use VetAssist?',
                          style: theme.textTheme.titleLarge),
                      const SizedBox(height: 6),
                      Text('Choose your space to get started.',
                          style: TextStyle(
                              color: theme.colorScheme.onSurfaceVariant)),
                      const SizedBox(height: 14),
                      PortalAction(
                        title: 'Pet owner',
                        subtitle:
                            'Book visits, view records, and message your clinic.',
                        icon: Icons.pets_rounded,
                        onTap: () => Navigator.pushNamed(
                            context, CustomerLoginScreen.route),
                      ),
                      PortalAction(
                        title: 'Staff / Vet',
                        subtitle:
                            'Manage patients, appointments, and conversations.',
                        icon: Icons.medical_services_outlined,
                        onTap: () => Navigator.pushNamed(
                            context, StaffLoginScreen.route),
                      ),
                      const SizedBox(height: 18),
                      FilledButton.icon(
                        onPressed: () => Navigator.pushNamed(
                            context, CreateAccountScreen.route,
                            arguments: 'customer'),
                        icon: const Icon(Icons.person_add_alt_1_rounded),
                        label: const Text('Create a pet owner account',
                            textAlign: TextAlign.center),
                      ),
                      const SizedBox(height: 12),
                      Text(
                          'Already registered? Select your portal above to sign in.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant)),
                      const SizedBox(height: 24),
                      Wrap(spacing: 8, runSpacing: 8, children: const [
                        _Benefit(
                            icon: Icons.calendar_month_outlined,
                            label: 'Easy booking'),
                        _Benefit(
                            icon: Icons.chat_bubble_outline_rounded,
                            label: 'Clinic chat'),
                        _Benefit(
                            icon: Icons.favorite_border_rounded,
                            label: 'Care reminders'),
                      ]),
                    ]),
              );
              if (constraints.maxWidth >= 800) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 48),
                  child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: intro),
                        const SizedBox(width: 64),
                        Expanded(child: choices),
                      ]),
                );
              }
              return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [intro, const SizedBox(height: 32), choices]);
            }),
          ),
        ),
      ),
    );
  }
}

class _Benefit extends StatelessWidget {
  final IconData icon;
  final String label;
  const _Benefit({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(30)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 16, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 6),
          Flexible(
              child: Text(label,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.primary))),
        ]),
      );
}
