import 'dart:async';

import 'package:flutter/material.dart';

class NotificationFeed<T> extends ChangeNotifier {
  NotificationFeed(this.openStream,
      {this.initialWait = const Duration(seconds: 12)}) {
    retry();
  }

  final Stream<List<T>> Function() openStream;
  final Duration initialWait;
  AsyncSnapshot<List<T>> snapshot = const AsyncSnapshot.waiting();
  StreamSubscription<List<T>>? _subscription;
  Timer? _deadline;
  int _generation = 0;
  bool _disposed = false;

  void retry() {
    if (_disposed) return;
    final generation = ++_generation;
    _subscription?.cancel();
    _deadline?.cancel();
    snapshot = snapshot.hasData
        ? AsyncSnapshot.withData(ConnectionState.waiting, snapshot.data!)
        : const AsyncSnapshot.waiting();
    notifyListeners();
    _deadline = Timer(initialWait, () {
      if (_disposed || generation != _generation) return;
      snapshot = AsyncSnapshot.withError(ConnectionState.active,
          TimeoutException('Notifications took too long'));
      notifyListeners();
    });
    void failed(Object error) {
      if (_disposed || generation != _generation) return;
      _deadline?.cancel();
      snapshot = AsyncSnapshot.withError(ConnectionState.active, error);
      notifyListeners();
    }

    try {
      _subscription = openStream().listen(
          (items) {
            if (_disposed || generation != _generation) return;
            _deadline?.cancel();
            snapshot = AsyncSnapshot.withData(
                ConnectionState.active, List<T>.unmodifiable(items));
            notifyListeners();
          },
          onError: failed,
          onDone: () {
            if (snapshot.connectionState == ConnectionState.waiting) {
              failed(StateError('Notification feed closed before loading'));
            }
          });
    } catch (error) {
      failed(error);
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    _deadline?.cancel();
    _subscription?.cancel();
    super.dispose();
  }
}

class NotificationFeedsBuilder<T> extends StatelessWidget {
  const NotificationFeedsBuilder({
    super.key,
    required this.bookings,
    required this.messages,
    required this.builder,
  });

  final NotificationFeed<T> bookings;
  final NotificationFeed<T> messages;
  final Widget Function(
      BuildContext, AsyncSnapshot<List<T>>, AsyncSnapshot<List<T>>) builder;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: Listenable.merge([bookings, messages]),
        builder: (context, _) =>
            builder(context, bookings.snapshot, messages.snapshot),
      );
}

class NotificationFeedStatus<T> extends StatelessWidget {
  const NotificationFeedStatus({
    super.key,
    required this.label,
    required this.feed,
  });

  final String label;
  final NotificationFeed<T> feed;

  @override
  Widget build(BuildContext context) {
    final snapshot = feed.snapshot;
    if (snapshot.hasError) {
      return Row(children: [
        const Icon(Icons.cloud_off_outlined, size: 18),
        const SizedBox(width: 8),
        Expanded(child: Text('$label could not load. Check your connection.')),
        TextButton(onPressed: feed.retry, child: const Text('Retry')),
      ]);
    }
    if (snapshot.connectionState == ConnectionState.waiting) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(children: [
          const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2)),
          const SizedBox(width: 12),
          Expanded(child: Text('Loading $label...')),
        ]),
      );
    }
    return const SizedBox.shrink();
  }
}
