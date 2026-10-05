import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/evaluation_settings_service.dart';
import 'brand_widgets.dart';

Future<void> openEvaluationForm(BuildContext context, Uri uri) async {
  try {
    if (await launchUrl(uri, mode: LaunchMode.externalApplication)) return;
  } catch (_) {}
  if (!context.mounted) return;
  await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
            title: const Text('Open evaluation form'),
            content: const Text(
                'We could not open your browser. Copy the link and paste it into your browser to continue.'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Close')),
              FilledButton.icon(
                  onPressed: () async {
                    await Clipboard.setData(
                        ClipboardData(text: uri.toString()));
                    if (!dialogContext.mounted) return;
                    Navigator.pop(dialogContext);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text('Evaluation link copied.')));
                    }
                  },
                  icon: const Icon(Icons.copy_rounded),
                  label: const Text('Copy link')),
            ],
          ));
}

class EvaluationCard extends StatefulWidget {
  final double topPadding;
  final Stream<EvaluationSettings>? settingsStream;
  const EvaluationCard({super.key, this.topPadding = 0, this.settingsStream});
  @override
  State<EvaluationCard> createState() => _EvaluationCardState();
}

class _EvaluationCardState extends State<EvaluationCard> {
  late final _stream =
      widget.settingsStream ?? EvaluationSettingsService().watch();
  @override
  Widget build(BuildContext context) => StreamBuilder<EvaluationSettings>(
        stream: _stream,
        builder: (context, snapshot) {
          final uri = snapshot.hasError ? null : snapshot.data?.publicUri;
          return AnimatedSize(
            duration: Duration(
                milliseconds:
                    MediaQuery.disableAnimationsOf(context) ? 0 : 280),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: uri == null
                ? const SizedBox.shrink()
                : Padding(
                    padding: EdgeInsets.only(top: widget.topPadding),
                    child: EvaluationInvitation(
                        onOpen: () => openEvaluationForm(context, uri)),
                  ),
          );
        },
      );
}

class EvaluationInvitation extends StatelessWidget {
  final VoidCallback? onOpen;
  const EvaluationInvitation({super.key, this.onOpen});
  @override
  Widget build(BuildContext context) => Entrance(
          child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: const LinearGradient(
              colors: [Color(0xFFF0F7F2), Color(0xFFE4F0E9)]),
          border: Border.all(color: const Color(0xFFD1E3D8)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Icon(Icons.rate_review_outlined,
              color: Color(0xFF1F664D), size: 28),
          const SizedBox(height: 12),
          Text('Help shape better pet care',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          const Text(
              'Share your experience with VetAssist. Your feedback helps us improve the app.',
              style: TextStyle(height: 1.5)),
          const SizedBox(height: 16),
          OutlinedButton.icon(
              onPressed: onOpen,
              icon: const Icon(Icons.open_in_new_rounded, size: 18),
              label: const Text('Evaluate VetAssist')),
          const SizedBox(height: 4),
          Text('Opens a Google Form in your browser',
              style: Theme.of(context).textTheme.bodySmall),
        ]),
      ));
}
