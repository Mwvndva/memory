import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:memory_app/core/app_providers.dart';
import 'package:memory_app/features/auth/auth.dart';
import 'package:memory_app/design_system/design_system.dart';

class LoginView extends ConsumerStatefulWidget {
  const LoginView({super.key});

  @override
  ConsumerState<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends ConsumerState<LoginView> {
  final _loginId = TextEditingController();
  final _loginPassword = TextEditingController();
  String _errorMessage = '';
  bool _loginLoading = false;
  bool _loginObscure = true;

  @override
  void dispose() {
    _loginId.dispose();
    _loginPassword.dispose();
    super.dispose();
  }

  Future<void> _onLogin() async {
    final identity = _loginId.text;
    final password = _loginPassword.text;

    if (identity.trim().isEmpty) {
      setState(() => _errorMessage = 'Username or email is required.');
      return;
    }
    if (password.isEmpty) {
      setState(() => _errorMessage = 'Password is required.');
      return;
    }
    if (password.length < 8) {
      setState(
        () => _errorMessage = 'Password must be at least 8 characters long.',
      );
      return;
    }

    setState(() {
      _loginLoading = true;
      _errorMessage = '';
    });
    try {
      final success = await ref
          .read(sessionProvider.notifier)
          .login(identity, password);
      if (!mounted) return;
      if (success) {
        context.go('/feed');
      } else {
        setState(() {
          _errorMessage = 'Invalid username/email or password.';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
        });
      }
    } finally {
      if (mounted) {
        setState(() => _loginLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = ref.watch(isDarkProvider);
    final fg = dark ? MemoryColors.cream : MemoryColors.charcoal;
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;

    // Plain yellow, the same accent the loading screen fills, with a still
    // logo: the login is the app's first frame after the splash, so it should
    // look like the splash settling, not a second animation starting over.
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: MemoryColors.accent,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: EdgeInsets.fromLTRB(26, 44, 26, 28 + keyboard),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: MemorySpacing.sheet),
                Image.asset(
                  'assets/images/memory-logo.png',
                  width: 140,
                  height: 140,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 24),
                // The wordmark, the one place the brand name is set larger than
                // any other type in the app.
                Text(
                  'Memory',
                  style: MemoryTypography.wordmark.copyWith(color: fg),
                ),
                const SizedBox(height: MemorySpacing.lg),
                Text(
                  'Share memories with your circle', // Canonical tagline
                  style: MemoryTypography.bodyMedium.copyWith(
                    color: fg.withValues(alpha: .55),
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 36),

                // Auth card with premium spacing, elevation & rounded geometries
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: MemorySpacing.section,
                    vertical: 24,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(MemoryRadius.xl),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 24,
                        spreadRadius: 1,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _field('Email or username', _loginId, '', dark),
                      const SizedBox(height: MemorySpacing.xxl),
                      _field(
                        'Password',
                        _loginPassword,
                        '',
                        dark,
                        obscure: _loginObscure,
                        onToggleObscure: () =>
                            setState(() => _loginObscure = !_loginObscure),
                      ),
                      if (_errorMessage.isNotEmpty) ...[
                        const SizedBox(height: MemorySpacing.xl),
                        Text(
                          _errorMessage,
                          style: MemoryTypography.caption.copyWith(
                            color: Colors.redAccent.shade700,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                      const SizedBox(height: MemorySpacing.section),
                      MemoryButton(
                        label: 'Continue',
                        onPressed: _onLogin,
                        dark: dark,
                        background: MemoryColors.ink,
                        foreground: Colors.white,
                        isLoading: _loginLoading,
                      ),
                      const SizedBox(height: MemorySpacing.xl),
                      MemoryButton(
                        label: 'Create account',
                        onPressed: () => context.push('/create'),
                        dark: dark,
                        background: MemoryColors.cream,
                        foreground: MemoryColors.charcoal,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Widget _field(
  String label,
  TextEditingController controller,
  String hint,
  bool dark, {
  bool obscure = false,
  TextInputType? keyboard,
  VoidCallback? onToggleObscure,
}) => authInputField(
  label,
  controller,
  hint,
  dark,
  obscure: obscure,
  keyboard: keyboard,
  onToggleObscure: onToggleObscure,
);
