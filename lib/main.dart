import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'theme/vet_theme.dart';

import 'screens/auth_gate.dart';
import 'screens/portal_picker.dart';
import 'screens/clinic/clinic_gate.dart';

import 'screens/admin/admin_login_screen.dart';
import 'screens/admin/admin_home_screen.dart';

import 'screens/create_account_screen.dart';
import 'screens/forgot_password_screen.dart';
import 'screens/login_screen.dart';

import 'screens/user/user.dart';
import 'screens/staff_home_screen.dart';

import 'screens/user/pet_form_screen.dart';
import 'screens/user/pet_detail_screen.dart';
import 'screens/user/reminders_screen.dart';
import 'screens/user/profile_screen.dart';
import 'screens/user/chat_screen.dart';
import 'screens/user/book_visit_screen.dart';

import 'screens/clinic/clinic_form_screen.dart';

import 'screens/splash_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const VetAssistApp());
}

class VetAssistApp extends StatelessWidget {
  const VetAssistApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'VetAssist',
      theme: VetTheme.light,
      initialRoute: SplashScreen.route,
      routes: {
        SplashScreen.route: (_) => const SplashScreen(),
        '/auth': (_) => const AuthGate(),
        PortalPicker.route: (_) => const PortalPicker(),
        AdminLoginScreen.route: (_) => const AdminLoginScreen(),
        CustomerLoginScreen.route: (_) => const CustomerLoginScreen(),
        StaffLoginScreen.route: (_) => const StaffLoginScreen(),
        CreateAccountScreen.route: (_) => const CreateAccountScreen(),
        ForgotPasswordScreen.route: (_) => const ForgotPasswordScreen(),
        AdminHomeScreen.route: (_) => const AdminHomeScreen(),
        '/user': (_) => const UserDashboard(),
        StaffHomeScreen.route: (_) => const StaffHomeScreen(),
        PetFormScreen.route: (_) => const PetFormScreen(),
        PetDetailScreen.route: (_) => const PetDetailScreen(),
        RemindersScreen.route: (_) => const RemindersScreen(),
        ProfileScreen.route: (_) => const ProfileScreen(),
        UserChatScreen.route: (_) => const UserChatScreen(),
        BookVisitScreen.route: (_) => const BookVisitScreen(),
        ClinicFormScreen.route: (_) => const ClinicFormScreen(),
        ClinicGate.route: (_) => const ClinicGate(),
      },
      onUnknownRoute: (_) =>
          MaterialPageRoute(builder: (_) => const AuthGate()),
    );
  }
}
