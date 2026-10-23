import 'package:flutter/material.dart';

import 'background_tracking_service.dart';
import 'screens/login_screen.dart';
import 'services/auth_service.dart';
import 'theme/app_colors.dart';
import 'widgets/app_background.dart';
import 'widgets/main_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeBackgroundTrackingService();
  runApp(const GpsTrackerApp());
}

class GpsTrackerApp extends StatelessWidget {
  const GpsTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'GPS Sales Tracker',
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.background,
        colorScheme: const ColorScheme.dark(
          primary: AppColors.card,
          secondary: AppColors.cream,
          surface: AppColors.background,
          onPrimary: AppColors.cream,
          onSecondary: AppColors.buttonText,
          onSurface: AppColors.cream,
          error: AppColors.error,
        ),
      ),
      home: const AuthGate(),
    );
  }
}

/// Shows Home if a driver is already saved, otherwise Login.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  final _authService = AuthService();
  late Future<AuthUser?> _sessionFuture;

  @override
  void initState() {
    super.initState();
    _sessionFuture = _authService.currentUser();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AuthUser?>(
      future: _sessionFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const AppBackground(
            child: Scaffold(
              backgroundColor: Colors.transparent,
              body: Center(
                child: CircularProgressIndicator(color: AppColors.cream),
              ),
            ),
          );
        }

        final user = snapshot.data;
        if (user == null) {
          return const LoginScreen();
        }
        return MainShell(user: user);
      },
    );
  }
}
