import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:geolocator/geolocator.dart';

import '../background_tracking_service.dart';
import '../database_helper.dart';
import '../screens/home_screen.dart';
import '../screens/login_screen.dart';
import '../screens/map_screen.dart';
import '../screens/performance_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/shifts_screen.dart';
import '../services/auth_service.dart';
import '../theme/app_colors.dart';
import 'app_background.dart';

/// Holds Home / Performance / Shifts / Profile plus the side menu.
class MainShell extends StatefulWidget {
  const MainShell({super.key, required this.user});

  final AuthUser user;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _authService = AuthService();
  late AuthUser _user;
  int _index = 0;
  int _homeRefreshToken = 0;

  @override
  void initState() {
    super.initState();
    _user = widget.user;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _resumeActiveShift();
    });
  }

  Future<void> _resumeActiveShift() async {
    final shift = await DatabaseHelper.instance.getActiveShift(
      driverId: _user.driverId,
    );
    if (shift == null || !mounted) return;

    // Keep the stored shift visible even if location permission was removed.
    // Resume GPS only when the operating system still allows location access.
    try {
      final permission = await Geolocator.checkPermission();
      final isAndroid =
          !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
      final hasPermission = isAndroid
          ? permission == LocationPermission.always
          : permission == LocationPermission.always ||
              permission == LocationPermission.whileInUse;
      if (hasPermission && !await FlutterBackgroundService().isRunning()) {
        await startBackgroundTracking();
      }
    } catch (_) {
      // The live map can still show the saved route if a platform plugin is
      // unavailable or permission has been revoked.
    }

    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<bool>(
        builder: (_) => MapScreen(user: _user),
      ),
    );
    if (mounted) {
      // Refresh visit counts and the Start/View tracking button after the
      // automatic map screen closes.
      setState(() => _homeRefreshToken += 1);
    }
  }

  void _openDrawer() => _scaffoldKey.currentState?.openDrawer();

  void _select(int index) {
    setState(() => _index = index);
    Navigator.of(context).pop();
  }

  Future<void> _logout() async {
    Navigator.of(context).pop();
    await stopBackgroundTracking();
    await DatabaseHelper.instance.endActiveShift(_user.driverId);
    await _authService.logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  void _onNameChanged(String name) {
    setState(() {
      _user = AuthUser(driverId: _user.driverId, name: name);
    });
    _authService.saveSession(_user);
  }

  @override
  Widget build(BuildContext context) {
    return AppBackground(
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: Colors.transparent,
        drawer: _AppDrawer(
          selectedIndex: _index,
          onSelect: _select,
          onLogout: _logout,
        ),
        body: SafeArea(
          child: IndexedStack(
            index: _index,
            children: [
              HomeScreen(
                key: ValueKey(_homeRefreshToken),
                user: _user,
                onOpenDrawer: _openDrawer,
              ),
              PerformanceScreen(user: _user, onOpenDrawer: _openDrawer),
              ShiftsScreen(user: _user, onOpenDrawer: _openDrawer),
              ProfileScreen(
                user: _user,
                onOpenDrawer: _openDrawer,
                onNameChanged: _onNameChanged,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AppDrawer extends StatelessWidget {
  const _AppDrawer({
    required this.selectedIndex,
    required this.onSelect,
    required this.onLogout,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: AppColors.backgroundTop,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text(
                  'Sales Tracker',
                  style: TextStyle(
                    color: AppColors.gold,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _item(Icons.home_outlined, 'Home', 0),
              _item(Icons.bar_chart_rounded, 'Performance', 1),
              _item(Icons.schedule, 'Shifts', 2),
              _item(Icons.person_outline, 'Profile', 3),
              const Spacer(),
              ListTile(
                leading: const Icon(Icons.logout, color: AppColors.cream),
                title: const Text(
                  'Logout',
                  style: TextStyle(color: AppColors.cream),
                ),
                onTap: onLogout,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _item(IconData icon, String label, int index) {
    final selected = selectedIndex == index;
    return ListTile(
      leading: Icon(
        icon,
        color: selected ? AppColors.gold : AppColors.cream,
      ),
      title: Text(
        label,
        style: TextStyle(
          color: selected ? AppColors.gold : AppColors.cream,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
      selected: selected,
      selectedTileColor: AppColors.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      onTap: () => onSelect(index),
    );
  }
}
