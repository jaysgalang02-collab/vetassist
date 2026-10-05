import 'package:flutter/material.dart';
import '../../models/soap_record.dart';
import '../../widgets/medical_record_view.dart';

typedef SaveSoapRecord = Future<void> Function(Map<String, dynamic> data);

class MedicalRecordForm extends StatefulWidget {
  const MedicalRecordForm({
    super.key,
    required this.recordId,
    required this.clinicId,
    required this.clinicName,
    required this.patientId,
    required this.ownerUid,
    required this.authorUid,
    required this.initialValues,
    required this.onSave,
  });
  final String recordId, clinicId, clinicName, patientId, ownerUid, authorUid;
  final Map<String, String> initialValues;
  final SaveSoapRecord onSave;

  @override
  State<MedicalRecordForm> createState() => _MedicalRecordFormState();
}

class _MedicalRecordFormState extends State<MedicalRecordForm> {
  late final Map<String, TextEditingController> _fields = {
    for (final section in soapSections)
      for (final field in section.fields)
        field.key:
            TextEditingController(text: widget.initialValues[field.key] ?? ''),
  };
  final _scroll = ScrollController();
  final _sectionKeys = List.generate(6, (_) => GlobalKey());
  DateTime _date = DateTime.now();
  DateTime _signatureDate = DateTime.now();
  List<Map<String, dynamic>> _signature = [];
  int _step = 0;
  bool _dirty = false, _saving = false, _allowExit = false, _validate = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    for (final controller in _fields.values) {
      controller.addListener(_changed);
    }
  }

  void _changed() {
    if (!_dirty) setState(() => _dirty = true);
  }

  @override
  void dispose() {
    for (final controller in _fields.values) {
      controller.dispose();
    }
    _scroll.dispose();
    super.dispose();
  }

  Map<String, String> get _values =>
      _fields.map((key, controller) => MapEntry(key, controller.text.trim()));

  void _go(int step) {
    FocusScope.of(context).unfocus();
    setState(() {
      _step = step;
      _validate = false;
    });
    if (_scroll.hasClients) _scroll.jumpTo(0);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final target = _sectionKeys[step].currentContext;
      if (target != null) {
        Scrollable.ensureVisible(target,
            alignment: .5,
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : const Duration(milliseconds: 200));
      }
    });
  }

  bool _validSection(int step) => soapSections[step]
      .fields
      .every((f) => validateSoapField(f, _fields[f.key]!.text) == null);

  Map<String, dynamic> _payload() => buildSoapVisit(
      recordId: widget.recordId,
      clinicId: widget.clinicId,
      clinicName: widget.clinicName,
      patientId: widget.patientId,
      ownerUid: widget.ownerUid,
      authorUid: widget.authorUid,
      date: _date,
      values: _values,
      signature: _signature,
      signatureDate: _signatureDate);

  Future<void> _save() async {
    if (_saving) return;
    for (var i = 0; i < soapSections.length; i++) {
      if (!_validSection(i)) {
        _go(i);
        setState(() => _validate = true);
        return;
      }
    }
    if (_signature.isNotEmpty &&
        (_values['veterinarian']!.isEmpty || _values['licenseNo']!.isEmpty)) {
      setState(() => _error =
          'Enter the attending veterinarian and license number for this signature.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.onSave(_payload());
      if (!mounted) return;
      setState(() {
        _saving = false;
        _dirty = false;
        _allowExit = true;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.pop(context, true);
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error =
              'Save was not confirmed. Your entries are still here. Check your connection and retry; the same record will be used.';
        });
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(_error!)));
      }
    }
  }

  Future<void> _leave() async {
    if (_saving) return;
    final discard = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Leave this record?'),
        content: const Text('Your unsaved entries will be discarded.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Keep editing')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Discard')),
        ],
      ),
    );
    if (discard == true && mounted) {
      setState(() => _allowExit = true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.pop(context);
      });
    }
  }

  Future<void> _pickDate({bool signature = false}) async {
    final initial = signature ? _signatureDate : _date;
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2010),
      lastDate: DateTime.now(),
    );
    if (date == null || !mounted) return;
    if (signature) {
      setState(() {
        _signatureDate = date;
        _dirty = true;
      });
      return;
    }
    final time = await showTimePicker(
        context: context, initialTime: TimeOfDay.fromDateTime(initial));
    if (time == null || !mounted) return;
    setState(() {
      _date = DateTime(date.year, date.month, date.day, time.hour, time.minute);
      _dirty = true;
    });
  }

  Widget _input(SoapField field) {
    final current = _fields[field.key]!;
    final options = switch (field.key) {
      'species' => ['canine', 'feline'],
      'sex' => ['male', 'female'],
      'reproductiveStatus' => ['neutered', 'spayed', 'intact', 'unknown'],
      _ => <String>[],
    };
    final decoration = InputDecoration(
      label: Text(field.label, softWrap: true),
      hintText: field.key == 'recordNo'
          ? 'Assigned automatically if left blank'
          : field.key == 'bcs'
              ? 'e.g. 5/9'
              : null,
      alignLabelWithHint: field.long,
    );
    if (options.isNotEmpty) {
      final value = current.text;
      return DropdownButtonFormField<String>(
        key: ValueKey('field-${field.key}'),
        value: value.isEmpty ? null : value,
        isExpanded: true,
        decoration: decoration,
        items: [
          const DropdownMenuItem(value: '', child: Text('Not recorded')),
          for (final option in {...options, if (value.isNotEmpty) value})
            DropdownMenuItem(
                value: option,
                child: Text(option[0].toUpperCase() + option.substring(1),
                    overflow: TextOverflow.ellipsis)),
        ],
        onChanged: _saving ? null : (value) => current.text = value ?? '',
      );
    }
    return TextFormField(
      key: ValueKey('field-${field.key}'),
      controller: current,
      decoration: decoration,
      minLines: field.long ? 2 : 1,
      maxLines: field.long ? 5 : 1,
      keyboardType: field.numeric
          ? const TextInputType.numberWithOptions(decimal: true)
          : field.long
              ? TextInputType.multiline
              : TextInputType.text,
      textCapitalization: field.numeric
          ? TextCapitalization.none
          : TextCapitalization.sentences,
      validator: (value) => validateSoapField(field, value ?? ''),
      autovalidateMode: _validate
          ? AutovalidateMode.always
          : AutovalidateMode.onUserInteraction,
      enabled: !_saving,
    );
  }

  @override
  Widget build(BuildContext context) {
    final section = soapSections[_step];
    final cs = Theme.of(context).colorScheme;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return PopScope(
      canPop: _allowExit || (!_dirty && !_saving),
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _leave();
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('New medical record')),
        body: SafeArea(
            child: Column(children: [
          if (MediaQuery.sizeOf(context).height -
                  MediaQuery.viewInsetsOf(context).bottom >=
              500)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.initialValues['patientName'] ?? 'Patient',
                        style: Theme.of(context).textTheme.titleLarge),
                    Text('SOAP record · ${widget.clinicName}',
                        style: TextStyle(color: cs.onSurfaceVariant)),
                    const SizedBox(height: 14),
                    TweenAnimationBuilder<double>(
                      tween: Tween(end: (_step + 1) / soapSections.length),
                      duration: reduceMotion
                          ? Duration.zero
                          : const Duration(milliseconds: 280),
                      builder: (_, value, __) => LinearProgressIndicator(
                          value: value,
                          minHeight: 5,
                          borderRadius: BorderRadius.circular(9)),
                    ),
                  ]),
            ),
          SizedBox(
              height: 40 + MediaQuery.textScalerOf(context).scale(14),
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                child: Row(children: [
                  for (var i = 0; i < soapSections.length; i++)
                    Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                            key: _sectionKeys[i],
                            label: Text('${i + 1}. ${soapSections[i].title}'),
                            selected: _step == i,
                            onSelected: _saving ? null : (_) => _go(i))),
                ]),
              )),
          Expanded(
              child: SingleChildScrollView(
            controller: _scroll,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
            child: Center(
                child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 840),
              child: AnimatedSwitcher(
                duration: reduceMotion
                    ? Duration.zero
                    : const Duration(milliseconds: 200),
                child: MedicalRecordCard(
                  key: ValueKey(_step),
                  title: section.title,
                  subtitle: section.subtitle,
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (_step == 0) ...[
                          OutlinedButton.icon(
                              onPressed: _saving ? null : () => _pickDate(),
                              icon: const Icon(Icons.calendar_month_outlined),
                              label: Text('Visit: ${recordDateLabel(_date)}')),
                          const SizedBox(height: 18),
                        ],
                        if (_step == 2) ...[
                          Text(
                              'Weight: ${_fields['weightKg']!.text.isEmpty ? 'Not recorded' : '${_fields['weightKg']!.text} kg'} · Set in Patient & visit'),
                          const SizedBox(height: 18),
                        ],
                        LayoutBuilder(builder: (context, constraints) {
                          final width = constraints.maxWidth;
                          final columns = width >= 600 &&
                                  MediaQuery.textScalerOf(context).scale(1) <
                                      1.5
                              ? 2
                              : 1;
                          return Wrap(spacing: 16, runSpacing: 20, children: [
                            for (final field in section.fields)
                              SizedBox(
                                  width: field.long
                                      ? width
                                      : (width - (columns - 1) * 16) / columns,
                                  child: _input(field)),
                          ]);
                        }),
                        if (_step == 5) ...[
                          const SizedBox(height: 24),
                          Text('Veterinarian signature',
                              style: Theme.of(context).textTheme.titleSmall),
                          const SizedBox(height: 6),
                          const Text(
                              'The attending veterinarian may sign here. Leave blank if not yet signed.'),
                          const SizedBox(height: 12),
                          VetSignaturePad(
                              points: _signature,
                              onChanged: _saving
                                  ? null
                                  : (points) => setState(() {
                                        _signature = points;
                                        _dirty = true;
                                      })),
                          Align(
                              alignment: Alignment.centerRight,
                              child: TextButton.icon(
                                  onPressed: _saving || _signature.isEmpty
                                      ? null
                                      : () => setState(() {
                                            _signature = [];
                                            _dirty = true;
                                          }),
                                  icon: const Icon(Icons.restart_alt),
                                  label: const Text('Clear signature'))),
                          OutlinedButton.icon(
                              onPressed: _saving
                                  ? null
                                  : () => _pickDate(signature: true),
                              icon: const Icon(Icons.today_outlined),
                              label: Text(
                                  'Sign-off date: ${recordDateLabel(_signatureDate).split(' ').first}')),
                          const SizedBox(height: 12),
                          TextButton.icon(
                            icon: const Icon(Icons.visibility_outlined),
                            label: const Text('Preview record'),
                            onPressed: _saving
                                ? null
                                : () {
                                    for (var i = 0;
                                        i < soapSections.length;
                                        i++) {
                                      if (!_validSection(i)) {
                                        _go(i);
                                        setState(() => _validate = true);
                                        return;
                                      }
                                    }
                                    try {
                                      Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                              builder: (_) => MedicalRecordView(
                                                  recordId: widget.recordId,
                                                  visit: _payload())));
                                    } on ArgumentError catch (error) {
                                      setState(() =>
                                          _error = error.message.toString());
                                    }
                                  },
                          ),
                        ],
                        if (_error != null) ...[
                          const SizedBox(height: 16),
                          Text(_error!, style: TextStyle(color: cs.error)),
                        ],
                      ]),
                ),
              ),
            )),
          )),
        ])),
        bottomNavigationBar: Padding(
          padding:
              EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
          child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Row(children: [
                  if (_step > 0) ...[
                    IconButton.filledTonal(
                        tooltip: 'Previous section',
                        onPressed: _saving ? null : () => _go(_step - 1),
                        icon: const Icon(Icons.arrow_back)),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                      child: FilledButton.icon(
                    onPressed: _saving
                        ? null
                        : () {
                            if (_step == 5) {
                              _save();
                              return;
                            }
                            if (!_validSection(_step)) {
                              setState(() => _validate = true);
                              return;
                            }
                            _go(_step + 1);
                          },
                    icon: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : Icon(_step == 5
                            ? Icons.check_circle_outline
                            : Icons.arrow_forward),
                    label: Text(_saving
                        ? 'Saving record...'
                        : _step == 5
                            ? 'Save medical record'
                            : 'Continue'),
                  )),
                ]),
              )),
        ),
      ),
    );
  }
}
