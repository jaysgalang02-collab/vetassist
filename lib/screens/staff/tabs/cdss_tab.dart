import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../services/local_cdss_service.dart';
import '../../../services/symptom_engine.dart';
import '../../../widgets/cdss_chat_box.dart';
import '../clinical_reference_screen.dart';

class CdsTab extends StatefulWidget {
  const CdsTab({super.key});
  @override
  State<CdsTab> createState() => _CdsTabState();
}

class _CdsTabState extends State<CdsTab> {
  String species = 'canine';

  File? _photo;
  bool _loadingVision = false;
  Map<String, dynamic>? _ai;

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

  SymptomEngine _engine = SymptomEngine();

  @override
  void initState() {
    super.initState();
    _loadModel();
  }

  Future<void> _loadModel() async {
    try {
      final engine = await loadSymptomEngine();
      if (mounted) setState(() => _engine = engine);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text(
            'The disease model could not be loaded. Symptom rules remain available.'),
      ));
    }
  }

  List<_CdsSuggestion> _computeSuggestions() {
    final selected =
        symptoms.entries.where((e) => e.value).map((e) => e.key).toSet();
    return _engine
        .predict(species, selected)
        .map((s) => _CdsSuggestion(
              disease: s.disease.replaceAll('_', ' ').toUpperCase(),
              score: s.score,
              notes: s.notes,
              matched: s.matched,
              total: s.total,
              source: s.source,
            ))
        .toList();
  }

  Future<void> _pickAndAnalyze(ImageSource src) async {
    final picker = ImagePicker();
    final x =
        await picker.pickImage(source: src, imageQuality: 92, maxWidth: 1800);
    if (x == null) return;
    setState(() {
      _photo = File(x.path);
      _ai = null;
      _loadingVision = true;
    });

    try {
      final result = await LocalPetPhotoService().analyzePetImage(
        file: _photo!,
        speciesHint: species,
      );
      setState(() {
        _ai = result;
      });

      final inferred = (_ai?['inferred_symptoms'] ?? []) as List;
      for (final key in symptoms.keys) {
        final hit = inferred
            .any((i) => i.toString().toLowerCase() == key.toLowerCase());
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

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final sugg = _computeSuggestions();

    return Padding(
      padding: const EdgeInsets.all(12),
      child: ListView(
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.library_books_outlined),
              title: const Text('Published clinical cases'),
              subtitle: const Text(
                  'Browse sourced urogenital case records. Reference examples, separate from symptom predictions.'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
                  builder: (_) => const ClinicalReferenceScreen())),
            ),
          ),
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
                onSelectionChanged: (s) => setState(() {
                  species = s.first;
                  _ai = null;
                  for (final key in symptoms.keys) {
                    symptoms[key] = false;
                  }
                }),
              ),
              FilledButton.icon(
                onPressed: _loadingVision ? null : _showImagePickerSheet,
                icon: const Icon(Icons.camera_alt_rounded, size: 18),
                label: const Text('Attach Photo'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_photo != null || _loadingVision || _ai != null)
            Card(
              elevation: 0,
              color: cs.surfaceContainerHighest,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_photo != null)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.file(_photo!,
                            height: 180,
                            fit: BoxFit.cover,
                            width: double.infinity),
                      ),
                    if (_loadingVision) ...[
                      const SizedBox(height: 12),
                      const LinearProgressIndicator(),
                      const SizedBox(height: 8),
                      const Text('Attaching photo…'),
                    ],
                    if (!_loadingVision && _ai != null) ...[
                      const SizedBox(height: 12),
                      Text('Photo attachment',
                          style: TextStyle(
                              fontWeight: FontWeight.w700, color: cs.primary)),
                      const SizedBox(height: 6),
                      if ((_ai!['findings'] as List?)?.isNotEmpty == true)
                        Wrap(
                          spacing: 8,
                          runSpacing: -8,
                          children: (_ai!['findings'] as List)
                              .map((f) => Chip(label: Text(f.toString())))
                              .toList(),
                        ),
                      if ((_ai!['red_flags'] as List?)?.isNotEmpty == true) ...[
                        const SizedBox(height: 8),
                        Text('Red flags',
                            style: TextStyle(
                                fontWeight: FontWeight.w600, color: cs.error)),
                        const SizedBox(height: 4),
                        ...(_ai!['red_flags'] as List).map((e) => Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(Icons.warning_amber_rounded,
                                    color: cs.error, size: 16),
                                const SizedBox(width: 6),
                                Expanded(child: Text(e.toString())),
                              ],
                            )),
                      ],
                      if ((_ai!['suggested_tests'] as List?)?.isNotEmpty ==
                          true) ...[
                        const SizedBox(height: 8),
                        const Text('Suggested tests',
                            style: TextStyle(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 8,
                          runSpacing: -8,
                          children: (_ai!['suggested_tests'] as List)
                              .map((f) => Chip(label: Text(f.toString())))
                              .toList(),
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            ),
          const SizedBox(height: 10),
          Text('Select symptoms',
              style: TextStyle(fontWeight: FontWeight.w700, color: cs.primary)),
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
          Builder(builder: (context) {
            if (sugg.isEmpty) {
              return const Text('No suggestions yet. Select symptoms.');
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Suggestions',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                ...sugg.map((s) => Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          child: Text('${(s.score * 100).round()}%'),
                        ),
                        title: Text(s.disease),
                        subtitle: Text(
                          ([
                            if (s.matched > 0 && s.total > 0)
                              'Matched ${s.matched}/${s.total}',
                            s.source
                          ]..removeWhere((x) => x.isEmpty))
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
                                    Text(s.disease,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleLarge),
                                    const SizedBox(height: 8),
                                    Text(s.notes),
                                    const SizedBox(height: 12),
                                    Text(
                                      'First Aid',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary,
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
  if (d.contains('fiv') ||
      d.contains('feline leukemia') ||
      d.contains('leukemia')) {
    return 'Keep indoors, reduce stress, ensure clean water and palatable food, monitor gums/breathing. Arrange vet follow-up to confirm diagnosis and manage infections.';
  }
  return 'Keep the ${species == 'canine' ? 'dog' : 'cat'} rested, hydrated with small frequent sips of water, and monitor breathing, appetite, and energy. Go to a vet immediately for hard breathing, pale/blue gums, persistent vomiting/diarrhea, or weakness.';
}
