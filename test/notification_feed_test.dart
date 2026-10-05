import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetassist/screens/staff/notification_feed.dart';

void main() {
  late StreamController<List<String>> bookings;
  late StreamController<List<String>> messages;
  late NotificationFeed<String> bookingFeed;
  late NotificationFeed<String> messageFeed;
  late int bookingSubscriptions;
  late int messageSubscriptions;

  void initialize() {
    bookingSubscriptions = 0;
    messageSubscriptions = 0;
    bookings = StreamController<List<String>>.broadcast();
    messages = StreamController<List<String>>.broadcast();
    bookingFeed = NotificationFeed(() {
      bookingSubscriptions++;
      return bookings.stream;
    });
    messageFeed = NotificationFeed(() {
      messageSubscriptions++;
      return messages.stream;
    });
  }

  tearDown(() {
    bookingFeed.dispose();
    messageFeed.dispose();
    unawaited(bookings.close());
    unawaited(messages.close());
  });

  Widget panel() => NotificationFeedsBuilder<String>(
        bookings: bookingFeed,
        messages: messageFeed,
        builder: (context, appointments, chats) => Column(children: [
          const Text('Notifications'),
          NotificationFeedStatus(label: 'Bookings', feed: bookingFeed),
          NotificationFeedStatus(label: 'Messages', feed: messageFeed),
          for (final item in [...?appointments.data, ...?chats.data])
            ListTile(title: Text(item)),
        ]),
      );

  Widget app() => MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => Column(children: [
              NotificationFeedsBuilder<String>(
                bookings: bookingFeed,
                messages: messageFeed,
                builder: (_, a, b) => Text(
                    'Unread: ${(a.data?.length ?? 0) + (b.data?.length ?? 0)}'),
              ),
              TextButton(
                onPressed: () => showModalBottomSheet<void>(
                  context: context,
                  builder: (_) => panel(),
                ),
                child: const Text('Open notifications'),
              ),
            ]),
          ),
        ),
      );

  testWidgets('opening and reopening uses data already received by the bell',
      (tester) async {
    initialize();
    await tester.pumpWidget(app());
    bookings.add(['Visit request']);
    messages.add(['Message from Alex']);
    await tester.pump();
    expect(find.text('Unread: 2'), findsOneWidget);

    await tester.tap(find.text('Open notifications'));
    await tester.pumpAndSettle();
    expect(find.text('Visit request'), findsOneWidget);
    expect(find.text('Message from Alex'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(bookingSubscriptions, 1);
    expect(messageSubscriptions, 1);

    Navigator.of(tester.element(find.text('Notifications'))).pop();
    await tester.pumpAndSettle();
    messages.add([]);
    await tester.pump();
    await tester.pump();
    expect(find.text('Unread: 1'), findsOneWidget);
    await tester.tap(find.text('Open notifications'));
    await tester.pumpAndSettle();
    expect(find.text('Visit request'), findsOneWidget);
    expect(find.text('Message from Alex'), findsNothing);
    expect(messageSubscriptions, 1);
  });

  testWidgets('a delayed source does not hide loaded messages, and can retry',
      (tester) async {
    initialize();
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: panel())));
    messages.add(['Message ready']);
    await tester.pump();
    expect(find.text('Message ready'), findsOneWidget);
    expect(find.text('Loading Bookings...'), findsOneWidget);

    await tester.pump(const Duration(seconds: 13));
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('Message ready'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    await tester.pump();
    expect(find.text('Loading Bookings...'), findsOneWidget);
    bookings.add(['Recovered booking']);
    await tester.pump();
    expect(find.text('Recovered booking'), findsOneWidget);
    expect(find.text('Retry'), findsNothing);
    expect(bookingSubscriptions, 2);
  });

  testWidgets('errors in one source leave the other source usable',
      (tester) async {
    initialize();
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: panel())));
    bookings.addError(StateError('permission denied'));
    messages.add(['Customer question']);
    await tester.pump();
    expect(find.text('Customer question'), findsOneWidget);
    expect(find.text('Bookings could not load. Check your connection.'),
        findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    messages.add([]);
    await tester.pump();
    expect(find.text('Customer question'), findsNothing);
  });

  testWidgets('healthy idle streams do not time out', (tester) async {
    initialize();
    await tester.pumpWidget(app());
    bookings.add([]);
    messages.add(['Unread message']);
    await tester.pump();
    await tester.pump(const Duration(minutes: 5));
    expect(bookingFeed.snapshot.hasError, isFalse);
    expect(messageFeed.snapshot.hasError, isFalse);
    expect(find.text('Unread: 1'), findsOneWidget);
  });

  testWidgets('late data recovers after the initial loading deadline',
      (tester) async {
    initialize();
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: panel())));
    await tester.pump(const Duration(seconds: 13));
    expect(find.text('Retry'), findsNWidgets(2));
    bookings.add([]);
    messages.add(['Delayed message']);
    await tester.pump();
    expect(find.text('Retry'), findsNothing);
    expect(find.text('Delayed message'), findsOneWidget);
  });

  testWidgets('stream closing before initial data presents retry',
      (tester) async {
    initialize();
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: panel())));
    unawaited(bookings.close());
    messages.add([]);
    await tester.pump();
    expect(find.text('Retry'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('disposing subscriptions prevents late updates', (tester) async {
    initialize();
    var calls = 0;
    final controller = StreamController<List<String>>.broadcast();
    final feed = NotificationFeed(() => controller.stream);
    feed.addListener(() => calls++);
    feed.dispose();
    controller.add(['Late update']);
    await tester.pump(const Duration(seconds: 20));
    expect(calls, 0);
    unawaited(controller.close());
    await tester.pump();
  });
}
