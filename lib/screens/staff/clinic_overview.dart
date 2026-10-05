import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../widgets/brand_widgets.dart';

class ClinicRecord {
  final String id;
  final Map<String, dynamic> data;
  const ClinicRecord(this.id, this.data);

  String text(String key, [String fallback = '']) {
    final value = data[key];
    return value is String && value.trim().isNotEmpty ? value.trim() : fallback;
  }

  bool get incoming =>
      text('fromOwnerUid').isNotEmpty && text('fromStaffUid').isEmpty;
  bool get unread => incoming && data['read'] != true;
  DateTime? get createdAt => data['createdAt'] is Timestamp
      ? (data['createdAt'] as Timestamp).toDate()
      : null;

  DateTime? get appointment {
    final date = text('dateKey');
    final time = text('timeKey');
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(date) ||
        !RegExp(r'^\d{2}:\d{2}$').hasMatch(time)) {
      return null;
    }
    final result = DateTime.tryParse('${date}T$time:00');
    if (result == null ||
        !result.toIso8601String().startsWith('${date}T$time')) {
      return null;
    }
    return result;
  }
}

class ClinicThreadPreview {
  final ClinicRecord latest;
  final ClinicRecord focus;
  final int unread;
  const ClinicThreadPreview(this.latest, this.focus, this.unread);
}

class ClinicSummary {
  final List<ClinicRecord> today;
  final List<ClinicRecord> upcoming;
  final List<ClinicRecord> pending;
  final List<ClinicThreadPreview> threads;
  final int unread;
  const ClinicSummary(
      {required this.today,
      required this.upcoming,
      required this.pending,
      required this.threads,
      required this.unread});

  factory ClinicSummary.fromRecords(
      List<ClinicRecord> bookings, List<ClinicRecord> messages, DateTime now) {
    final day = DateTime(now.year, now.month, now.day);
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    final approved = bookings
        .where((b) =>
            b.text('status').toLowerCase() == 'approved' &&
            b.appointment != null)
        .toList()
      ..sort((a, b) => a.appointment!.compareTo(b.appointment!));
    final pending = bookings
        .where((b) => b.text('status').toLowerCase() == 'pending')
        .toList();
    final groups = <String, List<ClinicRecord>>{};
    for (final message in messages) {
      final owner = message.text('ownerUid', message.text('fromOwnerUid'));
      if (owner.isNotEmpty) groups.putIfAbsent(owner, () => []).add(message);
    }
    final threads = groups.values.map((group) {
      group.sort((a, b) => (b.createdAt?.millisecondsSinceEpoch ?? 0)
          .compareTo(a.createdAt?.millisecondsSinceEpoch ?? 0));
      final unread = group.where((m) => m.unread).toList();
      return ClinicThreadPreview(group.first,
          unread.isEmpty ? group.first : unread.first, unread.length);
    }).toList()
      ..sort((a, b) {
        if ((a.unread > 0) != (b.unread > 0)) return a.unread > 0 ? -1 : 1;
        return (b.latest.createdAt?.millisecondsSinceEpoch ?? 0)
            .compareTo(a.latest.createdAt?.millisecondsSinceEpoch ?? 0);
      });
    return ClinicSummary(
      today: approved
          .where((b) =>
              !b.appointment!.isBefore(day) &&
              b.appointment!.isBefore(tomorrow))
          .toList(),
      upcoming:
          approved.where((b) => !b.appointment!.isBefore(tomorrow)).toList(),
      pending: pending,
      threads: threads,
      unread: threads.fold(0, (total, t) => total + t.unread),
    );
  }
}

