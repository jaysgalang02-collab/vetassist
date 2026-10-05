import 'package:flutter/material.dart';

class ClinicNavigation extends StatelessWidget {
  final int section;
  final int unreadMessages;
  final int pendingBookings;
  final ValueChanged<int> onSelected;
  final VoidCallback onMore;
  const ClinicNavigation(
      {super.key,
      required this.section,
      required this.onSelected,
      required this.onMore,
      this.unreadMessages = 0,
      this.pendingBookings = 0});

  static const sections = [8, 5, 6, 0];

  @override
  Widget build(BuildContext context) {
    final index = sections.indexOf(section);
    Widget badged(IconData icon, int count) => Badge(
          isLabelVisible: count > 0,
          label: Text(count > 9 ? '9+' : '$count'),
          child: Icon(icon),
        );
    return NavigationBar(
      selectedIndex: index < 0 ? 4 : index,
      onDestinationSelected: (index) =>
          index == 4 ? onMore() : onSelected(sections[index]),
      destinations: [
        const NavigationDestination(
            icon: Icon(Icons.space_dashboard_outlined),
            selectedIcon: Icon(Icons.space_dashboard_rounded),
            label: 'Home'),
        NavigationDestination(
            icon: badged(Icons.chat_bubble_outline_rounded, unreadMessages),
            selectedIcon: badged(Icons.chat_bubble_rounded, unreadMessages),
            label: 'Messages'),
        NavigationDestination(
            icon: badged(Icons.calendar_month_outlined, pendingBookings),
            selectedIcon: badged(Icons.calendar_month_rounded, pendingBookings),
            label: 'Schedule'),
        const NavigationDestination(
            icon: Icon(Icons.pets_outlined),
            selectedIcon: Icon(Icons.pets_rounded),
            label: 'Patients'),
        const NavigationDestination(
            icon: Icon(Icons.grid_view_rounded), label: 'More'),
      ],
    );
  }
}
