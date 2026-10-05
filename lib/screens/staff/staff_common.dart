import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class Section extends StatelessWidget {
  final String title;
  final Widget child;
  final Widget? trailing;
  const Section(
      {super.key, required this.title, required this.child, this.trailing});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: cs.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              child: Row(
                children: [
                  Expanded(
                      child: Text(title,
                          style: Theme.of(context).textTheme.titleMedium)),
                  const SizedBox(width: 8),
                  if (trailing != null) trailing!,
                ],
              ),
            ),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }
}

String fmtTs(Timestamp? t) {
  if (t == null) return '';
  final dt = t.toDate();
  return '${dt.year}-${_two(dt.month)}-${_two(dt.day)} ${_two(dt.hour)}:${_two(dt.minute)}';
}

String toCsv(List<List<String>> rows) =>
    rows.map((r) => r.map(_csvCell).join(',')).join('\n');

String _csvCell(String v) {
  final needsQuotes = v.contains(',') || v.contains('\n') || v.contains('"');
  if (!needsQuotes) return v;
  return '"${v.replaceAll('"', '""')}"';
}

String _two(int n) => n.toString().padLeft(2, '0');
