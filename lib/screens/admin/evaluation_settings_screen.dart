import 'package:flutter/material.dart';
import '../../services/evaluation_settings_service.dart';
import '../../widgets/brand_widgets.dart';
import '../../widgets/evaluation_card.dart';

class EvaluationSettingsScreen extends StatefulWidget {
  final Future<EvaluationSettings> Function()? load;
  final Future<void> Function(EvaluationSettings)? save;
  const EvaluationSettingsScreen({super.key, this.load, this.save});
  @override
  State<EvaluationSettingsScreen> createState() =>
      _EvaluationSettingsScreenState();
}

class _EvaluationSettingsScreenState extends State<EvaluationSettingsScreen> {
  final _url = TextEditingController();
  final _form = GlobalKey<FormState>();
  late Future<EvaluationSettings> _loading;
  EvaluationSettings _saved = const EvaluationSettings();
  bool _enabled = false;
  bool _saving = false;
  String? _saveError;
  bool get _dirty =>
      _url.text.trim() != _saved.url || _enabled != _saved.enabled;

  @override
  void initState() {
    super.initState();
    _loading = _load();
  }

  Future<EvaluationSettings> _load() async {
    final settings =
        await (widget.load?.call() ?? EvaluationSettingsService().load());
    if (mounted) {
      _saved = settings;
      _url.text = settings.url;
      _enabled = settings.enabled;
    }
    return settings;
  }

  @override
  void dispose() {
    _url.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate() || _saving) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _saving = true;
      _saveError = null;
    });
    final settings =
        EvaluationSettings(url: _url.text.trim(), enabled: _enabled);
    try {
      await (widget.save?.call(settings) ??
              EvaluationSettingsService().save(settings))
          .timeout(const Duration(seconds: 20));
      if (!mounted) return;
      setState(() => _saved = settings);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(settings.enabled
              ? 'Evaluation link saved. Users can now open your form.'
              : 'Settings saved. Evaluation is hidden from users.')));
    } catch (_) {
      if (mounted) {
        setState(() => _saveError =
            'We could not confirm your changes were saved. Check your connection and administrator access, then try again.');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _confirmLeave() async {
    if (_saving) return;
    final discard = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
              title: const Text('Discard unsaved changes?'),
              content: const Text(
                  'Save your changes to update the evaluation link for users.'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Keep editing')),
                FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Discard')),
              ],
            ));
    if (discard == true && mounted) {
      setState(() {
        _url.text = _saved.url;
        _enabled = _saved.enabled;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.pop(context);
      });
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
        canPop: !_dirty && !_saving,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop) _confirmLeave();
        },
        child: Scaffold(
          appBar: AppBar(title: const Text('App settings')),
          body: SafeArea(
              child: ContentFrame(
                  child: FutureBuilder<EvaluationSettings>(
            future: _loading,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(
                    child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.cloud_off_outlined, size: 40),
                            const SizedBox(height: 16),
                            const Text('Settings could not be loaded.',
                                textAlign: TextAlign.center),
                            const SizedBox(height: 12),
                            FilledButton.icon(
                                onPressed: () => setState(() {
                                      _loading = _load();
                                    }),
                                icon: const Icon(Icons.refresh_rounded),
                                label: const Text('Try again')),
                          ],
                        )));
              }
              return Form(key: _form, child: _editor(context));
            },
          ))),
        ),
      );

  Widget _editor(BuildContext context) {
    final validUri = googleFormUri(_url.text);
    return SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Entrance(
              child: CareHero(
                  eyebrow: 'LISTEN TO YOUR USERS',
                  title: 'App evaluation',
                  subtitle:
                      'Connect your Google Form and invite customers to share their VetAssist experience.')),
          const SizedBox(height: 24),
          Text('Google Form link',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          const Text(
              'Paste the respondent link from your form. Users will see it on Home and Profile.'),
          const SizedBox(height: 16),
          TextFormField(
            controller: _url,
            enabled: !_saving,
            keyboardType: TextInputType.url,
            textInputAction: TextInputAction.done,
            autocorrect: false,
            enableSuggestions: false,
            maxLines: 3,
            minLines: 1,
            decoration: const InputDecoration(
                labelText: 'Evaluation link',
                hintText: 'https://forms.gle/...',
                prefixIcon: Icon(Icons.link_rounded)),
            onChanged: (_) => setState(() => _saveError = null),
            validator: (value) {
              if ((value ?? '').trim().isEmpty) {
                return _enabled
                    ? 'Add a link before enabling evaluation.'
                    : null;
              }
              return googleFormUri(value!) == null
                  ? 'Use a Google Forms respondent link with https.'
                  : null;
            },
          ),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(20)),
            child: SwitchListTile.adaptive(
              title: const Text('Show evaluation to users'),
              subtitle: Text(_enabled
                  ? 'Visible after you save changes'
                  : 'Hidden from Home and Profile'),
              value: _enabled,
              onChanged: _saving
                  ? null
                  : (value) => setState(() {
                        _enabled = value;
                        _saveError = null;
                      }),
            ),
          ),
          const SizedBox(height: 24),
          Text('Customer preview',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          EvaluationInvitation(
              onOpen: validUri == null || _saving
                  ? null
                  : () => openEvaluationForm(context, validUri)),
          const SizedBox(height: 16),
          Text(
              'Make sure the form is published and accepting responses. Preview the link to check it before saving.',
              style: Theme.of(context).textTheme.bodySmall),
          if (_saveError != null) ...[
            const SizedBox(height: 16),
            Text(_saveError!,
                style: TextStyle(color: Theme.of(context).colorScheme.error))
          ],
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _saving || !_dirty ? null : _save,
            icon: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.check_rounded),
            label: Text(_saving ? 'Saving changes...' : 'Save changes'),
          ),
        ]));
  }
}
