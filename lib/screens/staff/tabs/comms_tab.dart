import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../utils/toast.dart';
import '../staff_common.dart';

class CommsTab extends StatefulWidget {
  final String clinicId;
  final String staffUid;
  final bool isActive;
  const CommsTab(
      {super.key,
      required this.clinicId,
      required this.staffUid,
      this.isActive = true});

  @override
  State<CommsTab> createState() => CommsTabState();
}

class CommsTabState extends State<CommsTab> {
  bool _composing = false;
  _OwnerOption? _selectedCustomer;
  String? _selectedPatientId;

  final _titleCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();

  @override
  void didUpdateWidget(covariant CommsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.isActive) _composing = false;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final ownerUid = _selectedCustomer?.uid;
    final ownerName = _selectedCustomer?.label;
    final title = _titleCtrl.text.trim();
    final body = _bodyCtrl.text.trim();

    if (ownerUid == null || ownerUid.isEmpty) {
      toast(context, 'Please choose a customer.');
      return;
    }
    if (title.isEmpty || body.isEmpty) {
      toast(context, 'Title and message are required.');
      return;
    }

    await FirebaseFirestore.instance
        .collection('users')
        .doc(ownerUid)
        .collection('inbox')
        .add({
      'ownerUid': ownerUid,
      if (ownerName != null && ownerName.isNotEmpty) 'ownerName': ownerName,
      'title': title,
      'body': body,
      if (_selectedPatientId != null) 'patientId': _selectedPatientId,
      'fromStaffUid': widget.staffUid,
      'clinicId': widget.clinicId,
      'read': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
    try {
      await FirebaseFirestore.instance
          .collection('clinic_inbox')
          .doc(widget.clinicId)
          .collection('messages')
          .add({
        'ownerUid': ownerUid,
        'ownerName': ownerName,
        'title': title,
        'body': body,
        if (_selectedPatientId != null) 'patientId': _selectedPatientId,
        'fromStaffUid': widget.staffUid,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {}

    if (!mounted) return;
    toast(context, 'Message sent.');
    _titleCtrl.clear();
    _bodyCtrl.clear();
    setState(() {
      _composing = false;
      _selectedPatientId = null;
    });
  }

  void _handleThreadTap(String ownerUid, String ownerName) {
    setState(() {
      _selectedCustomer = _OwnerOption(uid: ownerUid, label: ownerName);
      _selectedPatientId = null;
    });
  }

  Future<void> _openConversation(
    _OwnerOption owner, {
    String? focusMessageId,
  }) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => FractionallySizedBox(
        heightFactor: 0.92,
        child: _ConversationSheet(
          owner: owner,
          clinicId: widget.clinicId,
          staffUid: widget.staffUid,
          focusMessageId: focusMessageId,
        ),
      ),
    );
  }

  Future<void> focusMessageFromNotification(String messageId) async {
    if (messageId.trim().isEmpty) return;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('clinic_inbox')
          .doc(widget.clinicId)
          .collection('messages')
          .doc(messageId)
          .get();
      if (!doc.exists) return;
      final data = doc.data();
      if (data == null) return;
      final ownerUid = (data['ownerUid'] as String?)?.trim();
      if (ownerUid == null || ownerUid.isEmpty) return;
      final ownerName = (data['ownerName'] as String?)?.trim();
      final owner = _OwnerOption(
        uid: ownerUid,
        label: ownerName != null && ownerName.isNotEmpty
            ? ownerName
            : _shortUid(ownerUid),
      );
      if (!mounted) return;
      _handleThreadTap(owner.uid, owner.label);
      await _openConversation(owner, focusMessageId: messageId);
    } catch (_) {
      if (mounted) {
        toast(context, 'Could not open this conversation. Please try again.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final composePane = Section(
      title: 'Send a message to customer',
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _CustomerDropdown(
              clinicId: widget.clinicId,
              selected: _selectedCustomer,
              onChanged: (opt) {
                if (opt == null) {
                  setState(() {
                    _selectedCustomer = null;
                    _selectedPatientId = null;
                  });
                } else {
                  _handleThreadTap(opt.uid, opt.label);
                }
              },
            ),
            const SizedBox(height: 8),
            _PetDropdown(
              ownerUid: _selectedCustomer?.uid,
              selectedPatientId: _selectedPatientId,
              onChanged: (pid) => setState(() => _selectedPatientId = pid),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _titleCtrl,
              decoration: const InputDecoration(
                labelText: 'Title',
                prefixIcon: Icon(Icons.title),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _bodyCtrl,
              maxLines: 6,
              decoration: const InputDecoration(
                labelText: 'Message',
                alignLabelWithHint: true,
                prefixIcon: Icon(Icons.message_outlined),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _send,
              icon: const Icon(Icons.send),
              label: const Text('Send'),
            ),
          ],
        ),
      ),
    );

    final inboxPane = Section(
      title: 'Customer conversations',
      child: _ConversationList(
        clinicId: widget.clinicId,
        selectedOwnerUid: _selectedCustomer?.uid,
        onSelect: (owner) {
          _handleThreadTap(owner.uid, owner.label);
          _openConversation(owner);
        },
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 900;
        if (!isWide) {
          if (_composing) {
            return PopScope(
              canPop: !widget.isActive,
              onPopInvokedWithResult: (didPop, result) {
                if (!didPop && widget.isActive) {
                  setState(() => _composing = false);
                }
              },
              child: Column(children: [
                Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () => setState(() => _composing = false),
                      icon: const Icon(Icons.arrow_back_rounded),
                      label: const Text('Back to conversations'),
                    )),
                Expanded(child: composePane),
              ]),
            );
          }
          return Column(children: [
            Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => setState(() => _composing = true),
                    icon: const Icon(Icons.edit_square),
                    label: const Text('New message'),
                  ),
                )),
            Expanded(child: inboxPane),
          ]);
        }
        return Flex(
          direction: isWide ? Axis.horizontal : Axis.vertical,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: composePane),
            SizedBox(width: isWide ? 16 : 0, height: isWide ? 0 : 16),
            Expanded(child: inboxPane),
          ],
        );
      },
    );
  }
}

