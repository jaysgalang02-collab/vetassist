import 'package:flutter/material.dart';
import '../../../services/reminder_service.dart';

/// Open with: `await showCreateReminderDialog(context);`
Future<bool?> showCreateReminderDialog(BuildContext context) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const _CreateReminderDialog(),
  );
}

class _CreateReminderDialog extends StatefulWidget {
  const _CreateReminderDialog();

  @override
  State<_CreateReminderDialog> createState() => _CreateReminderDialogState();
}

class _CreateReminderDialogState extends State<_CreateReminderDialog> {
  final _titleCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  // default values as in your screenshot
  String _type = 'followup';
  DateTime _when = _roundUp(DateTime.now().add(const Duration(minutes: 30)));
  bool _busy = false;

  static DateTime _roundUp(DateTime dt) {
    final m = ((dt.minute + 4) ~/ 5) * 5;
    return DateTime(dt.year, dt.month, dt.day, dt.hour, m);
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _when,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
    );
    if (d == null) return;

    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_when),
    );
    if (t == null) return;

    setState(() {
      _when = DateTime(d.year, d.month, d.day, t.hour, t.minute);
    });
  }

  Future<void> _create() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await ReminderService.createReminder(
        type: _type,                 // will be normalized inside service
        title: _titleCtrl.text,
        when: _when,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _fmt(DateTime d) =>
      '${d.year}-${_pad2(d.month)}-${_pad2(d.day)} ${_pad2(d.hour)}:${_pad2(d.minute)}';
  String _pad2(int n) => n.toString().padLeft(2, '0');

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Type', style: TextStyle(color: cs.onSurfaceVariant)),
                ),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  value: _type,
                  isExpanded: true,
                  items: const [
                    DropdownMenuItem(value: 'followup', child: Text('Follow-up')),
                    DropdownMenuItem(value: 'vaccine', child: Text('Vaccine')),
                    DropdownMenuItem(value: 'visit', child: Text('Visit')),
                    DropdownMenuItem(value: 'custom', child: Text('Custom')),
                  ],
                  onChanged: (v) => setState(() => _type = v ?? 'followup'),
                ),
                const SizedBox(height: 12),

                Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Title', style: TextStyle(color: cs.onSurfaceVariant)),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _titleCtrl,
                  decoration: const InputDecoration(
                    hintText: 'vaccine',
                    isDense: true,
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Please enter a title' : null,
                ),
                const SizedBox(height: 12),

                Align(
                  alignment: Alignment.centerLeft,
                  child: Text('When', style: TextStyle(color: cs.onSurfaceVariant)),
                ),
                const SizedBox(height: 6),
                InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: _pickDateTime,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: cs.outlineVariant),
                    ),
                    child: Row(
                      children: [
                        Expanded(child: Text(_fmt(_when))),
                        const Icon(Icons.calendar_today_outlined, size: 18),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: _busy ? null : () => Navigator.of(context).pop(false),
                      child: const Text('Cancel'),
                    ),
                    FilledButton(
                      onPressed: _busy ? null : _create,
                      child: _busy
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Create'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