class ClinicOverview extends StatelessWidget {
  final String clinicName;
  final ClinicSummary summary;
  final DateTime now;
  final bool bookingsLoading;
  final bool messagesLoading;
  final bool bookingsError;
  final bool messagesError;
  final bool savedData;
  final VoidCallback onRetry;
  final ValueChanged<String> onSchedule;
  final VoidCallback onMessages;
  final ValueChanged<String> onMessage;
  const ClinicOverview({
    super.key,
    required this.clinicName,
    required this.summary,
    required this.now,
    required this.onRetry,
    required this.onSchedule,
    required this.onMessages,
    required this.onMessage,
    this.bookingsLoading = false,
    this.messagesLoading = false,
    this.bookingsError = false,
    this.messagesError = false,
    this.savedData = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final today = MaterialLocalizations.of(context).formatFullDate(now);
    final booked = summary.today;
    final appointments = booked.isEmpty ? summary.upcoming : booked;
    final metrics = [
      _Metric(
          label: 'Today’s visits',
          value: bookingsLoading || bookingsError ? '—' : '${booked.length}',
          icon: Icons.calendar_today_outlined,
          onTap: () => onSchedule('today')),
      _Metric(
          label: 'Unread messages',
          value: messagesLoading || messagesError ? '—' : '${summary.unread}',
          icon: Icons.chat_bubble_outline_rounded,
          onTap: onMessages),
      _Metric(
          label: 'To review',
          value: bookingsLoading || bookingsError
              ? '—'
              : '${summary.pending.length}',
          icon: Icons.pending_actions_rounded,
          onTap: () => onSchedule('pending')),
    ];
    final messages = _OverviewSection(
      title: 'Messages',
      action: 'View inbox',
      onAction: onMessages,
      child: messagesError
          ? _LoadProblem(label: 'Messages could not load.', onRetry: onRetry)
          : messagesLoading
              ? const _LoadingUpdate(label: 'Loading conversations…')
              : summary.threads.isEmpty
                  ? const _EmptyUpdate(
                      icon: Icons.forum_outlined,
                      title: 'No conversations yet',
                      detail: 'Customer messages will appear here.')
                  : Column(children: [
                      for (final thread in summary.threads.take(2))
                        _MessagePreview(
                            thread: thread,
                            onTap: () => onMessage(thread.focus.id)),
                    ]),
    );
    final visits = _OverviewSection(
      title: booked.isEmpty && !bookingsLoading && !bookingsError
          ? 'Next appointments'
          : 'Today’s appointments',
      action: 'View schedule',
      onAction: () => onSchedule(booked.isEmpty ? 'upcoming' : 'today'),
      child: bookingsError
          ? _LoadProblem(
              label: 'Appointments could not load.', onRetry: onRetry)
          : bookingsLoading
              ? const _LoadingUpdate(label: 'Loading appointments…')
              : appointments.isEmpty
                  ? const _EmptyUpdate(
                      icon: Icons.event_available_outlined,
                      title: 'No approved visits scheduled',
                      detail:
                          'Review requests or add availability in Schedule.')
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                          if (booked.isEmpty)
                            const Padding(
                                padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
                                child: Text(
                                    'No approved visits today. Here’s what’s next.')),
                          for (final appointment in appointments.take(3))
                            _AppointmentPreview(
                                appointment: appointment,
                                includeDate: booked.isEmpty,
                                onTap: () => onSchedule(
                                    booked.isEmpty ? 'upcoming' : 'today')),
                        ]),
    );
    return ContentFrame(
        maxWidth: 1120,
        child: ListView(
          key: const PageStorageKey('clinic-overview'),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            Entrance(
                child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: LinearGradient(colors: [
                  theme.colorScheme.primary,
                  const Color(0xFF286A51)
                ], begin: Alignment.topLeft, end: Alignment.bottomRight),
              ),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(today,
                        style: const TextStyle(
                            color: Color(0xFFD5EDDF), fontSize: 12)),
                    const SizedBox(height: 6),
                    Text(clinicName,
                        style: theme.textTheme.titleLarge
                            ?.copyWith(color: Colors.white)),
                    const SizedBox(height: 4),
                    const Text('Your day, at a glance.',
                        style: TextStyle(color: Color(0xFFE1EDE6))),
                  ]),
            )),
            const SizedBox(height: 12),
            LayoutBuilder(builder: (context, constraints) {
              final columns = constraints.maxWidth < 320 ||
                      MediaQuery.textScalerOf(context).scale(14) > 20
                  ? 1
                  : 3;
              return Wrap(spacing: 10, runSpacing: 10, children: [
                for (final metric in metrics)
                  SizedBox(
                      width:
                          (constraints.maxWidth - (columns - 1) * 10) / columns,
                      child: metric),
              ]);
            }),
            if (!bookingsLoading &&
                !bookingsError &&
                summary.pending.isNotEmpty) ...[
              const SizedBox(height: 8),
              Card(
                  color: const Color(0xFFFFF3DD),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(22),
                    onTap: () => onSchedule('pending'),
                    child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(children: [
                          const Icon(Icons.pending_actions_rounded,
                              color: Color(0xFF805B16)),
                          const SizedBox(width: 12),
                          Expanded(
                              child: Text(
                                  '${summary.pending.length} booking ${summary.pending.length == 1 ? 'request needs' : 'requests need'} your review',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF684A13)))),
                          const Icon(Icons.chevron_right,
                              color: Color(0xFF805B16)),
                        ])),
                  )),
            ],
            const SizedBox(height: 12),
            LayoutBuilder(builder: (context, constraints) {
              if (constraints.maxWidth >= 760) {
                return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: messages),
                      const SizedBox(width: 16),
                      Expanded(child: visits),
                    ]);
              }
              return Column(
                  children: [messages, const SizedBox(height: 12), visits]);
            }),
            if (savedData)
              Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Text(
                      'Showing saved updates. Counts may change when connected.',
                      style: theme.textTheme.bodySmall)),
          ],
        ));
  }
}

