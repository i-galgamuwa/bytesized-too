import 'package:flutter/material.dart';

import '../main.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';
import '../services/profile_service.dart';
import '../theme/app_colors.dart';
import '../widgets/cream_button.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    super.key,
    required this.user,
    required this.onOpenDrawer,
    required this.onNameChanged,
  });

  final AuthUser user;
  final VoidCallback onOpenDrawer;
  final ValueChanged<String> onNameChanged;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _profileService = ProfileService();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _address = TextEditingController();
  final _emergency = TextEditingController();
  bool _editing = false;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final profile = await _profileService.load(widget.user.name);
    _name.text = profile.name;
    _phone.text = profile.phone;
    _email.text = profile.email;
    _address.text = profile.address;
    _emergency.text = profile.emergencyContact;
    if (mounted) setState(() => _loaded = true);
  }

  Future<void> _save() async {
    final profile = DriverProfile(
      name: _name.text.trim().isEmpty ? widget.user.name : _name.text.trim(),
      phone: _phone.text.trim(),
      email: _email.text.trim(),
      address: _address.text.trim(),
      emergencyContact: _emergency.text.trim(),
    );
    await _profileService.save(profile);
    widget.onNameChanged(profile.name);
    if (!mounted) return;
    setState(() => _editing = false);
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _email.dispose();
    _address.dispose();
    _emergency.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: !_loaded
          ? Center(
              child: CircularProgressIndicator(color: context.colors.cream),
            )
          : ListView(
              children: [
                _Header(title: 'Profile', onOpenDrawer: widget.onOpenDrawer),
                SizedBox(height: 16),
                CircleAvatar(
                  radius: 48,
                  backgroundColor: context.colors.cardHighlight,
                  child: Icon(Icons.person, size: 52, color: context.colors.cream),
                ),
                SizedBox(height: 12),
                Text(
                  _name.text.isEmpty ? widget.user.name : _name.text,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: context.colors.cream,
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Sales ID: ${widget.user.driverId}',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: context.colors.muted),
                ),
                SizedBox(height: 4),
                Text(
                  DriverProfile.sampleVehicle,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: context.colors.gold, fontSize: 13),
                ),
                
                SizedBox(height: 12),
                ValueListenableBuilder<ThemeMode>(
                  valueListenable: themeNotifier,
                  builder: (context, currentMode, _) {
                    return SwitchListTile(
                      title: Text('Dark Mode', style: TextStyle(color: context.colors.cream)),
                      value: currentMode == ThemeMode.dark,
                      activeThumbColor: context.colors.gold,
                      onChanged: (val) async {
                        themeNotifier.value = val ? ThemeMode.dark : ThemeMode.light;
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.setBool('darkMode', val);
                      },
                    );
                  }
                ),

                _field('Name', _name),
                _field('Phone', _phone, keyboard: TextInputType.phone),
                _field('Email', _email, keyboard: TextInputType.emailAddress),
                _field('Address', _address),
                _field('Emergency contact', _emergency),
                SizedBox(height: 20),
                CreamButton(
                  label: _editing ? 'Save profile' : 'Edit Profile',
                  onPressed: () {
                    if (_editing) {
                      _save();
                    } else {
                      setState(() => _editing = true);
                    }
                  },
                ),
              ],
            ),
    );
  }

  Widget _field(
    String label,
    TextEditingController controller, {
    TextInputType? keyboard,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: context.colors.gold)),
          SizedBox(height: 6),
          TextField(
            controller: controller,
            enabled: _editing,
            keyboardType: keyboard,
            style: TextStyle(color: context.colors.cream),
            decoration: InputDecoration(
              filled: true,
              fillColor: context.colors.card,
              hintText: label,
              hintStyle: TextStyle(color: context.colors.muted),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.title, required this.onOpenDrawer});

  final String title;
  final VoidCallback onOpenDrawer;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          onPressed: onOpenDrawer,
          icon: Icon(Icons.menu, color: context.colors.cream),
        ),
        Text(
          title,
          style: TextStyle(color: context.colors.cream,
            fontSize: 22,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
