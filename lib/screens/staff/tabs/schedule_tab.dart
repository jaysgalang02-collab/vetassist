import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../widgets/brand_widgets.dart';

class ScheduleTab extends StatefulWidget {
  final String clinicId;
  final String staffUid;
  final String initialSection;
  final int selectionVersion;

  const ScheduleTab({
    super.key,
    required this.clinicId,
    required this.staffUid,
    this.initialSection = 'pending',
    this.selectionVersion = 0,
  });

  @override
  State<ScheduleTab> createState() => _ScheduleTabState();
}

class _ScheduleTabState extends State<ScheduleTab> {
  bool _savingSlot = false;
  int _slotsListVersion = 0;

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

  Future<void> _addSlotDialog() async {
    final now = DateTime.now();
    DateTime pickedDate = DateTime(now.year, now.month, now.day);
    TimeOfDay start = const TimeOfDay(hour: 9, minute: 0);
    TimeOfDay end = const TimeOfDay(hour: 10, minute: 0);

    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 8,
            bottom: 16 + MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: StatefulBuilder(
            builder: (ctx, setLocal) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Add available slot',
                    style: Theme.of(ctx).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: ctx,
                        initialDate: pickedDate,
                        firstDate: DateTime(now.year, now.month, now.day),
                        lastDate: DateTime(now.year + 2),
                      );
                      if (picked == null) return;
                      setLocal(() {
                        pickedDate =
                            DateTime(picked.year, picked.month, picked.day);
                      });
                    },
                    icon: const Icon(Icons.calendar_today),
                    label: Text(_dateLabel(pickedDate)),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final picked = await showTimePicker(
                              context: ctx,
                              initialTime: start,
                            );
                            if (picked != null) setLocal(() => start = picked);
                          },
                          icon: const Icon(Icons.schedule),
                          label: Text('Start: ${_timeLabel(start)}'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final picked = await showTimePicker(
                              context: ctx,
                              initialTime: end,
                            );
                            if (picked != null) setLocal(() => end = picked);
                          },
                          icon: const Icon(Icons.schedule_send),
                          label: Text('End: ${_timeLabel(end)}'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: () => Navigator.pop(ctx, true),
                    icon: const Icon(Icons.add),
                    label: const Text('Save slot'),
                  ),
                ],
              );
            },
          ),
        );
      },
    );

    if (ok != true) return;

    final startMinutes = start.hour * 60 + start.minute;
    final endMinutes = end.hour * 60 + end.minute;
    if (endMinutes <= startMinutes) {
      _showSnack('End time must be after start time.');
      return;
    }

    setState(() => _savingSlot = true);
    try {
      final dateKey = _dateKey(pickedDate);
      await FirebaseFirestore.instance
          .collection('clinic_slots')
          .doc(widget.clinicId)
          .collection('slots')
          .add({
        'clinicId': widget.clinicId,
        'date': Timestamp.fromDate(pickedDate),
        'dateKey': dateKey,
        'startTime': _timeKey(start),
        'endTime': _timeKey(end),
        'active': true,
        'createdBy': widget.staffUid,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (mounted) {
        setState(() {
          _slotsListVersion++;
        });
      }
      _showSnack('Slot added.');
    } catch (e) {
      _showSnack('Failed to add slot: $e');
    } finally {
      if (mounted) setState(() => _savingSlot = false);
    }
  }

  Future<void> _setSlotActive(String slotId, bool active) async {
    await FirebaseFirestore.instance
        .collection('clinic_slots')
        .doc(widget.clinicId)
        .collection('slots')
        .doc(slotId)
        .update({
      'active': active,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _deleteSlot(String slotId) async {
    await FirebaseFirestore.instance
        .collection('clinic_slots')
        .doc(widget.clinicId)
        .collection('slots')
        .doc(slotId)
        .delete();
  }

  Future<void> _rejectBooking(
    String bookingId,
    String ownerUid,
    String ownerName,
    String dateKey,
    String timeKey,
  ) async {
    await FirebaseFirestore.instance
        .collection('bookings')
        .doc(bookingId)
        .update({
      'status': 'rejected',
      'reviewedBy': widget.staffUid,
      'reviewedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    final body = 'Your booking on $dateKey at $timeKey was declined by clinic.';
    await _notifyOwner(
        ownerUid: ownerUid, title: 'Booking declined', body: body);
    _showSnack('Booking rejected.');
  }

  Future<void> _approveBooking({
    required String bookingId,
    required String ownerUid,
    required String ownerName,
    required String dateKey,
    required String timeKey,
  }) async {
    final q = await FirebaseFirestore.instance
        .collection('bookings')
        .where('clinicId', isEqualTo: widget.clinicId)
        .where('dateKey', isEqualTo: dateKey)
        .where('timeKey', isEqualTo: timeKey)
        .where('status', isEqualTo: 'approved')
        .limit(1)
        .get();

    if (q.docs.isNotEmpty) {
      _showSnack('This date/time is already approved for another booking.');
      return;
    }

    await FirebaseFirestore.instance
        .collection('bookings')
        .doc(bookingId)
        .update({
      'status': 'approved',
      'reviewedBy': widget.staffUid,
      'reviewedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    final body = 'Your booking on $dateKey at $timeKey is approved.';
    await _notifyOwner(
        ownerUid: ownerUid, title: 'Booking approved', body: body);
    _showSnack('Booking approved.');
  }

  Future<void> _notifyOwner({
    required String ownerUid,
    required String title,
    required String body,
  }) async {
    await FirebaseFirestore.instance
        .collection('notifications')
        .doc(ownerUid)
        .collection('items')
        .add({
      'title': title,
      'body': body,
      'type': 'booking_status',
      'read': false,
      'clinicId': widget.clinicId,
      'createdAt': FieldValue.serverTimestamp(),
    });

    await FirebaseFirestore.instance.collection('notification_queue').add({
      'target': 'user',
      'uid': ownerUid,
      'title': title,
      'body': body,
      'type': 'booking_status',
      'clinicId': widget.clinicId,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return ContentFrame(
        maxWidth: 900,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 12,
              children: [
                Text(
                  'Appointments',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                FilledButton.icon(
                  onPressed: _savingSlot ? null : _addSlotDialog,
                  icon: _savingSlot
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.add),
                  label: const Text('Add slot'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text('Set your availability and keep track of every visit.',
                style: TextStyle(color: cs.onSurfaceVariant)),
            const SizedBox(height: 24),
            Text(
              'Appointment overview',
              style: TextStyle(fontWeight: FontWeight.w700, color: cs.primary),
            ),
            const SizedBox(height: 8),
            _BookingsMonitorPanel(
              clinicId: widget.clinicId,
              initialSection: widget.initialSection,
              selectionVersion: widget.selectionVersion,
              onApprove: _approveBooking,
              onReject: _rejectBooking,
            ),
            const SizedBox(height: 16),
            Card(
                child: ExpansionTile(
              title: const Text('Clinic availability'),
              subtitle: const Text('View or manage your available slots'),
              leading: const Icon(Icons.event_available_outlined),
              initiallyExpanded: false,
              children: [
                _SlotsList(
                  key: ValueKey('slots-${widget.clinicId}-$_slotsListVersion'),
                  clinicId: widget.clinicId,
                  onActiveChanged: _setSlotActive,
                  onDelete: _deleteSlot,
                  dateLabel: _dateLabel,
                  timeLabel: _timeLabel,
                ),
              ],
            )),
          ],
        ));
  }
}

class _SlotsList extends StatefulWidget {
  final String clinicId;
  final Future<void> Function(String slotId, bool active) onActiveChanged;
  final Future<void> Function(String slotId) onDelete;
  final String Function(DateTime d) dateLabel;
  final String Function(TimeOfDay t) timeLabel;

  const _SlotsList({
    super.key,
    required this.clinicId,
    required this.onActiveChanged,
    required this.onDelete,
    required this.dateLabel,
    required this.timeLabel,
  });

  @override
  State<_SlotsList> createState() => _SlotsListState();
}

class _SlotsListState extends State<_SlotsList> {
  static const int _pageSize = 6;
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  DocumentSnapshot<Map<String, dynamic>>? _lastDoc;
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> _docs = [];

  TimeOfDay _parseTime(String value) {
    final parts = value.split(':');
    final h = int.tryParse(parts[0]) ?? 0;
    final m = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
    return TimeOfDay(hour: h, minute: m);
  }

  String _timeKey(TimeOfDay t) {
    final hh = t.hour.toString().padLeft(2, '0');
    final mm = t.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  String _dateKey(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  @override
  void initState() {
    super.initState();
    _loadPage(reset: true);
  }

  Future<void> _loadPage({bool reset = false}) async {
    if (_loadingMore) return;
    if (!reset && !_hasMore) return;

    if (reset) {
      setState(() {
        _loading = true;
        _loadingMore = false;
        _hasMore = true;
        _lastDoc = null;
        _docs.clear();
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
        setState(() => _hasMore = false);
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
      for (final b in approvedSnap.docs) {
        final m = b.data();
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

      final next = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
      for (final d in docs) {
        final data = d.data();
        final date = (data['date'] as Timestamp?)?.toDate();
        if (date == null) continue;
        final dateOnly = DateTime(date.year, date.month, date.day);
        if (dateOnly.isBefore(minDay)) continue;

        final startTime = (data['startTime'] as String?) ?? '09:00';
        final start = _parseTime(startTime);
        final dk = (data['dateKey'] as String?)?.trim().isNotEmpty == true
            ? (data['dateKey'] as String).trim()
            : _dateKey(dateOnly);
        final tk = _timeKey(start);
        final key = '$dk|$tk';

        if (approvedSlotIds.contains(d.id) ||
            approvedDateTimeKeys.contains(key)) {
          continue;
        }
        next.add(d);
      }

      if (!mounted) return;
      setState(() {
        _docs.addAll(next);
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

    if (_docs.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(12),
          child:
              Text('No available slots. Approved schedules are auto-hidden.'),
        ),
      );
    }

    return Column(
      children: [
        ..._docs.map((d) {
          final data = d.data();
          final date = (data['date'] as Timestamp?)?.toDate();
          final startTime = (data['startTime'] as String?) ?? '09:00';
          final endTime = (data['endTime'] as String?) ?? '10:00';
          final active = (data['active'] as bool?) ?? true;

          return Card(
            child: ListTile(
              title:
                  Text(date == null ? 'Unknown date' : widget.dateLabel(date)),
              subtitle:
                  Text('${widget.timeLabel(_parseTime(startTime))} - $endTime'),
              trailing: Wrap(
                spacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Switch(
                    value: active,
                    onChanged: (v) async {
                      await widget.onActiveChanged(d.id, v);
                      await _loadPage(reset: true);
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    tooltip: 'Delete',
                    onPressed: () async {
                      await widget.onDelete(d.id);
                      await _loadPage(reset: true);
                    },
                  ),
                ],
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

class _BookingsMonitorPanel extends StatefulWidget {
  final String initialSection;
  final int selectionVersion;
  final String clinicId;
  final Future<void> Function({
    required String bookingId,
    required String ownerUid,
    required String ownerName,
    required String dateKey,
    required String timeKey,
  }) onApprove;
  final Future<void> Function(
    String bookingId,
    String ownerUid,
    String ownerName,
    String dateKey,
    String timeKey,
  ) onReject;

  const _BookingsMonitorPanel({
    required this.initialSection,
    required this.selectionVersion,
    required this.clinicId,
    required this.onApprove,
    required this.onReject,
  });

  @override
  State<_BookingsMonitorPanel> createState() => _BookingsMonitorPanelState();
}

class _BookingsMonitorPanelState extends State<_BookingsMonitorPanel> {
  late String _selectedSection = widget.initialSection;
  late Stream<QuerySnapshot<Map<String, dynamic>>> _bookings = _bookingStream();

  Stream<QuerySnapshot<Map<String, dynamic>>> _bookingStream() =>
      FirebaseFirestore.instance
          .collection('bookings')
          .where('clinicId', isEqualTo: widget.clinicId)
          .snapshots();

  @override
  void didUpdateWidget(covariant _BookingsMonitorPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.clinicId != widget.clinicId) _bookings = _bookingStream();
    if (oldWidget.selectionVersion != widget.selectionVersion ||
        oldWidget.initialSection != widget.initialSection) {
      _selectedSection = widget.initialSection;
    }
  }

  static const int _initialPageSize = 5;
  final Map<String, int> _visibleBySection = {
    'pending': _initialPageSize,
    'today': _initialPageSize,
    'upcoming': _initialPageSize,
    'approved': _initialPageSize,
    'rejected': _initialPageSize,
  };

  DateTime? _parseDateKey(String value) {
    final parts = value.split('-');
    if (parts.length != 3) return null;
    final y = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    final d = int.tryParse(parts[2]);
    if (y == null || m == null || d == null) return null;
    return DateTime(y, m, d);
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String _prettyStatus(String status) {
    final s = status.toLowerCase();
    if (s == 'approved') return 'Approved';
    if (s == 'rejected') return 'Rejected';
    if (s == 'pending') return 'Pending';
    return status;
  }

  String _titleForSection(String section) {
    switch (section) {
      case 'pending':
        return 'Pending requests';
      case 'today':
        return 'Today approved schedules';
      case 'upcoming':
        return 'Upcoming approved schedules';
      case 'approved':
        return 'All approved schedules';
      case 'rejected':
        return 'Disapproved schedules';
      default:
        return section;
    }
  }

  Widget _buildSectionHeader(
    BuildContext context, {
    required String title,
    required int count,
  }) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            '$count',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }

  Widget _bookingTile(
    BuildContext context,
    QueryDocumentSnapshot<Map<String, dynamic>> d, {
    bool actionable = false,
  }) {
    final data = d.data();
    final ownerUid = (data['ownerUid'] as String?) ?? '';
    final ownerName = (data['ownerName'] as String?) ?? ownerUid;
    final patientName = (data['patientName'] as String?) ?? 'Unknown pet';
    final dateKey = (data['dateKey'] as String?) ?? '--';
    final timeKey = (data['timeKey'] as String?) ?? '--';
    final notes = (data['notes'] as String?) ?? '';
    final status = _prettyStatus((data['status'] as String?) ?? 'pending');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    ownerName,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                Text(
                  status,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text('Pet: $patientName'),
            Text('Schedule: $dateKey at $timeKey'),
            if (notes.trim().isNotEmpty) ...[
              const SizedBox(height: 6),
              Text('Notes: $notes'),
            ],
            if (actionable) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => widget.onReject(
                      d.id,
                      ownerUid,
                      ownerName,
                      dateKey,
                      timeKey,
                    ),
                    icon: const Icon(Icons.close),
                    label: const Text('Reject'),
                  ),
                  FilledButton.icon(
                    onPressed: () => widget.onApprove(
                      bookingId: d.id,
                      ownerUid: ownerUid,
                      ownerName: ownerName,
                      dateKey: dateKey,
                      timeKey: timeKey,
                    ),
                    icon: const Icon(Icons.check),
                    label: const Text('Approve'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _bookings,
      builder: (context, snap) {
        if (snap.hasError) {
          return Card(
              child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(children: [
                    const Text(
                        'Appointments could not load. Please check your connection and try again.'),
                    TextButton.icon(
                        onPressed: () =>
                            setState(() => _bookings = _bookingStream()),
                        icon: const Icon(Icons.refresh),
                        label: const Text('Retry')),
                  ])));
        }
        if (!snap.hasData) {
          return const LinearProgressIndicator();
        }

        final docs = snap.data!.docs;
        if (docs.isEmpty) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(12),
              child: Text('No bookings yet for this clinic.'),
            ),
          );
        }

        final sorted = [...docs]..sort((a, b) {
            final ta =
                (a.data()['createdAt'] as Timestamp?)?.millisecondsSinceEpoch ??
                    0;
            final tb =
                (b.data()['createdAt'] as Timestamp?)?.millisecondsSinceEpoch ??
                    0;
            return tb.compareTo(ta);
          });

        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);

        final pending = sorted
            .where((d) =>
                ((d.data()['status'] as String?) ?? '').toLowerCase() ==
                'pending')
            .toList();
        final approved = sorted
            .where((d) =>
                ((d.data()['status'] as String?) ?? '').toLowerCase() ==
                'approved')
            .toList();
        final rejected = sorted
            .where((d) =>
                ((d.data()['status'] as String?) ?? '').toLowerCase() ==
                'rejected')
            .toList();

        final todayApproved = approved.where((d) {
          final dateKey = (d.data()['dateKey'] as String?) ?? '';
          final dt = _parseDateKey(dateKey);
          if (dt == null) return false;
          return _isSameDay(dt, today);
        }).toList();

        final upcomingApproved = approved.where((d) {
          final dateKey = (d.data()['dateKey'] as String?) ?? '';
          final dt = _parseDateKey(dateKey);
          if (dt == null) return false;
          return dt.isAfter(today);
        }).toList();

        Widget section({
          required String id,
          required List<QueryDocumentSnapshot<Map<String, dynamic>>> items,
          bool actionable = false,
        }) {
          final limit = _visibleBySection[id] ?? _initialPageSize;
          final shown = items.take(limit).toList();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionHeader(
                context,
                title: _titleForSection(id),
                count: items.length,
              ),
              const SizedBox(height: 6),
              if (items.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(12),
                    child: Text('No records.'),
                  ),
                )
              else
                ...shown.map(
                    (d) => _bookingTile(context, d, actionable: actionable)),
              if (items.length > shown.length)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () {
                      setState(() {
                        _visibleBySection[id] = shown.length + _initialPageSize;
                      });
                    },
                    icon: const Icon(Icons.expand_more),
                    label: const Text('Load more'),
                  ),
                ),
              const SizedBox(height: 12),
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: [
                for (final entry in {
                  'pending': 'Pending (${pending.length})',
                  'today': 'Today (${todayApproved.length})',
                  'upcoming': 'Upcoming (${upcomingApproved.length})',
                  'approved': 'Approved (${approved.length})',
                  'rejected': 'Declined (${rejected.length})',
                }.entries)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(entry.value),
                      selected: _selectedSection == entry.key,
                      onSelected: (_) =>
                          setState(() => _selectedSection = entry.key),
                    ),
                  ),
              ]),
            ),
            const SizedBox(height: 16),
            section(
              id: _selectedSection,
              items: {
                'pending': pending,
                'today': todayApproved,
                'upcoming': upcomingApproved,
                'approved': approved,
                'rejected': rejected,
              }[_selectedSection]!,
              actionable: _selectedSection == 'pending',
            ),
          ],
        );
      },
    );
  }
}
