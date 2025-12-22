import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class OpenAiVisionService {
  // 🔑 Replace this with your actual OpenAI API key
  final String _apiKey = 'REMOVED_CREDENTIAL';

  // Using gpt-4o-mini for vision (fast and cheaper)
  final String _model = 'gpt-4o-mini';

  /// Analyzes a pet image and returns structured data.
  Future<Map<String, dynamic>> analyzePetImage({
    required File file,
    required String speciesHint, // 'canine' or 'feline'
  }) async {
    final bytes = await file.readAsBytes();
    final b64 = base64Encode(bytes);
    final mime = _inferMime(file.path);

    final systemPrompt = '''
You are a veterinary clinical decision support assistant specializing in DOGS and CATS only.
Analyze the uploaded image and return structured JSON ONLY:
{
 "species": "canine|feline|unknown",
 "findings": ["visible observations"],
 "inferred_symptoms": ["map to these: fever, vomiting, diarrhea, cough, nasal_discharge, ocular_discharge, lethargy, loss_of_appetite, weight_loss, respiratory_distress, pale_gums, neurologic_signs"],
 "differentials": [{"name":"disease","rationale":"why","confidence":0.0-1.0}],
 "red_flags": ["danger signs"],
 "suggested_tests": ["useful diagnostic tests"],
 "triage": "homecare|urgent|emergency"
}
Keep diseases relevant to ${speciesHint == 'canine' ? 'dogs' : 'cats'} only.
 Speak decisively and provide your best clinical judgment based on the image.
 Do not include any generic disclaimers. Do NOT say you cannot diagnose from images.
 Keep output strictly as valid JSON with no extra text.
''';

    final uri = Uri.parse('https://api.openai.com/v1/chat/completions');

    final body = {
      "model": _model,
      "response_format": {"type": "json_object"},
      "messages": [
        {"role": "system", "content": systemPrompt},
        {
          "role": "user",
          "content": [
            {"type": "text", "text": "Analyze this ${speciesHint == 'canine' ? 'dog' : 'cat'} image."},
            {
              "type": "image_url",
              "image_url": {"url": "data:$mime;base64,$b64"}
            }
          ]
        }
      ]
    };

    final res = await http.post(
      uri,
      headers: {
        'Authorization': 'Bearer $_apiKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(body),
    );

    if (res.statusCode >= 400) {
      throw Exception('OpenAI Error ${res.statusCode}: ${res.body}');
    }

    final data = jsonDecode(res.body);
    final content = data['choices']?[0]?['message']?['content'] ?? '{}';

    final Map<String, dynamic> parsed = jsonDecode(content);
    return {
      'findings': parsed['findings'] ?? [],
      'inferred_symptoms': parsed['inferred_symptoms'] ?? [],
      'differentials': parsed['differentials'] ?? [],
      'red_flags': parsed['red_flags'] ?? [],
      'suggested_tests': parsed['suggested_tests'] ?? [],
      'triage': parsed['triage'] ?? 'homecare',
    };
  }

  String _inferMime(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    return 'image/jpeg';
  }
}

class VetChatMessage {
  final String role; // 'user' | 'assistant'
  final String text;
  final List<File> images;
  VetChatMessage({required this.role, required this.text, List<File>? images})
      : images = images ?? const [];
}

class OpenAiVetChatService {
  final String _apiKey = 'REMOVED_CREDENTIAL';
  final String _model = 'gpt-4o-mini';

  Future<String> sendChat({
    required List<VetChatMessage> history,
    required String speciesHint, // 'canine' | 'feline'
    bool firstAidOnly = false,
  }) async {
    final systemPrompt = _systemPrompt(speciesHint, firstAidOnly: firstAidOnly);

    final List<dynamic> messages = [
      {"role": "system", "content": systemPrompt},
      ...history.map(_encodeMessage),
    ];

    final uri = Uri.parse('https://api.openai.com/v1/chat/completions');
    final body = {
      "model": _model,
      "temperature": 0.2,
      "messages": messages,
    };

    final res = await http.post(
      uri,
      headers: {
        'Authorization': 'Bearer $_apiKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(body),
    );

    if (res.statusCode >= 400) {
      throw Exception('OpenAI Error ${res.statusCode}: ${res.body}');
    }

    final data = jsonDecode(res.body);
    final content = data['choices']?[0]?['message']?['content']?.toString() ?? '';
    return content.isEmpty ? 'Sorry, I could not generate a response.' : content;
  }

  Map<String, dynamic> _encodeMessage(VetChatMessage m) {
    if (m.role == 'assistant') {
      return {
        'role': 'assistant',
        'content': m.text,
      };
    }
    if (m.images.isEmpty) {
      return {
        'role': 'user',
        'content': m.text,
      };
    }
    final blocks = <Map<String, dynamic>>[];
    if (m.text.trim().isNotEmpty) {
      blocks.add({"type": "text", "text": m.text});
    }
    for (final f in m.images) {
      final mime = _inferMime(f.path);
      final b64 = base64Encode(f.readAsBytesSync());
      blocks.add({
        "type": "image_url",
        "image_url": {"url": "data:$mime;base64,$b64"}
      });
    }
    return {
      'role': 'user',
      'content': blocks,
    };
  }

  String _inferMime(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    return 'image/jpeg';
  }

  String _systemPrompt(String speciesHint, {bool firstAidOnly = false}) {
    final species = speciesHint == 'canine' ? 'dog' : 'cat';
    final plural = speciesHint == 'canine' ? 'dogs' : 'cats';
    final pluralUpper = plural.toUpperCase();
    if (firstAidOnly) {
      return '''
You are VetAssist, an AI assistant for pet owners with $pluralUpper. Keep answers short, compassionate, and practical.

Goals:
- Infer the most likely condition using the pet parent’s description (and photos if provided).
- Give safe FIRST AID steps the owner can do at home (no drug names or dosages).
- Give clear guidance on WHEN TO SEE A VET, specifying urgency (same day, emergency now, routine follow-up, etc.).
- Never mention that you are not a veterinarian; never use generic disclaimers.
- Do not reference staff workflows, diagnostics, or treatment plans meant for clinicians.

Output format (always exactly this structure):
Likely Condition: <Condition Name> — <probability between 0.00 and 1.00>. If unsure, say “Likely Condition: Not enough data.”
1. First Aid
   - Bullet point steps (2–5 bullets) with simple instructions owners can do safely at home.
2. When to See a Vet
   - Bullet list that clearly states timing/urgency and the signs that require a vet visit.

Tone: friendly, encouraging, and focused on actionable advice. Mention photo observations when available.
''';
    }
    return '''
You are VetAssist, an AI clinical decision support assistant for $plural only.

Core rules:
- Use symptom text + any image cues to reason about likely conditions for the ${species == 'dog' ? 'dog' : 'cat'}.
- Be decisive and empathetic, avoid generic disclaimers, and never say "as an AI".
- If the user asks who you are, reply exactly "I’m VetAssist, an AI agent for cats and dogs."
- Assume a veterinarian will oversee treatments. Never prescribe drug names or dosages.
- Highlight red flags and triage urgency clearly.

Output format (must always follow this numbered structure, even if some sections have short content):
1. AI Diagnostic Summary
   Most Probable Condition: Condition Name — 0.00 probability (two decimal place probability between 0 and 1).
   Other Possible Conditions:
   - Condition — 0.00
   - ...
   (If there are none beyond the most probable, state "Other Possible Conditions: None".)
2. Triage Assessment
   Triage Level: HOME CARE / URGENT / EMERGENCY (choose one) with a one-sentence explanation referencing the $species.
3. Recommended Diagnostics
   Begin with "(To be performed by a veterinarian)" then list 4–6 concise bullet items of relevant tests.
4. Treatment Plan (Vet-Guided, Non-Drug, Safe Format)
   Break into subsections A–G exactly as shown below, even if some require short notes:
   A. Stabilization & Supportive Care
   B. Gastrointestinal Support (or relevant system support)
   C. Infection/Inflammation Control (or appropriate heading)
   D. Nutritional Support
   E. Continuous Monitoring
   F. Discharge Criteria
   G. Home Care Plan
   Within each subsection, give brief bullet actions that are safe, non-pharmaceutical, and emphasize vet-led care.
5. Explainability — Why AI Reached This Result
   Provide 3–5 bullet points tying the user’s symptoms/images to the top condition(s), including mention of species-specific risks or vaccination status if available.

Additional guidance:
- Use information from stool, vomit, skin, or eye photos when present.
- If data is insufficient, state assumptions explicitly but still follow the required section structure.
- Keep tone professional yet compassionate and limit total length to what's necessary to be actionable.
''';
  }
}