class _CustomerDropdown extends StatelessWidget {
  final String clinicId;
  final _OwnerOption? selected;
  final ValueChanged<_OwnerOption?> onChanged;

  const _CustomerDropdown({
    required this.clinicId,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final customerQuery = FirebaseFirestore.instance
        .collection('users')
        .where('clinicId', isEqualTo: clinicId)
        .where('role', isEqualTo: 'customer')
        .orderBy('displayName');

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: customerQuery.snapshots(),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const ListTile(
            leading: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2)),
            title: Text('Loading customers...'),
          );
        }
        if (snap.hasError) {
          return ListTile(
            leading:
                const Icon(Icons.warning_amber_rounded, color: Colors.orange),
            title: const Text('Cannot load customers'),
            subtitle: Text('${snap.error}'),
          );
        }

        final docs = snap.data?.docs ?? const [];
        final ownerOptions = docs.map((doc) {
          final data = doc.data();
          final uid = doc.id;
          final displayName = (data['displayName'] as String?)?.trim();
          final email = (data['email'] as String?)?.trim();
          final label = (displayName != null && displayName.isNotEmpty)
              ? displayName
              : (email != null && email.isNotEmpty ? email : _shortUid(uid));
          return _OwnerOption(uid: uid, label: label);
        }).toList()
          ..sort(
              (a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()));

        if (ownerOptions.isEmpty) {
          return const ListTile(
            leading: Icon(Icons.person_outline),
            title: Text('No customers found'),
            subtitle: Text('Add patients first to message their owners.'),
          );
        }

        _OwnerOption? selectedOption;
        if (selected != null) {
          for (final opt in ownerOptions) {
            if (opt.uid == selected!.uid) {
              selectedOption = opt;
              break;
            }
          }
        }

        return DropdownButtonFormField<_OwnerOption>(
          value: selectedOption,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Customer',
            prefixIcon: Icon(Icons.person_outline),
          ),
          items: ownerOptions
              .map((opt) => DropdownMenuItem<_OwnerOption>(
                    value: opt,
                    child: Text(opt.label,
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                  ))
              .toList(),
          onChanged: onChanged,
        );
      },
    );
  }
}

class _PetDropdown extends StatelessWidget {
  final String? ownerUid;
  final String? selectedPatientId;
  final ValueChanged<String?> onChanged;

