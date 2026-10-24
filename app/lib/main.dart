import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'background_tracking_service.dart';
import 'screens/login_screen.dart';
import 'services/auth_service.dart';
import 'theme/app_colors.dart';
import 'widgets/app_background.dart';
import 'widgets/main_shell.dart';

final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.system);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeBackgroundTrackingService();
  
  final prefs = await SharedPreferences.getInstance();
  final isDark = prefs.getBool('darkMode') ?? true;
  themeNotifier.value = isDark ? ThemeMode.dark : ThemeMode.light;

  runApp(GpsTrackerApp());
}

class GpsTrackerApp extends StatelessWidget {
  const GpsTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (_, ThemeMode currentMode, child) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'GPS Sales Tracker',
          themeMode: currentMode,
          theme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.light,
            scaffoldBackgroundColor: AppColors.light.background,
            colorScheme: ColorScheme.light(
              primary: AppColors.light.card,
              secondary: AppColors.light.cream,
              surface: AppColors.light.background,
              onPrimary: AppColors.light.cream,
              onSecondary: AppColors.light.buttonText,
              onSurface: AppColors.light.cream,
              error: AppColors.light.error,
            ),
          ),
          darkTheme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.dark,
            scaffoldBackgroundColor: AppColors.dark.background,
            colorScheme: ColorScheme.dark(
              primary: AppColors.dark.card,
              secondary: AppColors.dark.cream,
              surface: AppColors.dark.background,
              onPrimary: AppColors.dark.cream,
              onSecondary: AppColors.dark.buttonText,
              onSurface: AppColors.dark.cream,
              error: AppColors.dark.error,
            ),
          ),
          home: AuthGate(),
        );
      },
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
          return AppBackground(
            child: Scaffold(
              backgroundColor: Colors.transparent,
              body: Center(
                child: CircularProgressIndicator(color: context.colors.cream),
              ),
            ),
          );
        }

        final user = snapshot.data;
        if (user == null) {
          return LoginScreen();
        }
        return MainShell(user: user);
      },
    );
  }
}
