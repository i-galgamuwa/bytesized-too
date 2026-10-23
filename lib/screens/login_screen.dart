import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../theme/app_colors.dart';
import '../widgets/app_background.dart';
import '../widgets/cream_button.dart';
import '../widgets/main_shell.dart';

/// First screen: Driver ID + password.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _authService = AuthService();
  final _driverIdController = TextEditingController();
  final _passwordController = TextEditingController();
  String? _errorMessage;
  bool _isSubmitting = false;
  bool _hidePassword = true;

  @override
  void dispose() {
    _driverIdController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final user = await _authService.login(
        _driverIdController.text,
        _passwordController.text,
      );

      if (!mounted) return;

      if (user == null) {
        setState(() {
          _isSubmitting = false;
          _errorMessage = 'Wrong Driver ID or password. Please try again.';
        });
        return;
      }

      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => MainShell(user: user),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        // e.toString() has "Exception: " prepended, let's clean it up slightly
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
              const Text(
                'Sales Tracker',
                style: TextStyle(
                  color: AppColors.gold,
                  fontSize: 16,
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Welcome back',
                style: TextStyle(
                  color: AppColors.cream,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Sign in with your Driver ID to start your shift.',
                style: TextStyle(color: AppColors.muted, fontSize: 15),
              ),
              const SizedBox(height: 40),
              _LabeledField(
                label: 'Driver ID',
                child: TextField(
                  controller: _driverIdController,
                  textInputAction: TextInputAction.next,
                  autocorrect: false,
                  enableSuggestions: false,
                  style: const TextStyle(color: AppColors.cream),
                  decoration: _inputDecoration(hint: 'rep1'),
                ),
              ),
              const SizedBox(height: 20),
              _LabeledField(
                label: 'Password',
                child: TextField(
                  controller: _passwordController,
                  obscureText: _hidePassword,
                  autocorrect: false,
                  enableSuggestions: false,
                  keyboardType: TextInputType.text,
                  onSubmitted: (_) => _login(),
                  style: const TextStyle(color: AppColors.cream),
                  decoration: _inputDecoration(hint: 'Enter password').copyWith(
                    suffixIcon: IconButton(
                      onPressed: () {
                        setState(() => _hidePassword = !_hidePassword);
                      },
                      icon: Icon(
                        _hidePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        color: AppColors.muted,
                      ),
                    ),
                  ),
                ),
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 16),
                Text(
                  _errorMessage!,
                  style: const TextStyle(color: AppColors.error),
                ),
              ],
              const SizedBox(height: 32),
              CreamButton(
                label: 'Login',
                busy: _isSubmitting,
                onPressed: _login,
              ),
              const SizedBox(height: 16),
              const Text(
                'Demo login: rep1 / rep123',
                style: TextStyle(color: AppColors.muted, fontSize: 13),
              ),
            ],
          ),
        ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({required String hint}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: AppColors.muted),
      filled: true,
      fillColor: AppColors.card,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide.none,
      ),
    );
  }
}

class _LabeledField extends StatelessWidget {
  const _LabeledField({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.gold,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }
}
