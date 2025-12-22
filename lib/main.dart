import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

// App flow
import 'screens/auth_gate.dart';
import 'screens/portal_picker.dart';
import 'screens/clinic/clinic_gate.dart';

// Admin screens
import 'screens/admin/admin_login_screen.dart';
import 'screens/admin/admin_home_screen.dart';

// Auth & account
import 'screens/create_account_screen.dart';
import 'screens/forgot_password_screen.dart';
import 'screens/login_screen.dart';

// Dashboards
import 'screens/user/user.dart';
import 'screens/staff_home_screen.dart';

// USER child screens
import 'screens/user/pet_form_screen.dart';
import 'screens/user/pet_detail_screen.dart';
import 'screens/user/reminders_screen.dart';
import 'screens/user/profile_screen.dart';
import 'screens/user/chat_screen.dart';

// (optional) public clinic registration
import 'screens/clinic/clinic_form_screen.dart';

// Splash
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
    const seed = Color(0xFF059669);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'VetAssist',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: seed),
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(14)),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
      ),

      // Show Splash first
      initialRoute: SplashScreen.route,

      routes: {
        // splash
        SplashScreen.route: (_) => const SplashScreen(),

        // flow
        '/auth': (_) => const AuthGate(),
        PortalPicker.route: (_) => const PortalPicker(),
        AdminLoginScreen.route: (_) => const AdminLoginScreen(),

        // auth
        CustomerLoginScreen.route: (_) => const CustomerLoginScreen(),
        StaffLoginScreen.route:    (_) => const StaffLoginScreen(),
        CreateAccountScreen.route: (_) => const CreateAccountScreen(),
        ForgotPasswordScreen.route:(_) => const ForgotPasswordScreen(),
        AdminHomeScreen.route:     (_) => const AdminHomeScreen(),

        // dashboards
        '/user': (_) => const UserDashboard(),
        StaffHomeScreen.route: (_) => const StaffHomeScreen(),

        // USER child routes
        PetFormScreen.route:   (_) => const PetFormScreen(),
        PetDetailScreen.route: (_) => const PetDetailScreen(),
        RemindersScreen.route: (_) => const RemindersScreen(),
        ProfileScreen.route:   (_) => const ProfileScreen(),
        UserChatScreen.route:  (_) => const UserChatScreen(),

        // optional public clinic registration
        ClinicFormScreen.route: (_) => const ClinicFormScreen(),
        ClinicGate.route:       (_) => const ClinicGate(),
      },

      onUnknownRoute: (_) =>
          MaterialPageRoute(builder: (_) => const AuthGate()),
    );
  }
}