  const _PetDropdown({
    required this.ownerUid,
    required this.selectedPatientId,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    if (ownerUid == null) {
      return TextFormField(
        readOnly: true,
        decoration: const InputDecoration(
          labelText: 'Pet (optional)',
          hintText: 'Choose a customer first',
          prefixIcon: Icon(Icons.pets_outlined),
        ),
      );
    }

    final q = FirebaseFirestore.instance
        .collection('patients')
        .where('ownerUid', isEqualTo: ownerUid);

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: q.snapshots(),
      builder: (ctx, snap) {
        if (!snap.hasData) {
          return const ListTile(
            leading: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            title: Text('Loading pets...'),
          );
        }
        final docs = snap.data!.docs;
        final petEntries = docs.map((d) {
          final data = d.data();
          final name = (data['name'] as String?)?.trim();
          return {
            'id': d.id,
            'name': (name != null && name.isNotEmpty) ? name : d.id,
          };
        }).toList()
          ..sort((a, b) => (a['name'] as String)
              .toLowerCase()
              .compareTo((b['name'] as String).toLowerCase()));

        return DropdownButtonFormField<String?>(
          value: selectedPatientId,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Pet (optional)',
            prefixIcon: Icon(Icons.pets_outlined),
          ),
          items: <DropdownMenuItem<String?>>[
            const DropdownMenuItem<String?>(
              value: null,
              child: Text('No pet selected'),
            ),
            ...petEntries.map((entry) => DropdownMenuItem<String?>(
                  value: entry['id'] as String,
                  child: Text(
                    entry['name'] as String,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                )),
          ],
          onChanged: onChanged,
        );
      },
    );
  }
}

class _OwnerOption {
  final String uid;
  final String label;
  const _OwnerOption({required this.uid, required this.label});
}

String _shortUid(String uid) {
  if (uid.length <= 8) return uid;
  return '${uid.substring(0, 4)}...${uid.substring(uid.length - 4)}';
}

class _ConversationList extends StatelessWidget {
  final String clinicId;
  final ValueChanged<_OwnerOption> onSelect;
  final String? selectedOwnerUid;
  const _ConversationList({
    required this.clinicId,
    required this.onSelect,
    this.selectedOwnerUid,
  });

