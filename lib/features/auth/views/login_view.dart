import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:memory_app/core/theme.dart';
import 'package:memory_app/features/auth/auth.dart';
import '../auth_background_painter.dart';
import 'package:memory_app/shared/widgets/pills.dart';

class LoginView extends ConsumerStatefulWidget {
  const LoginView({super.key});

  @override
  ConsumerState<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends ConsumerState<LoginView>
    with SingleTickerProviderStateMixin {
  final _loginId = TextEditingController();
  final _loginPassword = TextEditingController();
  String _errorMessage = '';
  bool _loginLoading = false;
  bool _loginObscure = true;

  late AnimationController _breathingController;
  late Animation<double> _breathingAnimation;
  Timer? _blinkTimer;
  bool _isBlinking = false;

  @override
  void initState() {
    super.initState();
    _breathingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3500),
    )..repeat(reverse: true);

    _breathingAnimation = Tween<double>(begin: 1.0, end: 1.02).animate(
      CurvedAnimation(parent: _breathingController, curve: Curves.easeInOut),
    );

    // Blinking schedule: every 9 seconds, perform a quick double-blink simulation
    _blinkTimer = Timer.periodic(const Duration(seconds: 9), (timer) {
      if (mounted) {
        setState(() => _isBlinking = true);
        Future.delayed(const Duration(milliseconds: 150), () {
          if (mounted) {
            setState(() => _isBlinking = false);
            // double blink pattern
            Future.delayed(const Duration(milliseconds: 100), () {
              if (mounted) {
                setState(() => _isBlinking = true);
                Future.delayed(const Duration(milliseconds: 150), () {
                  if (mounted) setState(() => _isBlinking = false);
                });
              }
            });
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _loginId.dispose();
    _loginPassword.dispose();
    _breathingController.dispose();
    _blinkTimer?.cancel();
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
    final fg = dark ? kCream : kCharcoal;
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          // 1. Premium Textured Background
          Positioned.fill(child: CustomPaint(painter: AuthBackgroundPainter())),

          // 2. Main Login Form Layout
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: EdgeInsets.fromLTRB(26, 44, 26, 28 + keyboard),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 18),
                    // Breathing & Blinking Animated Mascot
                    ScaleTransition(
                      scale: _breathingAnimation,
                      child: Container(
                        width: 140,
                        height: 140,
                        alignment: Alignment.center,
                        child: AnimatedCrossFade(
                          duration: const Duration(milliseconds: 100),
                          crossFadeState: _isBlinking
                              ? CrossFadeState.showSecond
                              : CrossFadeState.showFirst,
                          firstChild: Image.asset(
                            'assets/images/memory-logo.png',
                            width: 140,
                            height: 140,
                            fit: BoxFit.contain,
                          ),
                          secondChild: Opacity(
                            opacity: 0.15, // Simple blink fade simulation
                            child: Image.asset(
                              'assets/images/memory-logo.png',
                              width: 140,
                              height: 140,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24), // Increased spacing
                    Text('Memory', style: _headline(fg, 36)),
                    const SizedBox(height: 10), // Increased spacing
                    Text(
                      'Share memories with your circle', // Canonical tagline
                      style: TextStyle(
                        color: fg.withValues(
                          alpha: .55,
                        ), // Softer tagline color
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 36),

                    // Auth card with premium spacing, elevation & rounded geometries
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 24,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
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
                          const SizedBox(height: 14),
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
                            const SizedBox(height: 12),
                            Text(
                              _errorMessage,
                              style: TextStyle(
                                color: Colors.redAccent.shade700,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                          const SizedBox(height: 20),
                          pill(
                            'Continue',
                            _onLogin,
                            dark,
                            color: _loginLoading
                                ? kBlack.withValues(alpha: 0.9)
                                : kBlack,
                            foreground: Colors.white,
                            isLoading: _loginLoading,
                          ),
                          const SizedBox(height: 12),
                          pill(
                            'Create account',
                            () => context.push('/create'),
                            dark,
                            color: kCream,
                            foreground: kCharcoal,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

TextStyle _headline(Color color, double size) =>
    headlineStyle(color).copyWith(fontSize: size);
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
