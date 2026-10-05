import 'dart:math' as math;

const symptomAliases = <String, List<String>>{
  'fever': ['fever', 'lagnat'],
  'vomiting': ['vomiting', 'vomit', 'throwing up', 'suka', 'sumusuka'],
  'diarrhea': ['diarrhea', 'diarrhoea', 'loose stool', 'pagtatae', 'nagtatae'],
  'cough': ['cough', 'coughing', 'ubo', 'umuubo'],
  'nasal_discharge': ['nasal discharge', 'runny nose', 'sipon'],
  'ocular_discharge': ['ocular discharge', 'eye discharge', 'muta'],
  'lethargy': [
    'lethargy',
    'lethargic',
    'weak',
    'weakness',
    'matamlay',
    'panghihina'
  ],
  'loss_of_appetite': [
    'loss of appetite',
    'not eating',
    'no appetite',
    'poor appetite',
    'hindi kumakain',
    'walang gana'
  ],
  'weight_loss': ['weight loss', 'losing weight', 'pumapayat'],
  'respiratory_distress': [
    'respiratory distress',
    'difficulty breathing',
    'trouble breathing',
    'hard breathing',
    'hirap huminga'
  ],
  'pale_gums': ['pale gums', 'blue gums', 'maputlang gilagid'],
  'neurologic_signs': [
    'neurologic signs',
    'seizure',
    'seizures',
    'convulsion',
    'convulsions',
    'twitching'
  ],
};

class DiseaseRule {
  final String disease, species, notes;
  final Set<String> symptoms;
  const DiseaseRule(this.disease, this.species, this.symptoms, this.notes);
}

const diseaseRules = <DiseaseRule>[
  DiseaseRule(
      'parvovirus',
      'canine',
      {'vomiting', 'diarrhea', 'lethargy', 'loss_of_appetite', 'fever'},
      'Consider fecal antigen testing and veterinary assessment.'),
  DiseaseRule(
      'distemper',
      'canine',
      {
        'cough',
        'nasal_discharge',
        'ocular_discharge',
        'fever',
        'neurologic_signs'
      },
      'Veterinary assessment and confirmatory testing are required.'),
  DiseaseRule(
      'heartworm',
      'canine',
      {'cough', 'respiratory_distress', 'lethargy', 'weight_loss'},
      'Consider antigen testing and veterinary staging.'),
  DiseaseRule(
      'feline_leukemia',
      'feline',
      {'lethargy', 'weight_loss', 'fever', 'pale_gums'},
      'Consider FeLV antigen testing with a veterinarian.'),
  DiseaseRule('fiv', 'feline', {'weight_loss', 'fever', 'lethargy'},
      'Consider FIV antibody testing with a veterinarian.'),
  DiseaseRule(
      'feline_uri',
      'feline',
      {
        'cough',
        'nasal_discharge',
        'ocular_discharge',
        'fever',
        'loss_of_appetite'
      },
      'A veterinarian should assess respiratory and eye symptoms.'),
];

class SymptomSuggestion {
  final String disease, notes, source;
  final double score;
  final int matched, total;
  const SymptomSuggestion(
      {required this.disease,
      required this.notes,
      required this.source,
      required this.score,
      required this.matched,
      required this.total});
}

class SymptomEngine {
  final Map<String, dynamic>? model;
  SymptomEngine({this.model}) {
    if (model != null) _validateModel(model!);
  }

  static void _validateModel(Map<String, dynamic> data) {
    if (data['schemaVersion'] != 1 ||
        !['untrained', 'trained'].contains(data['status'])) {
      throw const FormatException('Unsupported symptom model.');
    }
    if (data['status'] == 'untrained') return;
    final classes = data['classes'];
    if (classes is! List ||
        classes.isEmpty ||
        data['sourceSha256'] is! String ||
        data['sourceName'] is! String) {
      throw const FormatException('Missing training provenance or classes.');
    }
    final identities = <String>{};
    for (final item in classes) {
      if (item is! Map ||
          !['canine', 'feline'].contains(item['species']) ||
          item['disease'] is! String ||
          (item['disease'] as String).trim().isEmpty ||
          item['count'] is! int ||
          item['count'] <= 0 ||
          item['symptomCounts'] is! Map) {
        throw const FormatException('Invalid training class.');
      }
      if (!identities.add('${item['species']}:${item['disease']}')) {
        throw const FormatException('Duplicate training class.');
      }
      for (final entry in (item['symptomCounts'] as Map).entries) {
        if (!symptomAliases.containsKey(entry.key) ||
            entry.value is! int ||
            entry.value < 0 ||
            entry.value > item['count']) {
          throw const FormatException('Invalid symptom frequency.');
        }
      }
    }
  }

