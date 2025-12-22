import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../services/openai_service.dart';
import '../../../widgets/cdss_chat_box.dart';

class CdsTab extends StatefulWidget {
  const CdsTab({super.key});
  @override
  State<CdsTab> createState() => _CdsTabState();
}

class _CdsTabState extends State<CdsTab> {
  String species = 'canine';

  // Photo & AI analysis state
  File? _photo;
  bool _loadingVision = false;
  Map<String, dynamic>? _ai; // parsed JSON from OpenAI (see service)

  // Your existing symptom model
  final Map<String, bool> symptoms = {
    'fever': false,
    'vomiting': false,
    'diarrhea': false,
    'cough': false,
    'nasal_discharge': false,
    'ocular_discharge': false,
    'lethargy': false,
    'loss_of_appetite': false,
    'weight_loss': false,
    'respiratory_distress': false,
    'pale_gums': false,
    'neurologic_signs': false,
  };

  // Knowledge/rule base (kept from your file, can be extended anytime)
  final Map<String, Map<String, dynamic>> rulebase = {
    // DOGS
    'parvovirus': {
      'species': 'canine',
      'symptoms': ['vomiting', 'diarrhea', 'lethargy', 'loss_of_appetite', 'fever'],
      'notes': 'Severe vomiting/diarrhea (may be bloody). Test: fecal ELISA. Supportive therapy + antibiotics.',
    },
    'distemper': {
      'species': 'canine',
      'symptoms': ['cough', 'nasal_discharge', 'ocular_discharge', 'fever', 'neurologic_signs'],
      'notes': 'Respiratory + neuro signs. Test: RT-PCR/serology. Supportive care.',
    },
    'heartworm': {
      'species': 'canine',
      'symptoms': ['cough', 'respiratory_distress', 'lethargy', 'weight_loss'],
      'notes': 'Consider antigen test; stage before treatment. Exercise restriction.',
    },

    // CATS
    'feline_leukemia': {
      'species': 'feline',
      'symptoms': ['lethargy', 'weight_loss', 'fever', 'pale_gums'],
      'notes': 'Test: FeLV antigen. Manage secondary infections.',
    },
    'fiv': {
      'species': 'feline',
      'symptoms': ['weight_loss', 'fever', 'lethargy'],
      'notes': 'Test: FIV antibody. Supportive care; manage co-infections.',
    },
    'feline_uri': {
      'species': 'feline',
      'symptoms': ['cough', 'nasal_discharge', 'ocular_discharge', 'fever', 'loss_of_appetite'],
      'notes': 'Supportive care; consider antivirals/antibiotics if indicated.',
    },
  };

  // ===== Helpers =====

  List<_CdsSuggestion> _computeSuggestions() {
    final selected = symptoms.entries.where((e) => e.value).map((e) => e.key).toSet();

    final List<_CdsSuggestion> out = [];
    rulebase.forEach((disease, meta) {
      if (meta['species'] != species) return;
      final need = (meta['symptoms'] as List).cast<String>().toSet();
      if (need.isEmpty) return;
      final matched = need.intersection(selected).length;
      final score = matched / need.length; // 0.0 - 1.0
      if (matched > 0) {
        out.add(_CdsSuggestion(
          disease: disease.replaceAll('_', ' ').toUpperCase(),
          score: score,
          notes: meta['notes'] as String,
          matched: matched,
          total: need.length,
          source: 'Rules',
        ));
      }
    });

    // If AI returned differentials, fuse them here.
    final aiDiffs = _ai?['differentials'];
    if (aiDiffs is List) {
      for (final d in aiDiffs) {
        final name = (d['name'] ?? '').toString();
        if (name.isEmpty) continue;
        final conf = (d['confidence'] is num) ? (d['confidence'] as num).toDouble() : 0.0;
        final rationale = (d['rationale'] ?? '').toString();

        // If a rules suggestion has the same disease name, blend by taking max score.
        final idx = out.indexWhere((s) => s.disease.toLowerCase() == name.toString().toLowerCase());
        if (idx >= 0) {
          final merged = out[idx];
          out[idx] = merged.copyWith(
            score: merged.score > conf ? merged.score : conf,
            notes: '${merged.notes}\n\nAI: $rationale',
            source: 'Rules+AI',
          );
        } else {
          out.add(_CdsSuggestion(
            disease: _title(name),
            score: conf.clamp(0.0, 1.0),
            notes: 'AI: $rationale',
            matched: 0,
            total: 0,
            source: 'AI',
          ));
        }
      }
    }

    out.sort((a, b) => b.score.compareTo(a.score));
    return out;
  }

