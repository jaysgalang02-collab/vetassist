import 'package:flutter/material.dart';
import '../models/soap_record.dart';

class MedicalRecordCard extends StatelessWidget {
  const MedicalRecordCard(
      {super.key, required this.title, required this.child, this.subtitle});
  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) => Card(
        margin: const EdgeInsets.only(bottom: 16),
        child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                if (subtitle != null) ...[
                  const SizedBox(height: 6),
                  Text(subtitle!,
                      style: TextStyle(
                          color:
                              Theme.of(context).colorScheme.onSurfaceVariant)),
                ],
                const SizedBox(height: 18),
                child,
              ],
            )),
      );
}

class VetSignaturePad extends StatelessWidget {
  const VetSignaturePad({super.key, required this.points, this.onChanged});
  final List<Map<String, dynamic>> points;
  final ValueChanged<List<Map<String, dynamic>>>? onChanged;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurface;
    return Semantics(
      label: onChanged == null
          ? 'Veterinarian signature'
          : 'Draw veterinarian signature',
      child: LayoutBuilder(builder: (context, constraints) {
        var strokePoints = points;
        void add(Offset position, bool start) {
          if (strokePoints.length >= 4000) return;
          strokePoints = [
            ...strokePoints,
            {
              'x': (position.dx / constraints.maxWidth).clamp(0.0, 1.0),
              'y': (position.dy / 160).clamp(0.0, 1.0),
              'start': start,
            }
          ];
          onChanged?.call(strokePoints);
        }

        return GestureDetector(
          onPanStart:
              onChanged == null ? null : (d) => add(d.localPosition, true),
          onPanUpdate:
              onChanged == null ? null : (d) => add(d.localPosition, false),
          child: Container(
            height: 160,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              border: Border.all(
                  color: Theme.of(context).colorScheme.outlineVariant),
              borderRadius: BorderRadius.circular(16),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: CustomPaint(
                painter: _SignaturePainter(points, color),
                child: points.isEmpty
                    ? const Center(child: Text('Draw signature here'))
                    : const SizedBox.expand(),
              ),
            ),
          ),
        );
      }),
    );
  }
}

class _SignaturePainter extends CustomPainter {
  const _SignaturePainter(this.points, this.color);
  final List<Map<String, dynamic>> points;
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final pen = Paint()
      ..color = color
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;
    Offset? previous;
    for (final point in points) {
      final x = point['x'];
      final y = point['y'];
      if (x is! num || y is! num || !x.isFinite || !y.isFinite) continue;
      final next =
          Offset(x.clamp(0, 1) * size.width, y.clamp(0, 1) * size.height);
      if (point['start'] == true || previous == null) {
        canvas.drawCircle(next, 1.1, pen);
      } else {
        canvas.drawLine(previous, next, pen);
      }
      previous = next;
    }
  }

  @override
  bool shouldRepaint(covariant _SignaturePainter old) =>
      old.points != points || old.color != color;
}

class MedicalRecordView extends StatelessWidget {
  const MedicalRecordView(
      {super.key, required this.recordId, required this.visit});
  final String recordId;
  final Map<String, dynamic> visit;

  @override
  Widget build(BuildContext context) {
    final sections = readableSoap(visit);
    final patient = sections['patient']!;
    final signed = sections['signOff']!['signature'];
    final signature = signed is List
        ? signed
            .whereType<Map>()
            .map((p) => Map<String, dynamic>.from(p))
            .toList()
        : <Map<String, dynamic>>[];
    return Scaffold(
      appBar: AppBar(title: const Text('Medical record')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [
                Theme.of(context).colorScheme.primary,
                const Color(0xFF287C64),
              ]),
              borderRadius: BorderRadius.circular(24),
            ),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.health_and_safety_outlined,
                  color: Colors.white, size: 32),
              const SizedBox(height: 16),
              Text(
                  recordText(patient['patientName']).isEmpty
                      ? 'Visit record'
                      : recordText(patient['patientName']),
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: Colors.white, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text(
                  recordDateLabel(recordDate(visit['date']) ??
                      recordDate(visit['createdAt'])),
                  style: const TextStyle(color: Colors.white)),
              if (recordText(visit['clinic']).isNotEmpty)
                Text(recordText(visit['clinic']),
                    style: const TextStyle(color: Colors.white)),
              const SizedBox(height: 12),
              Text(
                  visit['recordType'] == 'soap'
                      ? 'SOAP medical record'
                      : 'Previous visit record',
                  style: const TextStyle(color: Colors.white)),
            ]),
          ),
          const SizedBox(height: 20),
          for (final section in soapSections)
            MedicalRecordCard(
                title: section.title,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (section.key == 'patient')
                      _Fact(
                          'Record no.',
                          recordText(patient['recordNo']).isEmpty
                              ? recordId
                              : recordText(patient['recordNo'])),
                    for (final field in section.fields)
                      if (field.key != 'recordNo' &&
                          recordText(sections[section.key]![field.key])
                              .isNotEmpty)
                        _Fact(field.label,
                            recordText(sections[section.key]![field.key])),
                    if (section.key == 'objective' &&
                        recordText(sections['objective']!['weightKg'])
                            .isNotEmpty)
                      _Fact('Weight (kg)',
                          recordText(sections['objective']!['weightKg'])),
                    if (section.fields.every((f) =>
                            recordText(sections[section.key]![f.key])
                                .isEmpty) &&
                        section.key != 'patient' &&
                        section.key != 'signOff')
                      const Text('Not recorded'),
                    if (section.key == 'signOff') ...[
                      if (signature.isNotEmpty) ...[
                        VetSignaturePad(points: signature),
                        const SizedBox(height: 12),
                        _Fact(
                            'Signature date',
                            recordDateLabel(
                                recordDate(sections['signOff']!['date']))),
                      ] else
                        const Text('No veterinarian signature recorded.'),
                    ],
                  ],
                )),
        ],
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact(this.label, this.value);
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant)),
          const SizedBox(height: 4),
          SelectableText(value),
        ]),
      );
}
