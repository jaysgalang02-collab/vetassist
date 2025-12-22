import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../utils/toast.dart';

class UserChatScreen extends StatefulWidget {
  static const route = '/chat';
  const UserChatScreen({super.key});

  @override
  State<UserChatScreen> createState() => _UserChatScreenState();
}

class _UserChatScreenState extends State<UserChatScreen> {
  final _messageCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  bool _sending = false;
  bool _loadingProfile = true;
  bool _markingRead = false;
  String? _clinicId;
  String? _ownerName;
  String? _ownerEmail;

  String get _uid => FirebaseAuth.instance.currentUser!.uid;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _messageCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    setState(() => _loadingProfile = true);
    try {
      final doc =
          await FirebaseFirestore.instance.collection('users').doc(_uid).get();
      final data = doc.data();
      if (data != null) {
        setState(() {
          _clinicId = data['clinicId'] as String?;
          _ownerName = (data['displayName'] as String?)?.trim();
          _ownerEmail = data['email'] as String?;
        });
      }
    } catch (_) {
      // ignore
    } finally {
      if (mounted) setState(() => _loadingProfile = false);
    }
  }

  Stream<QuerySnapshot<Map<String, dynamic>>>? get _inboxStream {
    if (_clinicId == null) return null;
    return FirebaseFirestore.instance
        .collection('users')
        .doc(_uid)
        .collection('inbox')
        .orderBy('createdAt')
        .snapshots();
  }

  Future<void> _send() async {
    final text = _messageCtrl.text.trim();
    final clinicId = _clinicId;
    if (text.isEmpty || clinicId == null) return;

    setState(() => _sending = true);
    final ownerLabel =
        (_ownerName != null && _ownerName!.isNotEmpty) ? _ownerName! : (_ownerEmail ?? 'Owner');

    try {
      final payload = {
        'ownerUid': _uid,
        'ownerName': ownerLabel,
        'body': text,
        'title': 'Message from owner',
        'fromOwnerUid': _uid,
        'clinicId': clinicId,
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
      };

      await FirebaseFirestore.instance
          .collection('users')
          .doc(_uid)
          .collection('inbox')
          .add(payload);

      await FirebaseFirestore.instance
          .collection('clinic_inbox')
          .doc(clinicId)
          .collection('messages')
          .add(payload);

      _messageCtrl.clear();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent + 120,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    } catch (e) {
      if (mounted) {
        toast(context, 'Failed to send: $e');
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chat with clinic'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loadingProfile ? null : _loadProfile,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loadingProfile
          ? const Center(child: CircularProgressIndicator())
          : _clinicId == null
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'Your account is not yet linked to a clinic. Please contact support or update your profile.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : Column(
                  children: [
                    Expanded(
                      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                        stream: _inboxStream,
                        builder: (context, snap) {
                          if (snap.connectionState == ConnectionState.waiting) {
                            return const Center(child: CircularProgressIndicator());
                          }
                          final docs = snap.data?.docs ?? const [];
                          if (docs.isNotEmpty) {
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              _markMessagesRead(docs);
                            });
                          }
                          if (docs.isEmpty) {
                            return const Center(
                              child: Padding(
                                padding: EdgeInsets.all(24.0),
                                child: Text(
                                  'No messages yet. Say hello to your clinic!',
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            );
                          }
                          return ListView.builder(
                            controller: _scrollCtrl,
                            padding: const EdgeInsets.all(16),
                            itemCount: docs.length,
                            itemBuilder: (context, index) {
                              final data = docs[index].data();
                              final fromStaff = (data['fromStaffUid'] as String?)
                                      ?.isNotEmpty ==
                                  true;
                              final isOwner = !fromStaff;
                              final title = (data['title'] as String?) ?? '';
                              final body = (data['body'] as String?) ?? '';
                              final created = data['createdAt'] as Timestamp?;

                              return Align(
                                alignment: isOwner
                                    ? Alignment.centerRight
                                    : Alignment.centerLeft,
                                child: Container(
                                  margin: const EdgeInsets.symmetric(vertical: 6),
                                  padding: const EdgeInsets.all(12),
                                  constraints:
                                      const BoxConstraints(maxWidth: 420),
                                  decoration: BoxDecoration(
                                    color: isOwner
                                        ? cs.primaryContainer
                                        : cs.surfaceContainerHighest,
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: isOwner
                                        ? CrossAxisAlignment.end
                                        : CrossAxisAlignment.start,
                                    children: [
                                      if (title.isNotEmpty)
                                        Text(
                                          title,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w700),
                                        ),
                                      if (title.isNotEmpty)
                                        const SizedBox(height: 4),
                                      Text(body),
                                      if (created != null)
                                        Padding(
                                          padding:
                                              const EdgeInsets.only(top: 4.0),
                                          child: Text(
                                            _formatTs(created),
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: cs.onSurfaceVariant,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                    SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _messageCtrl,
                                minLines: 1,
                                maxLines: 4,
                                decoration: const InputDecoration(
                                  hintText: 'Type a message...',
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            FilledButton.icon(
                              onPressed: _sending ? null : _send,
                              icon: _sending
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2))
                                  : const Icon(Icons.send),
                              label: const Text('Send'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }

  Future<void> _markMessagesRead(
      List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) async {
    if (_markingRead) return;
    final unread = docs.where((d) => d.data()['read'] != true).toList();
    if (unread.isEmpty) return;
    _markingRead = true;
    try {
      final batch = FirebaseFirestore.instance.batch();
      for (final doc in unread) {
        batch.update(doc.reference, {'read': true});
      }
      await batch.commit();
    } catch (_) {
      // ignore
    } finally {
      _markingRead = false;
    }
  }

  String _formatTs(Timestamp ts) {
    final dt = ts.toDate();
    final now = DateTime.now();
    if (dt.year == now.year &&
        dt.month == now.month &&
        dt.day == now.day) {
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }
    return '${dt.month}/${dt.day}/${dt.year}';
  }
}