  String _title(String s) => s.isEmpty ? s : (s[0].toUpperCase() + s.substring(1));

  Future<void> _pickAndAnalyze(ImageSource src) async {
    final picker = ImagePicker();
    final x = await picker.pickImage(source: src, imageQuality: 92, maxWidth: 1800);
    if (x == null) return;
    setState(() {
      _photo = File(x.path);
      _ai = null;
      _loadingVision = true;
    });

    try {
      final result = await OpenAiVisionService().analyzePetImage(
        file: _photo!,
        speciesHint: species, // we constrain to dog/cat
      );
      setState(() {
        _ai = result;
      });

      // Optionally auto-toggle symptoms inferred by AI
      final inferred = (_ai?['inferred_symptoms'] ?? []) as List;
      for (final key in symptoms.keys) {
        final hit = inferred.any((i) => i.toString().toLowerCase() == key.toLowerCase());
        if (hit) symptoms[key] = true;
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Image analysis failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _loadingVision = false);
    }
  }

  void _showImagePickerSheet() {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera),
              title: const Text('Take photo'),
              onTap: () {
                Navigator.pop(context);
                _pickAndAnalyze(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choose from gallery'),
              onTap: () {
                Navigator.pop(context);
                _pickAndAnalyze(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  // ===== UI =====

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final sugg = _computeSuggestions();

    return Padding(
      padding: const EdgeInsets.all(12),
      child: ListView(
        children: [
          // species selector + analyze button in one row
          Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text('Species:'),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'canine', label: Text('Dog')),
                  ButtonSegment(value: 'feline', label: Text('Cat')),
                ],
                selected: {species},
                onSelectionChanged: (s) => setState(() => species = s.first),
              ),
              FilledButton.icon(
                onPressed: _loadingVision ? null : _showImagePickerSheet,
                icon: const Icon(Icons.camera_alt_rounded, size: 18),
                label: const Text('Analyze Photo'),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Photo preview + AI summary
          if (_photo != null || _loadingVision || _ai != null)
            Card(
              elevation: 0,
              color: cs.surfaceContainerHighest,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_photo != null)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.file(_photo!, height: 180, fit: BoxFit.cover, width: double.infinity),
                      ),
                    if (_loadingVision) ...[
                      const SizedBox(height: 12),
                      const LinearProgressIndicator(),
                      const SizedBox(height: 8),
                      const Text('Analyzing photo…'),
                    ],
                    if (!_loadingVision && _ai != null) ...[
                      const SizedBox(height: 12),
                      Text('AI Findings', style: TextStyle(fontWeight: FontWeight.w700, color: cs.primary)),
                      const SizedBox(height: 6),
                      if ((_ai!['findings'] as List?)?.isNotEmpty == true)
                        Wrap(
                          spacing: 8,
                          runSpacing: -8,
                          children: (_ai!['findings'] as List).map((f) => Chip(label: Text(f.toString()))).toList(),
                        ),
                      if ((_ai!['red_flags'] as List?)?.isNotEmpty == true) ...[
                        const SizedBox(height: 8),
                        Text('Red flags', style: TextStyle(fontWeight: FontWeight.w600, color: cs.error)),
                        const SizedBox(height: 4),
                        ...(_ai!['red_flags'] as List).map((e) => Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(Icons.warning_amber_rounded, color: cs.error, size: 16),
                                const SizedBox(width: 6),
                                Expanded(child: Text(e.toString())),
                              ],
                            )),
                      ],
                      if ((_ai!['suggested_tests'] as List?)?.isNotEmpty == true) ...[
                        const SizedBox(height: 8),
                        const Text('Suggested tests', style: TextStyle(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 8,
                          runSpacing: -8,
                          children: (_ai!['suggested_tests'] as List).map((f) => Chip(label: Text(f.toString()))).toList(),
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            ),

          const SizedBox(height: 10),

          // Manual symptom selection
          Text('Select symptoms', style: TextStyle(fontWeight: FontWeight.w700, color: cs.primary)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: -8,
            children: symptoms.keys.map((k) {
              final label = k.replaceAll('_', ' ');
              final v = symptoms[k]!;
              return FilterChip(
                label: Text(label),
                selected: v,
                onSelected: (sel) => setState(() => symptoms[k] = sel),
              );
            }).toList(),
          ),

          const SizedBox(height: 14),

          // Suggestions (Rules + AI fused)
          Builder(builder: (context) {
            if (sugg.isEmpty) {
              return const Text('No suggestions yet. Select symptoms or analyze a photo.');
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Suggestions', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                ...sugg.map((s) => Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          child: Text('${(s.score * 100).round()}%'),
                        ),
                        title: Text(s.disease),
                        subtitle: Text(
                          ([
                            if (s.matched > 0 && s.total > 0) 'Matched ${s.matched}/${s.total}',
                            s.source
                          ]..removeWhere((x) => x == null || (x is String && x.isEmpty)))
                              .join(' • '),
                        ),
                        isThreeLine: true,
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () {
                          final advice = _firstAidAdvice(s.disease, species);
                          showModalBottomSheet(
                            context: context,
                            showDragHandle: true,
                            isScrollControlled: true,
                            builder: (_) => Padding(
                              padding: const EdgeInsets.all(16),
                              child: SingleChildScrollView(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(s.disease, style: Theme.of(context).textTheme.titleLarge),
                                    const SizedBox(height: 8),
                                    Text(s.notes),
                                    const SizedBox(height: 12),
                                    Text(
                                      'First Aid',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        color: Theme.of(context).colorScheme.primary,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(advice),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    )),
              ],
            );
          }),
          const SizedBox(height: 24),

          // CDSS Chat box (multi-turn with images)
          CDSSChatBox(species: species),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _CdsSuggestion {
  final String disease;
  final double score;
  final String notes;
  final int matched;
  final int total;
  final String source;
  _CdsSuggestion({
    required this.disease,
    required this.score,
    required this.notes,
    required this.matched,
    required this.total,
    required this.source,
  });

  _CdsSuggestion copyWith({
    String? disease,
    double? score,
    String? notes,
    int? matched,
    int? total,
    String? source,
  }) =>
      _CdsSuggestion(
        disease: disease ?? this.disease,
        score: score ?? this.score,
        notes: notes ?? this.notes,
        matched: matched ?? this.matched,
        total: total ?? this.total,
        source: source ?? this.source,
      );
}

String _firstAidAdvice(String disease, String species) {
  final d = disease.toLowerCase();
  if (d.contains('parvo') || d.contains('parvovirus')) {
    return 'Isolate the pet, keep warm, offer small sips of clean water or oral rehydration, and clean up vomit/stool promptly. Refer to a vet immediately for ongoing vomiting/diarrhea, bloody stool, or weakness.';
  }
  if (d.contains('distemper')) {
    return 'Limit activity, keep the dog warm and hydrated, clean nasal/eye discharge, and avoid contact with other dogs. See a vet urgently if breathing is labored, seizures/twitching appear, or appetite stops.';
  }
  if (d.contains('heartworm')) {
    return 'Strict rest—no exercise—to reduce heart/lung strain. Keep calm and cool, provide water. Schedule a vet promptly for testing and staging; avoid exertion until cleared.';
  }
  if (d.contains('feline') && d.contains('uri')) {
    return 'Use a steamy bathroom or humidifier to ease congestion, gently clean eye/nose discharge, offer warmed aromatic food and fresh water. Vet visit if breathing is difficult, eyes swell, or the cat stops eating.';
  }
  if (d.contains('fiv') || d.contains('feline leukemia') || d.contains('leukemia')) {
    return 'Keep indoors, reduce stress, ensure clean water and palatable food, monitor gums/breathing. Arrange vet follow-up to confirm diagnosis and manage infections.';
  }
  return 'Keep the ${species == 'canine' ? 'dog' : 'cat'} rested, hydrated with small frequent sips of water, and monitor breathing, appetite, and energy. Go to a vet immediately for hard breathing, pale/blue gums, persistent vomiting/diarrhea, or weakness.';
}