  @override
  Widget build(BuildContext context) {
    final stream = FirebaseFirestore.instance
        .collection('clinic_inbox')
        .doc(clinicId)
        .collection('messages')
        .orderBy('createdAt', descending: true)
        .limit(200)
        .snapshots();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: stream,
      builder: (ctx, snap) {
        if (snap.hasError) {
          return Center(
            child: Text(
              'Unable to load messages.\n${snap.error}',
              textAlign: TextAlign.center,
            ),
          );
        }
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snap.data?.docs ?? const [];
        final threads = _buildSummaries(docs);
        if (threads.isEmpty) {
          return const Center(child: Text('No conversations yet.'));
        }

        final cs = Theme.of(context).colorScheme;
        return ListView.separated(
          padding: const EdgeInsets.all(8),
          itemCount: threads.length,
          separatorBuilder: (_, __) => const SizedBox(height: 6),
          itemBuilder: (_, i) {
            final thread = threads[i];
            final isSelected = selectedOwnerUid == thread.ownerUid;
            final tileColor = Color.lerp(
                    cs.surface, cs.primaryContainer, isSelected ? 0.35 : 0.0) ??
                cs.surface;
            final option =
                _OwnerOption(uid: thread.ownerUid, label: thread.displayName);
            final preview = _buildPreview(thread);
            final timestamp = _formatThreadTimestamp(thread.lastTimestamp);

            return Material(
              color: tileColor,
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => onSelect(option),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        backgroundColor: cs.primaryContainer,
                        child: Text(
                          thread.displayName.isNotEmpty
                              ? thread.displayName[0].toUpperCase()
                              : '?',
                          style: TextStyle(color: cs.onPrimaryContainer),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    thread.displayName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontWeight: thread.unreadCount > 0
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  timestamp,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: cs.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              preview,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: cs.onSurfaceVariant,
                                fontWeight: thread.unreadCount > 0
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      thread.unreadCount > 0
                          ? _UnreadBubble(count: thread.unreadCount)
                          : Icon(Icons.chevron_right,
                              color: cs.onSurfaceVariant),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  List<_ThreadSummary> _buildSummaries(
      List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    final Map<String, _ThreadSummary> map = {};
    for (final doc in docs) {
      final data = doc.data();
      final ownerUid = (data['ownerUid'] ?? '').toString();
      if (ownerUid.isEmpty) continue;
      final ownerName = (data['ownerName'] as String?)?.trim();
      final displayName = (ownerName != null && ownerName.isNotEmpty)
          ? ownerName
          : _shortUid(ownerUid);
      final title = (data['title'] as String?)?.trim();
      final body = (data['body'] as String?)?.trim() ?? '';
      final created = data['createdAt'] as Timestamp?;
      final fromStaff = (data['fromStaffUid'] as String?)?.isNotEmpty == true;
      final fromOwner = (data['fromOwnerUid'] as String?)?.isNotEmpty == true;
      final isUnread = fromOwner && data['read'] != true;

      final existing = map[ownerUid];
      if (existing == null) {
        map[ownerUid] = _ThreadSummary(
          ownerUid: ownerUid,
          displayName: displayName,
          lastBody: body,
          lastTitle: title?.isNotEmpty == true ? title : null,
          lastTimestamp: created,
          lastFromStaff: fromStaff,
          unreadCount: isUnread ? 1 : 0,
        );
      } else {
        final additionalUnread = isUnread ? 1 : 0;
        map[ownerUid] = existing.copyWith(
            unreadCount: existing.unreadCount + additionalUnread);
      }
    }

    final list = map.values.toList()
      ..sort((a, b) {
        final aMs = a.lastTimestamp?.millisecondsSinceEpoch ?? 0;
        final bMs = b.lastTimestamp?.millisecondsSinceEpoch ?? 0;
        return bMs.compareTo(aMs);
      });

    return list;
  }

  String _buildPreview(_ThreadSummary thread) {
    final buffer = StringBuffer();
    buffer.write(thread.lastFromStaff ? 'You: ' : 'Customer: ');
    if (thread.lastTitle != null && thread.lastTitle!.isNotEmpty) {
      buffer.write('${thread.lastTitle} - ');
    }
    buffer.write(thread.lastBody.isNotEmpty ? thread.lastBody : '(no message)');
    return buffer.toString();
  }
}

class _ThreadSummary {
  final String ownerUid;
  final String displayName;
  final String? lastTitle;
  final String lastBody;
  final Timestamp? lastTimestamp;
  final bool lastFromStaff;
  final int unreadCount;

  _ThreadSummary({
    required this.ownerUid,
    required this.displayName,
    required this.lastBody,
    required this.lastTimestamp,
    required this.lastFromStaff,
    this.lastTitle,
    this.unreadCount = 0,
  });

  _ThreadSummary copyWith({int? unreadCount}) {
    return _ThreadSummary(
      ownerUid: ownerUid,
      displayName: displayName,
      lastBody: lastBody,
      lastTimestamp: lastTimestamp,
      lastFromStaff: lastFromStaff,
      lastTitle: lastTitle,
      unreadCount: unreadCount ?? this.unreadCount,
    );
  }
}

class _UnreadBubble extends StatelessWidget {
  final int count;
  const _UnreadBubble({required this.count});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = count > 9 ? '9+' : count.toString();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: cs.primary,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: cs.surface, width: 1.5),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 1)),
        ],
      ),
      child: Text(
        text,
        style: TextStyle(
          color: cs.onPrimary,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

String _formatThreadTimestamp(Timestamp? ts) {
  if (ts == null) return '';
  final dt = ts.toDate();
  final now = DateTime.now();
  if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final minute = dt.minute.toString().padLeft(2, '0');
    final suffix = dt.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $suffix';
  }
  if (dt.year == now.year) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[dt.month - 1]} ${dt.day}';
  }
  return '${dt.month}/${dt.day}/${dt.year}';
}

class _ConversationSheet extends StatefulWidget {
  final _OwnerOption owner;
  final String clinicId;
  final String staffUid;
  final String? focusMessageId;
  const _ConversationSheet({
    required this.owner,
    required this.clinicId,
    required this.staffUid,
    this.focusMessageId,
  });

  @override
  State<_ConversationSheet> createState() => _ConversationSheetState();
}

class _ConversationSheetState extends State<_ConversationSheet> {
  final _messageCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final Map<String, GlobalKey> _messageKeys = {};
  bool _sending = false;
  bool _markingRead = false;
  bool _focusHandled = false;

