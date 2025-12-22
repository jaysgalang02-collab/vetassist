import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/openai_service.dart';

class CDSSChatBox extends StatefulWidget {
  final String species; // 'canine' or 'feline'
  final bool firstAidOnly; // true for customer mode
  const CDSSChatBox({super.key, required this.species, this.firstAidOnly = false});

  @override
  State<CDSSChatBox> createState() => _CDSSChatBoxState();
}

class _CDSSChatBoxState extends State<CDSSChatBox> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  final _picker = ImagePicker();

  bool _sending = false;
  final List<VetChatMessage> _messages = [];
  final List<File> _pendingImages = [];

  @override
  void initState() {
    super.initState();
    _messages.add(VetChatMessage(
      role: 'assistant',
      text: widget.firstAidOnly
          ? 'Hi! I\'m VetAssist, an AI agent for cats and dogs. Describe the symptoms and optionally add photos. I\'ll suggest the likely condition, First Aid, and when to see a vet.'
          : 'Hi! I\'m VetAssist, an AI agent for cats and dogs. Describe symptoms and optionally add photos. I\'ll suggest likely conditions, treatment plan, and protocol',
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource src) async {
    if (_pendingImages.length >= 3) return;
    final x = await _picker.pickImage(source: src, imageQuality: 92, maxWidth: 1600);
    if (x == null) return;
    setState(() => _pendingImages.add(File(x.path)));
  }

  void _showImagePickerSheet() {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: Wrap(children: [
          ListTile(
            leading: const Icon(Icons.photo_camera),
            title: const Text('Take photo'),
            onTap: () {
              Navigator.pop(context);
              _pickImage(ImageSource.camera);
            },
          ),
          ListTile(
            leading: const Icon(Icons.photo_library),
            title: const Text('Choose from gallery'),
            onTap: () {
              Navigator.pop(context);
              _pickImage(ImageSource.gallery);
            },
          ),
        ]),
      ),
    );
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty && _pendingImages.isEmpty) return;

    final userMsg = VetChatMessage(role: 'user', text: text, images: List.of(_pendingImages));
    setState(() {
      _messages.add(userMsg);
      _controller.clear();
      _pendingImages.clear();
      _sending = true;
    });

    try {
      final reply = await OpenAiVetChatService().sendChat(
        history: _messages,
        speciesHint: widget.species,
        firstAidOnly: widget.firstAidOnly,
      );
      setState(() {
        _messages.add(VetChatMessage(role: 'assistant', text: reply));
      });
      await Future<void>.delayed(const Duration(milliseconds: 50));
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent + 120,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Chat failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: cs.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.psychology_alt_outlined, size: 18),
                const SizedBox(width: 6),
                const Text('CDSS Chat', style: TextStyle(fontWeight: FontWeight.w700)),
                const Spacer(),
                Tooltip(
                  message: 'Attach image',
                  child: IconButton(
                    icon: const Icon(Icons.attach_file),
                    onPressed: _sending ? null : _showImagePickerSheet,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              widget.firstAidOnly
                  ? 'Hi! I\'m VetAssist, an AI agent for cats and dogs. Describe the symptoms and optionally add photos. I\'ll suggest the likely condition, First Aid, and when to see a vet.'
                  : 'Describe your ${widget.species == 'canine' ? 'dog' : 'cat'}\'s issue. Add photos of the pet, stool, vomit, eyes, or skin for better assessment.',
              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
            ),
            const SizedBox(height: 8),
            if (_pendingImages.isNotEmpty)
              SizedBox(
                height: 72,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _pendingImages.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, i) => Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.file(_pendingImages[i], width: 72, height: 72, fit: BoxFit.cover),
                      ),
                      Positioned(
                        top: 2,
                        right: 2,
                        child: InkWell(
                          onTap: _sending
                              ? null
                              : () => setState(() => _pendingImages.removeAt(i)),
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.all(2),
                            child: const Icon(Icons.close, size: 16, color: Colors.white),
                          ),
                        ),
                      )
                    ],
                  ),
                ),
              ),
            if (_pendingImages.isNotEmpty) const SizedBox(height: 8),

            Container(
              constraints: const BoxConstraints(maxHeight: 280, minHeight: 160),
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: ListView.builder(
                  controller: _scroll,
                  itemCount: _messages.length,
                  itemBuilder: (_, i) {
                    final m = _messages[i];
                    final isUser = m.role == 'user';
                    return Align(
                      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        padding: const EdgeInsets.all(10),
                        constraints: const BoxConstraints(maxWidth: 480),
                        decoration: BoxDecoration(
                          color: isUser ? cs.primaryContainer : cs.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment:
                              isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                          children: [
                            if (m.images.isNotEmpty)
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: m.images
                                    .map((f) => ClipRRect(
                                          borderRadius: BorderRadius.circular(8),
                                          child: Image.file(f, width: 84, height: 84, fit: BoxFit.cover),
                                        ))
                                    .toList(),
                              ),
                            if (m.images.isNotEmpty) const SizedBox(height: 6),
                            Text(m.text),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    minLines: 1,
                    maxLines: 4,
                    textInputAction: TextInputAction.newline,
                    decoration: const InputDecoration(
                      hintText: 'Type a message…',
                    ),
                    onSubmitted: (_) {},
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: _sending ? null : _send,
                  icon: _sending
                      ? const SizedBox(
                          width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.send),
                  label: const Text('Send'),
                )
              ],
            ),
          ],
        ),
      ),
    );
  }
}
