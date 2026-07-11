import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:memory_app/core/error_handler.dart';
import 'package:memory_app/core/app_providers.dart';
import 'package:memory_app/core/countries.dart';
import 'package:memory_app/features/auth/auth.dart';
import 'package:memory_app/design_system/design_system.dart';

class CreateAccountView extends ConsumerStatefulWidget {
  const CreateAccountView({super.key});

  @override
  ConsumerState<CreateAccountView> createState() => _CreateAccountViewState();
}

class _CreateAccountViewState extends ConsumerState<CreateAccountView> {
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _username = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();

  int _currentStep = 1; // 1 = Identity, 2 = Account, 3 = Finish

  String usernameStatus = 'Choose something people recognize.';
  bool usernameOk = false;
  String passwordStatus = 'Use at least 8 characters.';
  bool passwordOk = false;
  bool _createLoading = false;
  bool _passwordObscure = true;
  bool _confirmObscure = true;
  Timer? _usernameDebounce;
  late CountryInfo selectedCountry;
  bool acceptedTerms = false;

  @override
  void initState() {
    super.initState();
    selectedCountry = kCountries.firstWhere(
      (c) => c.code == 'KE',
      orElse: () => kCountries[0],
    );
    _username.addListener(_validateUsername);
    _password.addListener(_validatePassword);
    _confirmPassword.addListener(_validatePassword);

    // Initial validation
    _validateUsername();
  }

