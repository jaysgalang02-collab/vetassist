import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../widgets/brand_widgets.dart';

class BookVisitScreen extends StatefulWidget {
  static const route = '/book-visit';
  const BookVisitScreen({super.key});

  @override
  State<BookVisitScreen> createState() => _BookVisitScreenState();
}

class _BookVisitScreenState extends State<BookVisitScreen> {
  final _notesCtrl = TextEditingController();

  bool _loadingProfile = true;
  bool _submitting = false;

  String? _clinicId;
  String? _clinicName;
  String? _ownerName;

  String? _selectedPatientId;
  String? _selectedPatientName;

  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  String? _selectedSlotId;

  String get _uid => FirebaseAuth.instance.currentUser!.uid;

  Stream<QuerySnapshot<Map<String, dynamic>>>
      _bookingStatusNotificationStream() {
    return FirebaseFirestore.instance
        .collection('notifications')
        .doc(_uid)
        .collection('items')
        .where('type', isEqualTo: 'booking_status')
        .where('read', isEqualTo: false)
        .snapshots();
  }

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    setState(() => _loadingProfile = true);
    try {
      final userDoc =
          await FirebaseFirestore.instance.collection('users').doc(_uid).get();
      final data = userDoc.data();
      if (data != null) {
        final clinicId = (data['clinicId'] as String?)?.trim();
        String? clinicName;
        if (clinicId != null && clinicId.isNotEmpty) {
          final clinicDoc = await FirebaseFirestore.instance
              .collection('clinics')
              .doc(clinicId)
              .get();
          clinicName = (clinicDoc.data()?['name'] as String?)?.trim();
        }
        if (!mounted) return;
        setState(() {
          _clinicId = clinicId;
          _clinicName = clinicName;
          _ownerName = (data['displayName'] as String?)?.trim();
        });
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loadingProfile = false);
    }
  }

  String _dateKey(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  String _dateLabel(DateTime d) {
    const months = [
      '',
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
    final m = months[d.month];
    return '$m ${d.day}, ${d.year}';
  }

  String _timeKey(TimeOfDay t) {
    final hh = t.hour.toString().padLeft(2, '0');
    final mm = t.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  String _timeLabel(TimeOfDay t) {
    final h = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
    final mm = t.minute.toString().padLeft(2, '0');
    final suffix = t.period == DayPeriod.am ? 'AM' : 'PM';
    return '$h:$mm $suffix';
  }

  Future<bool> _isSlotTaken(
      String clinicId, String dateKey, String timeKey) async {
    final q = await FirebaseFirestore.instance
        .collection('bookings')
        .where('clinicId', isEqualTo: clinicId)
        .where('dateKey', isEqualTo: dateKey)
        .where('timeKey', isEqualTo: timeKey)
        .where('status', whereIn: ['pending', 'approved'])
        .limit(1)
        .get();
    return q.docs.isNotEmpty;
  }

  Future<void> _submit() async {
    final clinicId = _clinicId;
    if (clinicId == null || clinicId.isEmpty) return;

    if (_selectedPatientId == null) {
      _showSnack('Please select a pet.');
      return;
    }
    if (_selectedDate == null || _selectedTime == null) {
      _showSnack('Please choose a date and time.');
      return;
    }

    final dateKey = _dateKey(_selectedDate!);
    final timeKey = _timeKey(_selectedTime!);

    setState(() => _submitting = true);
    try {
      final taken = await _isSlotTaken(clinicId, dateKey, timeKey);
      if (taken) {
        _showSnack('That date/time is already taken. Please choose another.');
        return;
      }

      final bookingRef =
          FirebaseFirestore.instance.collection('bookings').doc();
      final ownerLabel = (_ownerName != null && _ownerName!.isNotEmpty)
          ? _ownerName!
          : (FirebaseAuth.instance.currentUser?.email ?? _uid);

      final payload = {
        'clinicId': clinicId,
        'clinicName': _clinicName,
        'ownerUid': _uid,
        'ownerName': ownerLabel,
        'patientId': _selectedPatientId,
        'patientName': _selectedPatientName,
        'dateKey': dateKey,
        'timeKey': timeKey,
        'requestedDate': Timestamp.fromDate(_selectedDate!),
        'requestedTime': timeKey,
        'slotId': _selectedSlotId,
        'notes': _notesCtrl.text.trim(),
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await bookingRef.set(payload);
      await _notifyClinic(
        bookingId: bookingRef.id,
        ownerLabel: ownerLabel,
        dateKey: dateKey,
        timeKey: timeKey,
      );

      _showSnack('Appointment request sent. Waiting for clinic approval.');
      _notesCtrl.clear();
      if (!mounted) return;
      setState(() {
        _selectedSlotId = null;
      });
    } catch (e) {
      _showSnack('Failed to send request: $e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _notifyClinic({
    required String bookingId,
    required String ownerLabel,
    required String dateKey,
    required String timeKey,
  }) async {
    final clinicId = _clinicId;
    if (clinicId == null) return;

    final body = '$ownerLabel requested $dateKey at $timeKey';
    final data = {
      'type': 'booking_request',
      'title': 'New booking request',
      'body': body,
      'bookingId': bookingId,
      'ownerUid': _uid,
      'ownerName': ownerLabel,
      'patientId': _selectedPatientId,
      'patientName': _selectedPatientName,
      'dateKey': dateKey,
      'timeKey': timeKey,
      'read': false,
      'createdAt': FieldValue.serverTimestamp(),
    };

    await FirebaseFirestore.instance
        .collection('clinic_notifications')
        .doc(clinicId)
        .collection('items')
        .add(data);

    await FirebaseFirestore.instance.collection('notification_queue').add({
      'target': 'clinic',
      'clinicId': clinicId,
      'title': data['title'],
      'body': data['body'],
      'type': 'booking_request',
      'bookingId': bookingId,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _markNotificationRead(String docId) async {
    await FirebaseFirestore.instance
        .collection('notifications')
        .doc(_uid)
        .collection('items')
        .doc(docId)
        .update({
      'read': true,
      'readAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _markAllNotificationsRead(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) async {
    if (docs.isEmpty) return;
    final batch = FirebaseFirestore.instance.batch();
    for (final d in docs) {
      batch.update(d.reference, {
        'read': true,
        'readAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  }

  String _tsLabel(Timestamp? ts) {
    if (ts == null) return '';
    final dt = ts.toDate();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(dt.year, dt.month, dt.day);
    final hh = (dt.hour % 12 == 0 ? 12 : dt.hour % 12).toString();
    final mm = dt.minute.toString().padLeft(2, '0');
    final suffix = dt.hour >= 12 ? 'PM' : 'AM';
    if (d == today) return '$hh:$mm $suffix';
    return '${dt.month}/${dt.day} $hh:$mm $suffix';
  }

  Future<void> _openStatusNotifications() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _bookingStatusNotificationStream(),
              builder: (context, snap) {
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final docs = [...snap.data!.docs]..sort((a, b) {
                    final ta = (a.data()['createdAt'] as Timestamp?)
                            ?.millisecondsSinceEpoch ??
                        0;
                    final tb = (b.data()['createdAt'] as Timestamp?)
                            ?.millisecondsSinceEpoch ??
                        0;
                    return tb.compareTo(ta);
                  });
                return Column(
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Booking status updates',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w700),
                          ),
                        ),
                        TextButton(
                          onPressed: docs.isEmpty
                              ? null
                              : () async {
                                  await _markAllNotificationsRead(docs);
                                },
                          child: const Text('Mark all read'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    if (docs.isEmpty)
                      const Expanded(
                        child: Center(
                          child: Text('No new booking updates.'),
                        ),
                      )
                    else
                      Expanded(
                        child: ListView.separated(
                          itemCount: docs.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (_, i) {
                            final d = docs[i];
                            final data = d.data();
                            final title =
                                (data['title'] as String?) ?? 'Booking update';
                            final body = (data['body'] as String?) ?? '';
                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(
                                  Icons.notifications_active_outlined),
                              title: Text(title,
                                  maxLines: 1, overflow: TextOverflow.ellipsis),
                              subtitle: Text(body,
                                  maxLines: 2, overflow: TextOverflow.ellipsis),
                              trailing: Text(
                                _tsLabel(data['createdAt'] as Timestamp?),
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              onTap: () async {
                                await _markNotificationRead(d.id);
                              },
                            );
                          },
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final initial = _selectedDate ?? now;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 2),
    );
    if (picked == null) return;
    setState(() {
      _selectedDate = DateTime(picked.year, picked.month, picked.day);
      _selectedSlotId = null;
    });
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? const TimeOfDay(hour: 9, minute: 0),
    );
    if (picked == null) return;
    setState(() {
      _selectedTime = picked;
      _selectedSlotId = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (_loadingProfile) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_clinicId == null || _clinicId!.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Book Visit')),
        body: const Center(
          child: Text('No clinic assigned yet. Please contact support.'),
        ),
      );
    }

    final selectedDateLabel =
        _selectedDate == null ? 'Select date' : _dateLabel(_selectedDate!);
    final selectedTimeLabel =
        _selectedTime == null ? 'Select time' : _timeLabel(_selectedTime!);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Book Visit'),
        actions: [
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _bookingStatusNotificationStream(),
            builder: (context, snap) {
              final count = snap.data?.docs.length ?? 0;
              final label = count > 9 ? '9+' : '$count';
              return IconButton(
                tooltip: 'Booking updates',
                onPressed: _openStatusNotifications,
                icon: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    const Icon(Icons.notifications_none_rounded),
                    if (count > 0)
                      Positioned(
                        top: -5,
                        right: -5,
                        child: Container(
                          constraints:
                              const BoxConstraints(minWidth: 18, minHeight: 18),
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.error,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            label,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
          child: ContentFrame(
              child: ListView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.all(16),
        children: [
          Text('Plan their next visit',
              style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 8),
          Text(
              'Choose your pet and preferred time. Your clinic will confirm the appointment.',
              style: TextStyle(color: cs.onSurfaceVariant)),
          const SizedBox(height: 16),
          if (_clinicName != null && _clinicName!.isNotEmpty)
            Text(
              'Clinic: $_clinicName',
              style: TextStyle(color: cs.onSurfaceVariant),
            ),
          const SizedBox(height: 12),
          _PetDropdown(
            ownerUid: _uid,
            selectedPatientId: _selectedPatientId,
            onChanged: (pid, name) => setState(() {
              _selectedPatientId = pid;
              _selectedPatientName = name;
            }),
          ),
          const SizedBox(height: 12),
          AdaptiveActions(
            children: [
              OutlinedButton.icon(
                icon: const Icon(Icons.calendar_today),
                label: Text(selectedDateLabel),
                onPressed: _pickDate,
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.access_time),
                label: Text(selectedTimeLabel),
                onPressed: _pickTime,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Available slots from clinic',
            style: TextStyle(fontWeight: FontWeight.w700, color: cs.primary),
          ),
          const SizedBox(height: 6),
          _AvailableSlotsList(
            clinicId: _clinicId!,
            onSelect: (slot) {
              setState(() {
                _selectedSlotId = slot.id;
                _selectedDate = DateTime(
                  slot.date.year,
                  slot.date.month,
                  slot.date.day,
                );
                _selectedTime = slot.start;
              });
              _showSnack(
                  'Slot selected: ${_dateLabel(slot.date)} ${_timeLabel(slot.start)}');
            },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _notesCtrl,
            minLines: 2,
            maxLines: 5,
            decoration: const InputDecoration(
              labelText: 'Notes (optional)',
              hintText: 'Symptoms or reason for visit',
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _submitting ? null : _submit,
            icon: _submitting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.send),
            label: const Text('Request Appointment'),
          ),
          const SizedBox(height: 8),
          Text(
            'Clinic staff will review your request and notify you once approved or declined.',
            style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          Text(
            'My booking requests',
            style: TextStyle(fontWeight: FontWeight.w700, color: cs.primary),
          ),
          const SizedBox(height: 8),
          _MyBookingRequestsList(ownerUid: _uid),
        ],
      ))),
    );
  }
}

class _MyBookingRequestsList extends StatelessWidget {
  final String ownerUid;
  const _MyBookingRequestsList({required this.ownerUid});

  Color _statusColor(BuildContext context, String status) {
    final s = status.toLowerCase();
    if (s == 'approved') return Colors.green.shade700;
    if (s == 'rejected') return Theme.of(context).colorScheme.error;
    return Colors.orange.shade800;
  }

  @override
  Widget build(BuildContext context) {
    final stream = FirebaseFirestore.instance
        .collection('bookings')
        .where('ownerUid', isEqualTo: ownerUid)
        .snapshots();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snap) {
        if (!snap.hasData) return const LinearProgressIndicator();
        final docs = [...snap.data!.docs]..sort((a, b) {
            final ta =
                (a.data()['createdAt'] as Timestamp?)?.millisecondsSinceEpoch ??
                    0;
            final tb =
                (b.data()['createdAt'] as Timestamp?)?.millisecondsSinceEpoch ??
                    0;
            return tb.compareTo(ta);
          });
        if (docs.isEmpty) {
          return const Text('No booking requests yet.');
        }
        return Column(
          children: docs.take(10).map((d) {
            final data = d.data();
            final status =
                ((data['status'] as String?) ?? 'pending').toLowerCase();
            final dateKey = (data['dateKey'] as String?) ?? '--';
            final timeKey = (data['timeKey'] as String?) ?? '--';
            final clinicName = (data['clinicName'] as String?) ?? 'Clinic';
            final patientName = (data['patientName'] as String?) ?? 'Pet';
            return Card(
              child: ListTile(
                leading: Icon(Icons.event_note_outlined,
                    color: _statusColor(context, status)),
                title: Text('$patientName • $clinicName'),
                subtitle: Text('$dateKey at $timeKey'),
                trailing: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color:
                        _statusColor(context, status).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    status.toUpperCase(),
                    style: TextStyle(
                      color: _statusColor(context, status),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

class _PetDropdown extends StatelessWidget {
  final String ownerUid;
  final String? selectedPatientId;
  final void Function(String? id, String? name) onChanged;

  const _PetDropdown({
    required this.ownerUid,
    required this.selectedPatientId,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final q = FirebaseFirestore.instance
        .collection('patients')
        .where('ownerUid', isEqualTo: ownerUid)
        .orderBy('name');

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: q.snapshots(),
      builder: (ctx, snap) {
        if (!snap.hasData) {
          return const LinearProgressIndicator();
        }
        final docs = snap.data!.docs;
        if (docs.isEmpty) {
          return const Text('No pets found. Add a pet first.');
        }

        if (selectedPatientId != null &&
            docs.every((d) => d.id != selectedPatientId)) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            onChanged(null, null);
          });
        }

        return DropdownButtonFormField<String>(
          value: selectedPatientId,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Pet',
            prefixIcon: Icon(Icons.pets_outlined),
          ),
          items: docs.map((d) {
            final name = (d.data()['name'] as String?)?.trim();
            final label = (name != null && name.isNotEmpty) ? name : d.id;
            return DropdownMenuItem<String>(
              value: d.id,
              child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
            );
          }).toList(),
          onChanged: (v) {
            if (v == null) {
              onChanged(null, null);
              return;
            }
            final doc = docs.firstWhere((e) => e.id == v);
            final name = (doc.data()['name'] as String?)?.trim();
            onChanged(v, name);
          },
        );
      },
    );
  }
}

class _SlotOption {
  final String id;
  final DateTime date;
  final TimeOfDay start;
  final String startLabel;
  final String endLabel;
  final String dateKey;
  final String timeKey;

  const _SlotOption({
    required this.id,
    required this.date,
    required this.start,
    required this.startLabel,
    required this.endLabel,
    required this.dateKey,
    required this.timeKey,
  });
}

class _AvailableSlotsList extends StatefulWidget {
  final String clinicId;
  final void Function(_SlotOption slot) onSelect;

  const _AvailableSlotsList({required this.clinicId, required this.onSelect});

  @override
  State<_AvailableSlotsList> createState() => _AvailableSlotsListState();
}

class _AvailableSlotsListState extends State<_AvailableSlotsList> {
  static const int _pageSize = 6;
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  DocumentSnapshot<Map<String, dynamic>>? _lastDoc;
  final List<_SlotOption> _slots = [];

  @override
  void initState() {
    super.initState();
    _loadPage(reset: true);
  }

  String _dateKey(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  String _timeKey(TimeOfDay t) {
    final hh = t.hour.toString().padLeft(2, '0');
    final mm = t.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  TimeOfDay _parseTime(String value) {
    final parts = value.split(':');
    final h = int.tryParse(parts[0]) ?? 0;
    final m = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
    return TimeOfDay(hour: h, minute: m);
  }

  String _dateLabel(DateTime d) {
    const months = [
      '',
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
    return '${months[d.month]} ${d.day}, ${d.year}';
  }

  String _timeLabel(TimeOfDay t) {
    final h = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
    final mm = t.minute.toString().padLeft(2, '0');
    final suffix = t.period == DayPeriod.am ? 'AM' : 'PM';
    return '$h:$mm $suffix';
  }

  Future<void> _loadPage({bool reset = false}) async {
    if (_loadingMore) return;
    if (!reset && !_hasMore) return;
    if (reset) {
      setState(() {
        _loading = true;
        _hasMore = true;
        _lastDoc = null;
        _slots.clear();
      });
    } else {
      setState(() => _loadingMore = true);
    }

    try {
      Query<Map<String, dynamic>> q = FirebaseFirestore.instance
          .collection('clinic_slots')
          .doc(widget.clinicId)
          .collection('slots')
          .where('active', isEqualTo: true)
          .orderBy('createdAt', descending: true)
          .limit(_pageSize);

      if (!reset && _lastDoc != null) {
        q = q.startAfterDocument(_lastDoc!);
      }

      final snap = await q.get();
      final docs = snap.docs;
      if (docs.isEmpty) {
        setState(() {
          _hasMore = false;
        });
        return;
      }

      _lastDoc = docs.last;
      if (docs.length < _pageSize) {
        _hasMore = false;
      }

      final approvedSnap = await FirebaseFirestore.instance
          .collection('bookings')
          .where('clinicId', isEqualTo: widget.clinicId)
          .where('status', isEqualTo: 'approved')
          .limit(400)
          .get();

      final approvedSlotIds = <String>{};
      final approvedDateTimeKeys = <String>{};
      for (final d in approvedSnap.docs) {
        final m = d.data();
        final sid = (m['slotId'] as String?)?.trim();
        if (sid != null && sid.isNotEmpty) {
          approvedSlotIds.add(sid);
        }
        final dk = (m['dateKey'] as String?)?.trim();
        final tk = (m['timeKey'] as String?)?.trim();
        if (dk != null && dk.isNotEmpty && tk != null && tk.isNotEmpty) {
          approvedDateTimeKeys.add('$dk|$tk');
        }
      }

      final now = DateTime.now();
      final minDay = DateTime(now.year, now.month, now.day);
      final next = <_SlotOption>[];
      for (final d in docs) {
        final data = d.data();
        final dateTs = data['date'] as Timestamp?;
        if (dateTs == null) continue;
        final rawDate = dateTs.toDate();
        final date = DateTime(rawDate.year, rawDate.month, rawDate.day);
        if (date.isBefore(minDay)) continue;

        final startLabel = (data['startTime'] as String?) ?? '09:00';
        final endLabel = (data['endTime'] as String?) ?? '10:00';
        final start = _parseTime(startLabel);
        final dateKey = (data['dateKey'] as String?)?.trim().isNotEmpty == true
            ? (data['dateKey'] as String).trim()
            : _dateKey(date);
        final timeKey = _timeKey(start);
        final dateTimeKey = '$dateKey|$timeKey';

        if (approvedSlotIds.contains(d.id) ||
            approvedDateTimeKeys.contains(dateTimeKey)) {
          continue;
        }

        next.add(_SlotOption(
          id: d.id,
          date: date,
          start: start,
          startLabel: startLabel,
          endLabel: endLabel,
          dateKey: dateKey,
          timeKey: timeKey,
        ));
      }

      if (!mounted) return;
      setState(() {
        _slots.addAll(next);
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadingMore = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const LinearProgressIndicator();
    }

    if (_slots.isEmpty) {
      return const Text(
        'No available slots right now. You can still request your preferred date and time above.',
      );
    }

    return Column(
      children: [
        ..._slots.map((s) {
          return Card(
            child: ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              title: Text(_dateLabel(s.date)),
              subtitle: Text('${_timeLabel(s.start)} - ${s.endLabel}'),
              trailing: TextButton(
                onPressed: () => widget.onSelect(s),
                child: const Text('Select'),
              ),
            ),
          );
        }),
        if (_hasMore)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: _loadingMore ? null : () => _loadPage(),
              icon: _loadingMore
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.expand_more),
              label: const Text('Load more'),
            ),
          ),
      ],
    );
  }
}
