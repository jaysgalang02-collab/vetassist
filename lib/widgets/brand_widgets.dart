import 'package:flutter/material.dart';

import '../theme/vet_theme.dart';

class BrandLogo extends StatelessWidget {
  final double size;
  const BrandLogo({super.key, this.size = 60});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'VetAssist logo',
      image: true,
      child: Container(
        width: size,
        height: size,
        padding: EdgeInsets.all(size * 0.08),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(size * 0.28),
          border: Border.all(color: VetTheme.mint),
        ),
        child: Image.asset(
          'lib/assets/logo.png',
          fit: BoxFit.contain,
          excludeFromSemantics: true,
          errorBuilder: (context, error, stackTrace) => Icon(Icons.pets_rounded,
              size: size * 0.5, color: VetTheme.forest),
        ),
      ),
    );
  }
}

class Entrance extends StatelessWidget {
  final Widget child;
  final int milliseconds;
  const Entrance({super.key, required this.child, this.milliseconds = 420});

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: milliseconds),
      curve: Curves.easeOutCubic,
      child: child,
      builder: (context, progress, child) => Opacity(
        opacity: progress,
        child: Transform.translate(
            offset: Offset(0, 16 * (1 - progress)), child: child),
      ),
    );
  }
}

class ContentFrame extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  const ContentFrame({super.key, required this.child, this.maxWidth = 620});

  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth), child: child),
      );
}

class AdaptiveActions extends StatelessWidget {
  final List<Widget> children;
  const AdaptiveActions({super.key, required this.children});

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          final columns = constraints.maxWidth >= 360 &&
                  MediaQuery.textScalerOf(context).scale(14) <= 20
              ? 2
              : 1;
          final width = (constraints.maxWidth - (columns - 1) * 12) / columns;
          return Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final child in children) SizedBox(width: width, child: child)
            ],
          );
        },
      );
}

class CareHero extends StatelessWidget {
  final String eyebrow;
  final String title;
  final String subtitle;
  final Widget? action;
  const CareHero(
      {super.key,
      required this.eyebrow,
      required this.title,
      required this.subtitle,
      this.action});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
            colors: [VetTheme.forest, Color(0xFF286A51)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(eyebrow,
              style: const TextStyle(
                  color: Color(0xFFD5EDDF),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5)),
          const SizedBox(height: 14),
          Text(title,
              style: Theme.of(context)
                  .textTheme
                  .headlineMedium
                  ?.copyWith(color: Colors.white)),
          const SizedBox(height: 10),
          Text(subtitle,
              style: const TextStyle(color: Color(0xFFE1EDE6), height: 1.5)),
          if (action != null) ...[const SizedBox(height: 20), action!],
        ],
      ),
    );
  }
}

class PortalAction extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
  const PortalAction(
      {super.key,
      required this.title,
      required this.subtitle,
      required this.icon,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: VetTheme.mint,
                  borderRadius: BorderRadius.circular(16)),
              child: Icon(icon, color: VetTheme.forest),
            ),
            const SizedBox(width: 16),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 3),
                  Text(subtitle,
                      style: TextStyle(
                          color:
                              Theme.of(context).colorScheme.onSurfaceVariant)),
                ])),
            const SizedBox(width: 8),
            const Icon(Icons.arrow_forward_rounded,
                color: VetTheme.forest, size: 20),
          ]),
        ),
      ),
    );
  }
}

class MotionTabStack extends StatefulWidget {
  final int index;
  final List<Widget> children;
  const MotionTabStack(
      {super.key, required this.index, required this.children});

  @override
  State<MotionTabStack> createState() => _MotionTabStackState();
}

class _MotionTabStackState extends State<MotionTabStack>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 220), value: 1);

  @override
  void didUpdateWidget(covariant MotionTabStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.index != widget.index) {
      FocusManager.instance.primaryFocus?.unfocus();
      if (MediaQuery.disableAnimationsOf(context)) {
        _controller.value = 1;
      } else {
        _controller.forward(from: 0);
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
        opacity: _controller,
        child: IndexedStack(
          index: widget.index,
          children: [
            for (var index = 0; index < widget.children.length; index++)
              TickerMode(
                  enabled: index == widget.index, child: widget.children[index])
          ],
        ),
      );
}
