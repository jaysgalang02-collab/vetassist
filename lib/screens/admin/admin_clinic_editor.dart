import 'package:flutter/material.dart';

class AdminClinicEditor extends StatefulWidget {
  final Map<String, dynamic>? initial;
  final Future<void> Function(Map<String, dynamic>) onSave;
  const AdminClinicEditor({super.key, this.initial, required this.onSave});
  @override
  State<AdminClinicEditor> createState() => _AdminClinicEditorState();
}

class _AdminClinicEditorState extends State<AdminClinicEditor> {
  final _form = GlobalKey<FormState>();
  late final Map<String, TextEditingController> _fields = {
    for (final field in ['name', 'address', 'phone', 'email', 'hours'])
      field:
          TextEditingController(text: widget.initial?[field] as String? ?? ''),
  };
  late bool _active = widget.initial?['active'] as bool? ?? true;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    for (final controller in _fields.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.onSave({
        for (final entry in _fields.entries) entry.key: entry.value.text.trim(),
        'active': _active
      });
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Unable to save. Check your connection and try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
            24, 8, 24, MediaQuery.viewInsetsOf(context).bottom + 24),
        child: Form(
            key: _form,
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(widget.initial == null ? 'Register a clinic' : 'Edit clinic',
                  style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 8),
              Text('The details your network needs to stay connected.',
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant)),
              const SizedBox(height: 24),
              for (final entry in <String, (String, IconData)>{
                'name': ('Clinic name', Icons.local_hospital_outlined),
                'address': ('Address', Icons.location_on_outlined),
                'phone': ('Phone', Icons.phone_outlined),
                'email': ('Email', Icons.alternate_email),
                'hours': ('Operating hours', Icons.schedule_outlined),
              }.entries)
                Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: TextFormField(
                      controller: _fields[entry.key],
                      enabled: !_saving,
                      textInputAction: entry.key == 'hours'
                          ? TextInputAction.done
                          : TextInputAction.next,
                      keyboardType: entry.key == 'phone'
                          ? TextInputType.phone
                          : entry.key == 'email'
                              ? TextInputType.emailAddress
                              : TextInputType.text,
                      decoration: InputDecoration(
                          labelText: entry.value.$1,
                          prefixIcon: Icon(entry.value.$2)),
                      validator: entry.key == 'name'
                          ? (value) => value?.trim().isEmpty != false
                              ? 'Enter a clinic name'
                              : null
                          : null,
                    )),
              SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Active clinic'),
                  subtitle: const Text('Available in your clinic network'),
                  value: _active,
                  onChanged: _saving
                      ? null
                      : (value) => setState(() => _active = value)),
              if (_error != null)
                Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(_error!,
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.error))),
              const SizedBox(height: 12),
              SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                      onPressed: _saving ? null : _save,
                      icon: _saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.check_rounded),
                      label: Text(_saving
                          ? 'Saving clinic…'
                          : widget.initial == null
                              ? 'Create clinic'
                              : 'Save changes'))),
            ])),
      ));
}
