import 'package:flutter/material.dart';

// Import the three tab widgets explicitly.
import 'pet_profile_tab.dart' show PetProfileTab;
import 'pet_visits_tab.dart' show PetVisitsTab;
import 'pet_vaccines_tab.dart' show PetVaccinesTab;

class PetDetailArgs {
  final String patientId;
  final String? name;
  const PetDetailArgs({required this.patientId, this.name});
}

class PetDetailScreen extends StatefulWidget {
  static const route = '/pet';
  const PetDetailScreen({super.key});

  @override
  State<PetDetailScreen> createState() => _PetDetailScreenState();
}

class _PetDetailScreenState extends State<PetDetailScreen>
    with TickerProviderStateMixin {
  late final TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final routeArgs = ModalRoute.of(context)?.settings.arguments;
    if (routeArgs is! PetDetailArgs) {
      return const Scaffold(
        body: Center(child: Text('Missing PetDetailArgs')),
      );
    }
    final args = routeArgs;
    final title = (args.name?.trim().isNotEmpty ?? false) ? args.name!.trim() : 'Pet';

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        bottom: TabBar(
          controller: _tab,
          tabs: const [
            Tab(text: 'Profile'),
            Tab(text: 'Visits'),
            Tab(text: 'Vaccines'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          PetProfileTab(patientId: args.patientId),
          PetVisitsTab(patientId: args.patientId),
          PetVaccinesTab(patientId: args.patientId),
        ],
      ),
    );
  }
}