  @override
  void dispose() {
    _usernameDebounce?.cancel();
    _firstName.dispose();
    _lastName.dispose();
    _username.dispose();
    _email.dispose();
    _phone.dispose();
    _password.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  Future<void> _validateUsername() async {
    _usernameDebounce?.cancel();
    _usernameDebounce = Timer(const Duration(milliseconds: 450), () async {
      await _checkUsernameNow();
    });
  }

  Future<bool> _checkUsernameNow() async {
    _usernameDebounce?.cancel();
    final result = await ref
        .read(sessionProvider.notifier)
        .checkUsername(_username.text);
    if (!mounted) return false;
    setState(() {
      usernameStatus = result['message'];
      usernameOk = result['ok'];
    });
    return result['ok'] == true;
  }

  void _validatePassword() {
    final result = ref
        .read(sessionProvider.notifier)
        .checkPassword(_password.text, _confirmPassword.text);
    setState(() {
      passwordStatus = result['message'];
      passwordOk = result['ok'];
    });
  }

  void _goNext() async {
    if (_currentStep == 1) {
      final fName = _firstName.text.trim();
      final lName = _lastName.text.trim();
      final uName = _username.text
          .trim()
          .replaceFirst(RegExp(r'^@+'), '')
          .toLowerCase();

      if (fName.isEmpty) {
        showAppError(context, 'First name is required.');
        return;
      }
      if (lName.isEmpty) {
        showAppError(context, 'Last name is required.');
        return;
      }
      if (uName.isEmpty) {
        showAppError(context, 'Username is required.');
        return;
      }
      final isUsernameAvailable = await _checkUsernameNow();
      if (!mounted) return;
      if (!isUsernameAvailable) {
        showAppError(context, usernameStatus);
        return;
      }
      setState(() => _currentStep = 2);
    } else if (_currentStep == 2) {
      final emailVal = _email.text.trim();
      final phoneVal = _phone.text.trim();
      final passVal = _password.text;
      final confPassVal = _confirmPassword.text;

      if (emailVal.isEmpty ||
          !RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(emailVal)) {
        showAppError(context, 'Please enter a valid email address.');
        return;
      }
      if (phoneVal.isEmpty) {
        showAppError(context, 'Phone number is required.');
        return;
      }
      if (passVal.length < 8) {
        showAppError(context, 'Password must be at least 8 characters.');
        return;
      }
      if (passVal != confPassVal) {
        showAppError(context, 'Passwords do not match.');
        return;
      }
      _validatePassword();
      if (!passwordOk) {
        showAppError(context, passwordStatus);
        return;
      }
      setState(() => _currentStep = 3);
    }
  }

  Future<void> _onSubmit() async {
    // Prevent duplicate submissions
    if (_createLoading) return;

    if (!acceptedTerms) {
      if (!mounted) return;
      showAppError(
        context,
        'You must agree to the Terms & Conditions to register.',
      );
      return;
    }

    setState(() => _createLoading = true);
    Map<String, dynamic> result = {
      'ok': false,
      'message': 'Registration failed',
    };
    try {
      result = await ref
          .read(sessionProvider.notifier)
          .createAccount(
            firstName: _firstName.text.trim(),
            lastName: _lastName.text.trim(),
            username: _username.text.trim(),
            email: _email.text.trim().toLowerCase(),
            phone: '${selectedCountry.flag} ${_phone.text.trim()}',
            password: _password.text,
            acceptedTerms: acceptedTerms,
          );
    } finally {
      if (mounted) setState(() => _createLoading = false);
    }

    if (result['ok'] == true) {
      if (!mounted) return;
      context.go('/avatar');
    } else {
      if (mounted) {
        final msg = result['message']?.toString() ?? 'Registration failed.';
        showAppError(context, msg);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = ref.watch(isDarkProvider);
    final fg = dark ? MemoryColors.cream : MemoryColors.charcoal;

    return Scaffold(
      // The same flat accent as the login screen — no textured painter, no
      // scattered background icons — so the two auth screens read as one place.
      backgroundColor: MemoryColors.accent,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Guided Onboarding Header
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 58,
                    height: 34,
                    child: MemoryButton(
                      label: 'Back',
                      onPressed: () {
                        if (_currentStep > 1) {
                          setState(() => _currentStep--);
                        } else {
                          context.pop();
                        }
                      },
                      dark: dark,
                      variant: MemoryButtonVariant.secondary,
                      size: MemoryButtonSize.compact,
                    ),
                  ),
                  const SizedBox(width: MemorySpacing.xl),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Step $_currentStep of 3', // Simple step indicator
                          style: MemoryTypography.caption.copyWith(
                            fontWeight: FontWeight.w900,
                            color: fg.withValues(alpha: 0.5),
                            letterSpacing: 1.0,
                          ),
                        ),
                        const SizedBox(height: MemorySpacing.xxs),
                        Text(
                          _currentStep == 1
                              ? 'Identity'
                              : _currentStep == 2
                              ? 'Account Details'
                              : 'Terms & Finish',
                          // Smaller than the other auth headlines: this line is two lines long.
                          style: MemoryTypography.headlineLarge.copyWith(
                            color: fg,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: MemorySpacing.gutter),

            // Step forms — centered on the yellow, no card, so the screen
            // reads as the same place as login.
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final keyboard = MediaQuery.viewInsetsOf(context).bottom;
                  return SingleChildScrollView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: EdgeInsets.fromLTRB(18, 0, 18, 28 + keyboard),
                    child: ConstrainedBox(
                      // Fill the viewport so the form can sit centered when
                      // it is shorter than the screen, and scroll when not.
                      constraints: BoxConstraints(
                        minHeight: (constraints.maxHeight - 48).clamp(
                          0.0,
                          double.infinity,
                        ),
                      ),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 440),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // The same logo the login and splash show, so the
                              // sign-up flow stays branded above every step.
                              // Centered, not stretched, so it keeps its shape.
                              Center(
                                child: Image.asset(
                                  'assets/images/memory-logo.png',
                                  width: 96,
                                  height: 96,
                                  fit: BoxFit.contain,
                                ),
                              ),
                              const SizedBox(height: MemorySpacing.section),

                              // Step 1 - Identity
                              if (_currentStep == 1) ...[
                                Text(
                                  'The best memories start with real people.',
                                  style: MemoryTypography.bodySmall.copyWith(
                                    color: MemoryColors.charcoal.withValues(
                                      alpha: 0.6,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: MemorySpacing.sheet),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _field(
                                        'First name',
                                        _firstName,
                                        '',
                                        dark,
                                      ),
                                    ),
                                    const SizedBox(width: MemorySpacing.lg),
                                    Expanded(
                                      child: _field(
                                        'Last name',
                                        _lastName,
                                        '',
                                        dark,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: MemorySpacing.xl),
                                _field('Username', _username, '', dark),
                                _status(usernameStatus, usernameOk),
                                const SizedBox(height: MemorySpacing.section),
                                MemoryButton(
                                  label: 'Continue',
                                  onPressed: _goNext,
                                  dark: dark,
                                  background: MemoryColors.ink,
                                  foreground: Colors.white,
                                ),
                              ],

                              // Step 2 - Account Details
                              if (_currentStep == 2) ...[
                                _field(
                                  'Email',
                                  _email,
                                  '',
                                  dark,
                                  keyboard: TextInputType.emailAddress,
                                ),
                                const SizedBox(height: MemorySpacing.xl),
                                _phoneField(dark),
                                const SizedBox(height: MemorySpacing.xl),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _field(
                                        'Password',
                                        _password,
                                        '',
                                        dark,
                                        obscure: _passwordObscure,
                                        onToggleObscure: () => setState(
                                          () => _passwordObscure =
                                              !_passwordObscure,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: MemorySpacing.lg),
                                    Expanded(
                                      child: _field(
                                        'Confirm password',
                                        _confirmPassword,
                                        '',
                                        dark,
                                        obscure: _confirmObscure,
                                        onToggleObscure: () => setState(
                                          () => _confirmObscure =
                                              !_confirmObscure,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: MemorySpacing.xxl),
                                // Real-time validation checklist
                                _passwordRequirements(
                                  _password.text,
                                  _confirmPassword.text,
                                ),
                                const SizedBox(height: MemorySpacing.md),
                                _status(passwordStatus, passwordOk),
                                const SizedBox(height: MemorySpacing.section),
                                MemoryButton(
                                  label: 'Continue',
                                  onPressed: _goNext,
                                  dark: dark,
                                  background: MemoryColors.ink,
                                  foreground: Colors.white,
                                ),
                              ],

                              // Step 3 - Finish Consent & Submit
                              if (_currentStep == 3) ...[
                                Text(
                                  'Confirm your registration below to agree and complete registration.',
                                  style: MemoryTypography.bodySmall.copyWith(
                                    color: MemoryColors.charcoal.withValues(
                                      alpha: 0.6,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: MemorySpacing.sheet),
                                GestureDetector(
                                  onTap: () => setState(
                                    () => acceptedTerms = !acceptedTerms,
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 22,
                                        height: 22,
                                        decoration: BoxDecoration(
                                          color: acceptedTerms
                                              ? MemoryColors.ink
                                              : MemoryColors.cream,
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                          border: Border.all(
                                            color: acceptedTerms
                                                ? Colors.transparent
                                                : MemoryColors.ink.withValues(
                                                    alpha: 0.2,
                                                  ),
                                            width: 1.5,
                                          ),
                                        ),
                                        child: acceptedTerms
                                            ? const Icon(
                                                Icons.check_rounded,
                                                color: MemoryColors.accent,
                                                size: 14,
                                              )
                                            : null,
                                      ),
                                      const SizedBox(width: MemorySpacing.xl),
                                      Expanded(
                                        child: RichText(
                                          text: TextSpan(
                                            style: MemoryTypography.bodySmall
                                                .copyWith(
                                                  fontWeight: FontWeight.w700,
                                                  color: MemoryColors.charcoal,
                                                ),
                                            children: [
                                              const TextSpan(
                                                text: 'I agree to the ',
                                              ),
                                              WidgetSpan(
                                                alignment:
                                                    PlaceholderAlignment.middle,
                                                child: GestureDetector(
                                                  onTap: () => _showTermsSheet(
                                                    context,
                                                    dark,
                                                  ),
                                                  child: Text(
                                                    'Terms and Conditions',
                                                    style: MemoryTypography
                                                        .bodyMedium
                                                        .copyWith(
                                                          color:
                                                              MemoryColors.ink,
                                                          decoration:
                                                              TextDecoration
                                                                  .underline,
                                                        ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 24),
                                MemoryButton(
                                  label: 'Create account',
                                  onPressed: _onSubmit,
                                  dark: dark,
                                  background: MemoryColors.ink,
                                  foreground: Colors.white,
                                  isLoading: _createLoading,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showTermsSheet(BuildContext context, bool dark) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return Container(
          height: MediaQuery.sizeOf(context).height * 0.8,
          margin: const EdgeInsets.all(MemorySpacing.sheet),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          decoration: BoxDecoration(
            color: dark ? MemoryColors.ink : Colors.white,
            borderRadius: BorderRadius.circular(MemoryRadius.xl),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 30,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            children: [
              Container(
                width: 40,
                height: 5,
                margin: const EdgeInsets.only(bottom: MemorySpacing.gutter),
                decoration: BoxDecoration(
                  color: (dark ? Colors.white : MemoryColors.charcoal)
                      .withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(MemoryRadius.pill),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Terms & Conditions',
                    style: MemoryTypography.headlineMedium.copyWith(
                      color: dark ? MemoryColors.cream : MemoryColors.charcoal,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(MemorySpacing.sm),
                      decoration: BoxDecoration(
                        color:
                            (dark ? MemoryColors.cream : MemoryColors.charcoal)
                                .withValues(alpha: 0.08),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.close_rounded,
                        color: dark
                            ? MemoryColors.cream
                            : MemoryColors.charcoal,
                        size: 18,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: MemorySpacing.sheet),
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Last Updated: June 2026',
                        style: MemoryTypography.caption.copyWith(
                          color:
                              (dark
                                      ? MemoryColors.cream
                                      : MemoryColors.charcoal)
                                  .withValues(alpha: 0.6),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: MemorySpacing.xxl),
                      _termsSection(
                        '1. Welcome to Memory',
                        'Memory ("we", "us", or "our") provides a private daily social sharing platform for intimate circles. By creating an account or using the Memory app, you agree to comply with and be bound by these Terms & Conditions and all applicable laws of the Republic of Kenya.',
                        dark,
                      ),
                      _termsSection(
                        '2. Privacy & Consent (Kenya Data Protection Act, 2019)',
                        'Your privacy is critical to us. By registering an account, you explicitly consent to the collection, storage, and processing of your personal data—including your name, email, phone number, and uploaded media files (memories). All personal data is processed in strict compliance with the Kenya Data Protection Act, 2019 and registration guidelines set by the Office of the Data Protection Commissioner (ODPC). We do not sell or share your personal data with third-party advertising companies.',
                        dark,
                      ),
                      _termsSection(
                        '3. User-Generated Content & Liabilities (Cybercrimes Act, 2018)',
                        'You are solely responsible for the video memories and captions you post to your circle. Under the Computer Misuse and Cybercrimes Act, 2018 of Kenya, it is a criminal offense to upload or share content that is pornographic, hateful, harassing, defamatory, or infringes on another person\'s copyright. We reserve the right to suspend or delete your account immediately and report violations to relevant authorities if illegal or prohibited content is detected.',
                        dark,
                      ),
                      _termsSection(
                        '4. Account Security',
                        'You are responsible for safeguarding your password and account details. You agree to notify us immediately of any unauthorized use or security breach of your account.',
                        dark,
                      ),
                      _termsSection(
                        '5. Limitation of Liability',
                        'The Memory app is provided "as is" without warranties of any kind. We shall not be liable for any indirect, incidental, or punitive damages arising from your use of the app, service disruptions, or unauthorized access to user data.',
                        dark,
                      ),
                      _termsSection(
                        '6. Dispute Resolution & Governing Law',
                        'These terms are governed by and construed in accordance with the laws of the Republic of Kenya. Any disputes, claims, or controversies arising out of or relating to these terms shall be subject to the exclusive jurisdiction of the competent courts in Nairobi, Kenya.',
                        dark,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: MemorySpacing.gutter),
              SizedBox(
                width: double.infinity,
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: dark ? MemoryColors.accent : MemoryColors.ink,
                      borderRadius: BorderRadius.circular(MemoryRadius.pill),
                    ),
                    child: Text(
                      'I Understand',
                      style: MemoryTypography.button.copyWith(
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _termsSection(String heading, String body, bool dark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: MemorySpacing.sheet),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            heading,
            style: MemoryTypography.bodyMedium.copyWith(
              color: MemoryColors.ink,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: MemorySpacing.sm),
          Text(
            body,
            style: MemoryTypography.bodySmall.copyWith(
              color: dark
                  ? MemoryColors.cream.withValues(alpha: 0.8)
                  : MemoryColors.charcoal.withValues(alpha: 0.8),
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  Widget _phoneField(bool dark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Phone number',
          style: MemoryTypography.caption.copyWith(
            color: dark ? MemoryColors.cream : MemoryColors.charcoal,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 7),
        Row(
          children: [
            SizedBox(
              width: 96,
              child: MemoryDropdown<CountryInfo>(
                value: selectedCountry,
                options: kCountries,
                dark: dark,
                onChanged: (v) => setState(() => selectedCountry = v),
                itemBuilder: (c) => Row(
                  children: [
                    Text(c.flag, style: MemoryTypography.emoji(18)),
                    const SizedBox(width: MemorySpacing.md),
                    Text(
                      c.code,
                      style: MemoryTypography.onSurface(
                        MemoryTypography.bodyMedium,
                        dark,
                      ),
                    ),
                    const SizedBox(width: MemorySpacing.sm),
                    Text(
                      c.dialCode,
                      style: MemoryTypography.mutedOnSurface(
                        MemoryTypography.caption,
                        dark,
                        alpha: 0.6,
                      ),
                    ),
                  ],
                ),
                // Collapsed, the box is 96dp wide: the dial code will not fit,
                // and the flag already says which country this is.
                selectedBuilder: (c) => Row(
                  children: [
                    Text(c.flag, style: MemoryTypography.emoji(18)),
                    const SizedBox(width: MemorySpacing.sm),
                    Text(
                      c.code,
                      style: MemoryTypography.onSurface(
                        MemoryTypography.button,
                        dark,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: MemorySpacing.md),
            Expanded(
              child: MemoryTextField(
                controller: _phone,
                hint: '',
                dark: dark,
                keyboardType: TextInputType.phone,
                background: MemoryColors.ink,
                foreground: Colors.white,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

Widget _status(String text, bool ok) => authStatusIndicator(text, ok);
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
Widget _passwordRequirements(String pass, String confirm) =>
    passwordRequirements(pass, confirm);