  @override
  void dispose() {
    _messageCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> get _stream =>
      FirebaseFirestore.instance
          .collection('clinic_inbox')
          .doc(widget.clinicId)
          .collection('messages')
          .where('ownerUid', isEqualTo: widget.owner.uid)
          .orderBy('createdAt')
          .snapshots();

  Future<void> _send() async {
    final text = _messageCtrl.text.trim();
    if (text.isEmpty) return;

    setState(() => _sending = true);
    final payload = {
      'ownerUid': widget.owner.uid,
      'ownerName': widget.owner.label,
      'title': 'Message from staff',
      'body': text,
      'fromStaffUid': widget.staffUid,
      'clinicId': widget.clinicId,
      'read': false,
      'createdAt': FieldValue.serverTimestamp(),
    };

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.owner.uid)
          .collection('inbox')
          .add(payload);
      await FirebaseFirestore.instance
          .collection('clinic_inbox')
          .doc(widget.clinicId)
          .collection('messages')
          .add(payload);
      _messageCtrl.clear();
      await Future<void>.delayed(const Duration(milliseconds: 40));
      _scrollToBottom(animated: true);
    } catch (e) {
      if (mounted) {
        toast(context, 'Failed to send: $e');
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _scrollToBottom({bool animated = false}) {
    if (!_scrollCtrl.hasClients) return;
    final offset = _scrollCtrl.position.maxScrollExtent + 60;
    if (animated) {
      _scrollCtrl.animateTo(
        offset,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    } else {
      _scrollCtrl.jumpTo(offset);
    }
  }

  Future<void> _markMessagesRead(
      List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) async {
    if (_markingRead) return;
    final unread = docs.where((d) {
      final data = d.data();
      final fromOwner = (data['fromOwnerUid'] as String?)?.isNotEmpty == true;
      return fromOwner && data['read'] != true;
    }).toList();
    if (unread.isEmpty) return;
    _markingRead = true;
    try {
      final batch = FirebaseFirestore.instance.batch();
      for (final doc in unread) {
        batch.update(doc.reference, {'read': true});
      }
      await batch.commit();
    } catch (_) {
    } finally {
      _markingRead = false;
    }
  }

  bool _focusTargetMessage(
      List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    final targetId = widget.focusMessageId;
    if (_focusHandled || targetId == null || targetId.isEmpty) return false;
    final exists = docs.any((d) => d.id == targetId);
    if (!exists) return false;
    final key = _messageKeys[targetId];
    final ctx = key?.currentContext;
    if (ctx != null) {
      _focusHandled = true;
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOut,
        alignment: 0.2,
      );
      return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.surface,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 8, 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.owner.label,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        'Customer chat',
                        style: TextStyle(color: cs.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                )
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _stream,
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final docs = snap.data?.docs ?? const [];
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _markMessagesRead(docs);
                  final focused = _focusTargetMessage(docs);
                  if (!focused) {
                    _scrollToBottom();
                  }
                });
                if (docs.isEmpty) {
                  return const Center(
                    child: Text('No messages yet. Start the conversation!'),
                  );
                }

                return ListView.builder(
                  controller: _scrollCtrl,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final data = doc.data();
                    final key =
                        _messageKeys.putIfAbsent(doc.id, () => GlobalKey());
                    final fromStaff =
                        (data['fromStaffUid'] as String?)?.isNotEmpty == true;
                    final fromOwner =
                        (data['fromOwnerUid'] as String?)?.isNotEmpty == true;
                    final isOwner = fromOwner && !fromStaff;
                    final title = (data['title'] as String?) ?? '';
                    final body = (data['body'] as String?) ?? '';
                    final created = data['createdAt'] as Timestamp?;
                    final bubbleColor = isOwner
                        ? cs.surfaceContainerHighest
                        : cs.primaryContainer;
                    final alignment =
                        isOwner ? Alignment.centerLeft : Alignment.centerRight;
                    final textAlign = isOwner
                        ? CrossAxisAlignment.start
                        : CrossAxisAlignment.end;

                    return Align(
                      key: key,
                      alignment: alignment,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        padding: const EdgeInsets.all(12),
                        constraints: const BoxConstraints(maxWidth: 420),
                        decoration: BoxDecoration(
                          color: bubbleColor,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          crossAxisAlignment: textAlign,
                          children: [
                            if (title.trim().isNotEmpty)
                              Text(
                                title,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                                textAlign:
                                    isOwner ? TextAlign.left : TextAlign.right,
                              ),
                            if (title.trim().isNotEmpty)
                              const SizedBox(height: 4),
                            Text(
                              body,
                              textAlign:
                                  isOwner ? TextAlign.left : TextAlign.right,
                            ),
                            if (created != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  _formatThreadTimestamp(created),
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: cs.onSurfaceVariant,
                                  ),
                                  textAlign: isOwner
                                      ? TextAlign.left
                                      : TextAlign.right,
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
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
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
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
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
}