class _Metric extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final VoidCallback onTap;
  const _Metric(
      {required this.label,
      required this.value,
      required this.icon,
      required this.onTap});
  @override
  Widget build(BuildContext context) => Card(
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Expanded(
                          child: AnimatedSwitcher(
                        duration: MediaQuery.disableAnimationsOf(context)
                            ? Duration.zero
                            : const Duration(milliseconds: 200),
                        layoutBuilder: (child, previous) => Stack(
                            alignment: Alignment.centerLeft,
                            children: [...previous, if (child != null) child]),
                        child: Text(value,
                            key: ValueKey(value),
                            style: Theme.of(context).textTheme.headlineMedium),
                      )),
                      Icon(icon,
                          size: 18,
                          color: Theme.of(context).colorScheme.primary),
                    ]),
                    const SizedBox(height: 4),
                    ConstrainedBox(
                      constraints: BoxConstraints(
                          minHeight:
                              MediaQuery.textScalerOf(context).scale(12) * 2.9),
                      child: Text(label,
                          style: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w600)),
                    ),
                  ]),
            )),
      );
}

class _OverviewSection extends StatelessWidget {
  final String title;
  final String action;
  final VoidCallback onAction;
  final Widget child;
  const _OverviewSection(
      {required this.title,
      required this.action,
      required this.onAction,
      required this.child});
  @override
  Widget build(BuildContext context) => Card(
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        child: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
                    child: Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(title,
                            style: Theme.of(context).textTheme.titleMedium),
                        TextButton(onPressed: onAction, child: Text(action))
                      ],
                    )),
                child,
              ],
            )),
      );
}

class _MessagePreview extends StatelessWidget {
  final ClinicThreadPreview thread;
  final VoidCallback onTap;
  const _MessagePreview({required this.thread, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final preview = thread.focus;
    final name =
        preview.text('ownerName', thread.latest.text('ownerName', 'Customer'));
    return InkWell(
        onTap: onTap,
        child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                    backgroundColor:
                        Theme.of(context).colorScheme.primaryContainer,
                    child: Text(name.characters.first.toUpperCase())),
                const SizedBox(width: 12),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontWeight: thread.unread > 0
                                  ? FontWeight.w700
                                  : FontWeight.w500)),
                      const SizedBox(height: 3),
                      Text(
                          '${preview.incoming ? '' : 'You: '}${preview.text('body', preview.text('title', 'Open conversation'))}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant)),
                    ])),
                const SizedBox(width: 8),
                if (thread.unread > 0)
                  Semantics(
                    label: '${thread.unread} unread messages',
                    child: Badge(
                        label: Text(
                            thread.unread > 9 ? '9+' : '${thread.unread}')),
                  )
                else
                  const Icon(Icons.chevron_right, size: 20),
              ],
            )));
  }
}

class _AppointmentPreview extends StatelessWidget {
  final ClinicRecord appointment;
  final bool includeDate;
  final VoidCallback onTap;
  const _AppointmentPreview(
      {required this.appointment,
      required this.includeDate,
      required this.onTap});
  @override
  Widget build(BuildContext context) {
    final date = appointment.appointment!;
    final time = MaterialLocalizations.of(context)
        .formatTimeOfDay(TimeOfDay.fromDateTime(date));
    return InkWell(
        onTap: onTap,
        child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.pets_outlined,
                    color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 12),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(appointment.text('patientName', 'Pet'),
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                      Text(appointment.text('ownerName', 'Customer')),
                      const SizedBox(height: 4),
                      Text(
                          '${includeDate ? '${MaterialLocalizations.of(context).formatMediumDate(date)} • ' : ''}$time • Approved',
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.primary,
                              fontSize: 12,
                              fontWeight: FontWeight.w600)),
                    ])),
                const Icon(Icons.chevron_right, size: 20),
              ],
            )));
  }
}

class _EmptyUpdate extends StatelessWidget {
  final IconData icon;
  final String title;
  final String detail;
  const _EmptyUpdate(
      {required this.icon, required this.title, required this.detail});
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.all(20),
      child: Column(children: [
        Icon(icon, color: Theme.of(context).colorScheme.primary, size: 30),
        const SizedBox(height: 10),
        Text(title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text(detail,
            textAlign: TextAlign.center,
            style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant)),
      ]));
}

class _LoadingUpdate extends StatelessWidget {
  final String label;
  const _LoadingUpdate({required this.label});
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.all(20),
      child: Column(children: [
        Text(label),
        const SizedBox(height: 12),
        const LinearProgressIndicator(minHeight: 2),
      ]));
}

class _LoadProblem extends StatelessWidget {
  final String label;
  final VoidCallback onRetry;
  const _LoadProblem({required this.label, required this.onRetry});
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.all(16),
      child: Column(children: [
        Text('$label Please check your connection and try again.',
            textAlign: TextAlign.center),
        TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Retry')),
      ]));
}