  Set<String> extract(String text) {
    final normalized = text.toLowerCase().replaceAll('_', ' ');
    final found = <String>{};
    for (final entry in symptomAliases.entries) {
      for (final alias in entry.value) {
        for (final match
            in RegExp('\\b${RegExp.escape(alias)}\\b').allMatches(normalized)) {
          final before = normalized.substring(0, match.start).replaceAll(
                RegExp(
                    r'\b(?:not eating|no appetite|hindi kumakain|walang gana)\b'),
                'appetite_loss',
              );
          final clause =
              before.split(RegExp(r'[.!?;,\n]|\b(?:but|pero)\b')).last;
          if (RegExp(r"\b(?:no|not|without|denies|denied|walang|wala|hindi)\b(?:\s+[a-z]+){0,3}\s*$")
                  .hasMatch(clause) &&
              !['not eating', 'no appetite', 'hindi kumakain', 'walang gana']
                  .contains(alias)) {
            continue;
          }
          final after = normalized.substring(match.end);
          if (RegExp(r'^\s+(?:has\s+|is\s+)?(?:stopped|resolved|absent)\b')
              .hasMatch(after)) {
            continue;
          }
          found.add(entry.key);
        }
      }
    }
    return found;
  }

  List<SymptomSuggestion> predict(String species, Set<String> selected) {
    if (!['canine', 'feline'].contains(species)) {
      throw ArgumentError('Select dog or cat.');
    }
    final known = selected.where(symptomAliases.containsKey).toSet();
    if (known.isEmpty) return [];
    final classes = model?['status'] == 'trained'
        ? (model!['classes'] as List)
            .where((c) => c['species'] == species)
            .toList()
        : <dynamic>[];
    if (classes.length >= 2) {
      final totalCases =
          classes.fold<int>(0, (n, c) => n + (c['count'] as int));
      final logs = classes.map((c) {
        final count = c['count'] as int;
        var logScore = math.log((count + 1) / (totalCases + classes.length));
        for (final symptom in known) {
          logScore += math.log(
              ((c['symptomCounts'][symptom] as int? ?? 0) + 1) / (count + 2));
        }
        return logScore;
      }).toList();
      final maxLog = logs.reduce(math.max);
      final weights = logs.map((v) => math.exp(v - maxLog)).toList();
      final sum = weights.reduce((a, b) => a + b);
      final out = <SymptomSuggestion>[];
      for (var i = 0; i < classes.length; i++) {
        final c = classes[i];
        final rule = diseaseRules
            .where((r) => r.species == species && r.disease == c['disease'])
            .firstOrNull;
        out.add(SymptomSuggestion(
            disease: c['disease'],
            notes: rule?.notes ?? 'Veterinary confirmation is required.',
            source: 'Naive Bayes model estimate',
            score: weights[i] / sum,
            matched: rule?.symptoms.intersection(known).length ?? 0,
            total: rule?.symptoms.length ?? 0));
      }
      return out..sort((a, b) => b.score.compareTo(a.score));
    }
    return diseaseRules
        .where((r) =>
            r.species == species && r.symptoms.intersection(known).isNotEmpty)
        .map((r) => SymptomSuggestion(
            disease: r.disease,
            notes: r.notes,
            source: 'Rule match (not disease probability)',
            score: r.symptoms.intersection(known).length / r.symptoms.length,
            matched: r.symptoms.intersection(known).length,
            total: r.symptoms.length))
        .toList()
      ..sort((a, b) => b.score.compareTo(a.score));
  }

  String reply(String text, String species,
      {bool firstAidOnly = false, bool hasImages = false}) {
    final symptoms = extract(text);
    final emergency = symptoms.intersection(
        {'respiratory_distress', 'pale_gums', 'neurologic_signs'}).isNotEmpty;
    final care =
        '1. First Aid\n- Keep your pet calm and limit handling.\n- Call your veterinary clinic for advice and safe transport instructions.\n2. When to See a Vet\n- ${emergency ? 'EMERGENCY: contact an emergency veterinary clinic now for the reported breathing, gum-color, or neurological signs.' : 'Contact a veterinarian about the reported symptoms; this tool cannot rule out an emergency.'}';
    final photoNote = hasImages
        ? '\n\nPhotos are attachments only; no image assessment model is installed. Describe the symptoms in text.'
        : '';
    if (symptoms.isEmpty) {
      return 'Describe the current symptoms, when they started, and their severity. No supported symptoms were recognized. For an urgent concern, call a veterinary clinic.$photoNote';
    }
    if (firstAidOnly) return '$care$photoNote';
    final suggestions = predict(species, symptoms);
    final items = suggestions
        .take(3)
        .map((s) =>
            '- ${s.disease.replaceAll('_', ' ')}: ${(s.score * 100).toStringAsFixed(1)}% ${s.source}. ${s.notes}')
        .join('\n');
    return '1. Symptom Summary\nRecognized: ${symptoms.map((s) => s.replaceAll('_', ' ')).join(', ')}.\n2. Possible Conditions for Veterinary Review\n${items.isEmpty ? 'No matching condition in the available rules.' : items}\n${model?['status'] != 'trained' ? 'No dataset-trained disease model is installed. Scores show symptom overlap only.\n' : 'Model estimates are not clinically validated diagnostic probabilities.\n'}3. Care and Urgency\n$care\n4. Explanation\nResults use only the reported symptoms and selected species. Unreported symptoms are unknown. A veterinarian must confirm any diagnosis.$photoNote';
  }
}
