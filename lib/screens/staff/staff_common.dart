import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class Section extends StatelessWidget {
  final String title;
  final Widget child;
  final Widget? trailing;
  const Section({super.key, required this.title, required this.child, this.trailing});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          color: cs.surfaceContainerHighest.withOpacity(.6),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
              const Spacer(),
              if (trailing != null) trailing!,
            ],
          ),
        ),
        Expanded(child: child),
      ],
    );
  }
}

// ---- Formatting & CSV helpers ----
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
