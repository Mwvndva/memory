import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:share_plus/share_plus.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/theme.dart';
import '../../core/api_config.dart';
import '../../core/api_client.dart';
import '../../core/countries.dart';
import '../../repositories/auth_repository.dart';
import '../../repositories/circles_repository.dart';
import '../../core/error_handler.dart';

String _formatImageUrl(String url) {
  if (url.startsWith('http://localhost:') || url.startsWith('http://127.0.0.1:')) {
    final uri = Uri.parse(url);
    final baseUri = Uri.parse(kBaseUrl);
    return url.replaceFirst(uri.authority, baseUri.authority);
  }
  return url;
}

class LoadingView extends ConsumerStatefulWidget {
  const LoadingView({super.key});

  @override
  ConsumerState<LoadingView> createState() => _LoadingViewState();
}

class _LoadingViewState extends ConsumerState<LoadingView> {
  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider);
    if (!session.isRestoring) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          context.go(session.isAuthenticated ? '/capture' : '/login');
        }
      });
    }

    return const Scaffold(
      backgroundColor: kYellow,
      body: Center(
        child: SizedBox(
          width: 50,
          height: 50,
          child: CircularProgressIndicator(
            color: kBlack,
            strokeWidth: 4,
          ),
        ),
      ),
    );
  }
}

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
    setState(() {
      _loginLoading = true;
      _errorMessage = '';
    });
    try {
      final success = await ref.read(sessionProvider.notifier).login(
            _loginId.text,
            _loginPassword.text,
          );
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
    const bg = kYellow;
    final fg = dark ? kCream : kCharcoal;
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;

    return Scaffold(
      backgroundColor: bg,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: EdgeInsets.fromLTRB(26, 44, 26, 28 + keyboard),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: MediaQuery.sizeOf(context).height -
                  MediaQuery.paddingOf(context).vertical -
                  72,
            ),
            child: Column(
              children: [
                const SizedBox(height: 28),
                Image.asset(
                  'assets/images/memory-logo.png',
                  width: 150,
                  height: 150,
                  fit: BoxFit.contain,
                ),
                Text('Memory', style: _headline(fg, 34)),
                const SizedBox(height: 8),
                Text(
                  'Your circle is waiting.',
                  style: _small(fg.withValues(alpha: .68)),
                ),
                const SizedBox(height: 28),
                _field('Email or username', _loginId, '', dark),
                const SizedBox(height: 12),
                _field('Password', _loginPassword, '', dark, obscure: _loginObscure, onToggleObscure: () => setState(() => _loginObscure = !_loginObscure)),
                if (_errorMessage.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    _errorMessage,
                    style: TextStyle(color: kBlack, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ],
                const SizedBox(height: 12),
                _pill(
                  'Continue',
                  _onLogin,
                  dark,
                  color: _loginLoading ? kBlack.withValues(alpha: 0.9) : (dark ? kYellow : kBlack),
                  foreground: Colors.white,
                  isLoading: _loginLoading,
                ),
                const SizedBox(height: 18),
                _pill(
                  'Create account',
                  () => context.push('/create'),
                  dark,
                  color: dark ? kBlack : kCream,
                  foreground: dark ? kCream : kCharcoal,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

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

  String usernameStatus = 'Choose something people recognize.';
  bool usernameOk = false;
  String passwordStatus = 'Use at least 8 characters.';
  bool passwordOk = false;
  bool _createLoading = false;
  bool _passwordObscure = true;
  bool _confirmObscure = true;
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
    final result = await ref.read(sessionProvider.notifier).checkUsername(_username.text);
    if (!mounted) return;
    setState(() {
      usernameStatus = result['message'];
      usernameOk = result['ok'];
    });
  }

  void _validatePassword() {
    final result = ref.read(sessionProvider.notifier).checkPassword(_password.text, _confirmPassword.text);
    setState(() {
      passwordStatus = result['message'];
      passwordOk = result['ok'];
    });
  }

  Future<void> _onSubmit() async {
    // Prevent duplicate submissions
    if (_createLoading) return;

    await _validateUsername();
    _validatePassword();
    if (!usernameOk || !passwordOk) return;

    if (!acceptedTerms) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You must agree to the Terms & Conditions to register.'),
          backgroundColor: kBlack,
        ),
      );
      return;
    }

    setState(() => _createLoading = true);
    Map<String, dynamic> result = {'ok': false, 'message': 'Registration failed'};
    try {
      result = await ref.read(sessionProvider.notifier).createAccount(
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            backgroundColor: kBlack,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = ref.watch(isDarkProvider);
    const bg = kYellow;
    final fg = dark ? kCream : kCharcoal;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Fixed header (stationary) with inline Back button
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 18, 18, 0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 58,
                          height: 34,
                          child: _pill(
                            'Back',
                            () => context.pop(),
                            dark,
                            compact: true,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Create account', style: _headline(fg, 26)),
                              const SizedBox(height: 6),
                              Text(
                                'Start your circle with the real you.',
                                style: _small(fg.withValues(alpha: .68)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Scrollable form area
                  Expanded(
                    child: SingleChildScrollView(
                      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: EdgeInsets.fromLTRB(
                        18,
                        0,
                        18,
                        28 + MediaQuery.viewInsetsOf(context).bottom,
                      ),
                      child: Column(
                        children: [
                          // Form container: visually groups all fields and controls
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(18),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.06),
                                  blurRadius: 16,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(child: _field('First name', _firstName, '', dark)),
                                    const SizedBox(width: 10),
                                    Expanded(child: _field('Last name', _lastName, '', dark)),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                _field('Username', _username, '', dark),
                                _status(usernameStatus, usernameOk),
                                const SizedBox(height: 8),
                                _field('Email', _email, '', dark, keyboard: TextInputType.emailAddress),
                                const SizedBox(height: 8),
                                _phoneField(dark),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    Expanded(child: _field('Password', _password, '', dark, obscure: _passwordObscure, onToggleObscure: () => setState(() => _passwordObscure = !_passwordObscure))),
                                    const SizedBox(width: 10),
                                    Expanded(child: _field('Confirm password', _confirmPassword, '', dark, obscure: _confirmObscure, onToggleObscure: () => setState(() => _confirmObscure = !_confirmObscure))),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                _passwordRequirements(_password.text, _confirmPassword.text),
                                const SizedBox(height: 8),
                                _status(passwordStatus, passwordOk),
                                const SizedBox(height: 12),
                                GestureDetector(
                                  onTap: () => setState(() => acceptedTerms = !acceptedTerms),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 20,
                                        height: 20,
                                        decoration: BoxDecoration(
                                          color: acceptedTerms ? kBlack : kYellow,
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(
                                            color: acceptedTerms ? Colors.transparent : kBlack.withValues(alpha: 0.2),
                                            width: 1.5,
                                          ),
                                        ),
                                        child: acceptedTerms ? Icon(Icons.check_rounded, color: kYellow, size: 14) : null,
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: RichText(
                                          text: TextSpan(
                                            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: kCharcoal),
                                            children: [
                                              const TextSpan(text: 'I agree to the '),
                                              WidgetSpan(
                                                alignment: PlaceholderAlignment.middle,
                                                child: GestureDetector(
                                                  onTap: () => _showTermsSheet(context, dark),
                                                  child: const Text('Terms and Conditions', style: TextStyle(color: kBlack, decoration: TextDecoration.underline)),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 14),
                                // Create button
                                _pill(
                                  'Create account',
                                  _onSubmit,
                                  dark,
                                  color: _createLoading ? kBlack.withValues(alpha: 0.9) : kBlack,
                                  foreground: Colors.white,
                                  isLoading: _createLoading,
                                  disabled: _createLoading,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 18),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Back button moved inline in header
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
          margin: const EdgeInsets.all(18),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          decoration: BoxDecoration(
            color: dark ? kBlack : Colors.white,
            borderRadius: BorderRadius.circular(30),
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
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: (dark ? Colors.white : kCharcoal).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Terms & Conditions',
                    style: TextStyle(
                      color: dark ? kCream : kCharcoal,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: (dark ? kCream : kCharcoal).withValues(alpha: 0.08),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.close_rounded,
                        color: dark ? kCream : kCharcoal,
                        size: 18,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Last Updated: June 2026',
                        style: TextStyle(
                          color: (dark ? kCream : kCharcoal).withValues(alpha: 0.6),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 14),
                      _termsSection('1. Welcome to Memory', 
                        'Memory ("we", "us", or "our") provides a private daily social sharing platform for intimate circles. By creating an account or using the Memory app, you agree to comply with and be bound by these Terms & Conditions and all applicable laws of the Republic of Kenya.',
                        dark,
                      ),
                      _termsSection('2. Privacy & Consent (Kenya Data Protection Act, 2019)', 
                        'Your privacy is critical to us. By registering an account, you explicitly consent to the collection, storage, and processing of your personal data—including your name, email, phone number, and uploaded media files (memories). All personal data is processed in strict compliance with the Kenya Data Protection Act, 2019 and registration guidelines set by the Office of the Data Protection Commissioner (ODPC). We do not sell or share your personal data with third-party advertising companies.',
                        dark,
                      ),
                      _termsSection('3. User-Generated Content & Liabilities (Cybercrimes Act, 2018)', 
                        'You are solely responsible for the video memories and captions you post to your circle. Under the Computer Misuse and Cybercrimes Act, 2018 of Kenya, it is a criminal offense to upload or share content that is pornographic, hateful, harassing, defamatory, or infringes on another person\'s copyright. We reserve the right to suspend or delete your account immediately and report violations to relevant authorities if illegal or prohibited content is detected.',
                        dark,
                      ),
                      _termsSection('4. Account Security', 
                        'You are responsible for safeguarding your password and account details. You agree to notify us immediately of any unauthorized use or security breach of your account.',
                        dark,
                      ),
                      _termsSection('5. Limitation of Liability', 
                        'The Memory app is provided "as is" without warranties of any kind. We shall not be liable for any indirect, incidental, or punitive damages arising from your use of the app, service disruptions, or unauthorized access to user data.',
                        dark,
                      ),
                      _termsSection('6. Dispute Resolution & Governing Law', 
                        'These terms are governed by and construed in accordance with the laws of the Republic of Kenya. Any disputes, claims, or controversies arising out of or relating to these terms shall be subject to the exclusive jurisdiction of the competent courts in Nairobi, Kenya.',
                        dark,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: dark ? kYellow : kBlack,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Text(
                      'I Understand',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
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
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            heading,
            style: const TextStyle(
              color: kBlack,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            body,
            style: TextStyle(
              color: dark ? kCream.withValues(alpha: 0.8) : kCharcoal.withValues(alpha: 0.8),
              fontSize: 12.5,
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
          style: TextStyle(
            color: dark ? kCream : kCharcoal,
            fontSize: 11,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 7),
        Row(
          children: [
            SizedBox(
              width: 96,
              child: DropdownButtonFormField<CountryInfo>(
                initialValue: selectedCountry,
                dropdownColor: dark ? kBlack : kYellow,
                borderRadius: BorderRadius.circular(16),
                icon: Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: (dark ? kCream : kCharcoal).withValues(alpha: 0.6),
                ),
                iconSize: 20,
                isDense: true,
                isExpanded: true,
                menuMaxHeight: 350,
                items: kCountries
                    .map(
                      (c) => DropdownMenuItem<CountryInfo>(
                        value: c,
                        child: Row(
                          children: [
                            Text(c.flag, style: const TextStyle(fontSize: 18)),
                            const SizedBox(width: 8),
                            Text(
                              c.code,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: dark ? kCream : kCharcoal,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              c.dialCode,
                              style: TextStyle(
                                fontSize: 11,
                                color: (dark ? kCream : kCharcoal).withValues(alpha: 0.6),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                    .toList(),
                selectedItemBuilder: (context) => kCountries
                    .map(
                      (c) => Row(
                        children: [
                          Text(c.flag, style: const TextStyle(fontSize: 18)),
                          const SizedBox(width: 6),
                          Text(
                            c.code,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                              color: dark ? kCream : kCharcoal,
                            ),
                          ),
                        ],
                      ),
                    )
                    .toList(),
                onChanged: (v) => setState(() => selectedCountry = v ?? kCountries[0]),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: dark ? kDarkCream : kCream,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 14,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
                decoration: InputDecoration(
                  hintText: '',
                  filled: true,
                  fillColor: Colors.black,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 13, vertical: 14),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class AvatarUploadView extends ConsumerStatefulWidget {
  const AvatarUploadView({super.key});

  @override
  ConsumerState<AvatarUploadView> createState() => _AvatarUploadViewState();
}

class _AvatarUploadViewState extends ConsumerState<AvatarUploadView> {
  Uint8List? _avatarBytes;

  Future<void> _pickAvatar() async {
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 82,
    );
    if (file == null) return;
    final bytes = await file.readAsBytes();
    setState(() {
      _avatarBytes = bytes;
    });
    try {
      await ref.read(sessionProvider.notifier).updateAvatar(bytes);
    } catch (e) {
      if (mounted) {
        showAppError(context, e.toString());
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = ref.watch(isDarkProvider);
    final bg = dark ? kCharcoal : kCream;
    final fg = dark ? kCream : kCharcoal;
    final user = ref.watch(authProvider);

    final initialText = user.firstName.isNotEmpty ? user.firstName[0].toUpperCase() : 'R';

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(26, 80, 26, 28),
          child: Column(
            children: [
              Text(
                'Add your face',
                textAlign: TextAlign.center,
                style: _headline(fg, 34),
              ),
              const SizedBox(height: 8),
              Text(
                'This helps your circle recognize your memories.',
                textAlign: TextAlign.center,
                style: _small(fg.withValues(alpha: .7)),
              ),
              const SizedBox(height: 26),
              InkWell(
                onTap: _pickAvatar,
                borderRadius: BorderRadius.circular(28),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: fg.withValues(alpha: .08),
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 54,
                        backgroundColor: kAmber,
                        backgroundImage: _avatarBytes == null ? null : MemoryImage(_avatarBytes!),
                        child: _avatarBytes == null
                            ? Text(
                                initialText,
                                style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w900, color: Colors.white),
                              )
                            : null,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Upload profile picture',
                        style: TextStyle(color: fg, fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'You can update it later from your profile.',
                        style: _small(fg.withValues(alpha: .62)),
                      ),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              _pill(
                'Continue',
                () => context.go('/contacts'),
                dark,
                color: dark ? kYellow : kBlack,
                foreground: Colors.white,
              ),
              const SizedBox(height: 10),
              _pill(
                'Skip for now',
                () => context.go('/contacts'),
                dark,
                color: dark ? kCream : kCharcoal,
                foreground: dark ? kCharcoal : Colors.white,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ContactsSetupView extends ConsumerStatefulWidget {
  const ContactsSetupView({super.key});

  @override
  ConsumerState<ContactsSetupView> createState() => _ContactsSetupViewState();
}

class _ContactsSetupViewState extends ConsumerState<ContactsSetupView> {
  final Set<String> _addedToCircle = {};
  List<CircleMember> _matchedUsers = [];
  bool _isLoading = true;
  bool _permissionGranted = false;

  @override
  void initState() {
    super.initState();
    _fetchContacts();
  }

  Future<void> _fetchContacts() async {
    try {
      final status = await FlutterContacts.permissions.request(PermissionType.read);
      final granted = status == PermissionStatus.granted || status == PermissionStatus.limited;
      if (granted) {
        final contacts = await FlutterContacts.getAll(
          properties: {ContactProperty.phone, ContactProperty.email},
        );
        
        List<CircleMember> matched = [];
        
        if (kUseMockBackend) {
          matched = [
            const CircleMember(
              id: 'mock_amara',
              username: 'amara',
              firstName: 'Amara',
            ),
            const CircleMember(
              id: 'mock_mum',
              username: 'mumsmemories',
              firstName: 'Mum',
            ),
          ];
        } else {
          final phoneNumbers = contacts
              .expand((c) => c.phones.map((p) => p.number))
              .where((phoneNum) => phoneNum.isNotEmpty)
              .toList();
              
          if (phoneNumbers.isNotEmpty) {
            final dio = ref.read(apiClientProvider);
            final response = await dio.post('/users/sync-contacts', data: {'phones': phoneNumbers});
            final rawList = response.data as List? ?? [];
            matched = rawList
                .map((item) => CircleMember.fromJson(item as Map<String, dynamic>))
                .toList();
          }
        }

        setState(() {
          _matchedUsers = matched;
          _permissionGranted = true;
          _isLoading = false;
        });

        if (matched.isEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _showInviteSheet(context);
          });
        }
      } else {
        setState(() {
          _permissionGranted = false;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _permissionGranted = false;
        _isLoading = false;
      });
    }
  }

  void _showInviteSheet(BuildContext context) {
    final dark = ref.read(isDarkProvider);
    final user = ref.read(authProvider);
    final displayUsername = user.username.isNotEmpty ? user.username : 'user';
    final inviteLink = 'https://memory.app/invite/$displayUsername';

    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: dark ? kBlack : kYellow,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 24,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 5,
                margin: const EdgeInsets.only(bottom: 18),
                decoration: BoxDecoration(
                  color: (dark ? Colors.white : kCharcoal).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const Text(
                'No contacts on Memory yet',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Invite your friends to keep your circle alive! ⚡',
                style: TextStyle(
                  fontSize: 12,
                  color: (dark ? kCream : kCharcoal).withValues(alpha: 0.6),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () async {
                        Navigator.pop(context);
                        await SharePlus.instance.share(
                          ShareParams(
                            text: 'Join my circle on Memory! $inviteLink',
                          ),
                        );
                      },
                      child: Container(
                        height: 48,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFF058A0), Color(0xFFBD3EFF), Color(0xFFFF6B00)],
                          ),
                          borderRadius: BorderRadius.circular(999),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFF058A0).withValues(alpha: 0.3),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.camera_alt_rounded, color: Colors.white, size: 16),
                            SizedBox(width: 8),
                            Text(
                              'Instagram',
                              style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w900),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: GestureDetector(
                      onTap: () async {
                        Navigator.pop(context);
                        await SharePlus.instance.share(
                          ShareParams(
                            text: 'Join my circle on Memory! $inviteLink',
                          ),
                        );
                      },
                      child: Container(
                        height: 48,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF25D366), Color(0xFF128C7E)],
                          ),
                          borderRadius: BorderRadius.circular(999),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF25D366).withValues(alpha: 0.3),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.chat_bubble_rounded, color: Colors.white, size: 16),
                            SizedBox(width: 8),
                            Text(
                              'WhatsApp',
                              style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w900),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: inviteLink));
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Invite link copied!')),
                  );
                },
                child: Container(
                  width: double.infinity,
                  height: 48,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: (dark ? Colors.white : kCharcoal).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.copy_rounded, color: dark ? kCream : kCharcoal, size: 16),
                      const SizedBox(width: 8),
                      Text(
                        'Copy invite link',
                        style: TextStyle(
                          color: dark ? kCream : kCharcoal,
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  void _toggleAdded(String user) {
    setState(() {
      if (_addedToCircle.contains(user)) {
        _addedToCircle.remove(user);
      } else {
        _addedToCircle.add(user);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final dark = ref.watch(isDarkProvider);
    final bg = dark ? kCharcoal : kCream;
    final fg = dark ? kCream : kCharcoal;

    final List<Widget> listItems = [];

    if (_permissionGranted && _matchedUsers.isNotEmpty) {
      listItems.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          child: Text(
            'Contacts already on Memory',
            style: TextStyle(
              color: kBlack,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      );

      for (final matchedUser in _matchedUsers) {
        final name = '${matchedUser.firstName} ${matchedUser.lastName}'.trim();
        final displayName = name.isNotEmpty ? name : matchedUser.username;
        final initial = matchedUser.firstName.isNotEmpty ? matchedUser.firstName[0].toUpperCase() : '?';
        
        listItems.add(_contactRow(
          initial: initial,
          name: displayName,
          subtitle: '@${matchedUser.username}',
          color: (dark ? kYellow : kBlack).withValues(alpha: 0.6),
          fg: fg,
          dark: dark,
          isMock: kUseMockBackend,
          userKey: matchedUser.id,
          avatarUrl: matchedUser.avatarUrl,
        ));
      }
    } else if (_permissionGranted && _matchedUsers.isEmpty && !_isLoading) {
      listItems.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 8),
          child: Text(
            'None of your contacts are on Memory yet. Invite them below!',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: fg.withValues(alpha: .5),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
    } else if (_isLoading) {
      listItems.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Center(
            child: CircularProgressIndicator(color: dark ? kYellow : kBlack),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(26, 52, 26, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Build your circle', style: _headline(fg, 32)),
              const SizedBox(height: 8),
              Text(
                'People from your contacts already on Memory.',
                style: _small(fg.withValues(alpha: .68)),
              ),
              const SizedBox(height: 18),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    ...listItems,
                    const SizedBox(height: 14),
                    _inviteCard(),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _pill(
                'Start using Memory',
                () {
                  ref.read(sessionProvider.notifier).authenticate();
                  context.go('/feed');
                },
                dark,
                color: dark ? kYellow : kBlack,
                foreground: Colors.white,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _contactRow({
    required String initial,
    required String name,
    required String subtitle,
    required Color color,
    required Color fg,
    required bool dark,
    required bool isMock,
    required String userKey,
    String? avatarUrl,
  }) {
    final isAdded = _addedToCircle.contains(userKey);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        color: fg.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: color,
            backgroundImage: (avatarUrl != null && avatarUrl.isNotEmpty)
                ? NetworkImage(_formatImageUrl(avatarUrl)) as ImageProvider
                : null,
            child: (avatarUrl == null || avatarUrl.isEmpty)
                ? Text(
                    initial,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(color: fg, fontWeight: FontWeight.w900),
                ),
                Text(subtitle, style: _small(fg.withValues(alpha: .58))),
              ],
            ),
          ),
          SizedBox(
            width: 110,
            height: 34,
              child: _pill(
              isAdded ? 'Requested' : 'Add to circle',
              () async {
                if (isAdded) return;
                if (isMock) {
                  _toggleAdded(userKey);
                } else {
                  final Map<String, dynamic> result = await ref.read(circlesProvider.notifier).addMember(userKey);
                  final ok = result['ok'] == true;
                  final msg = result['message']?.toString() ?? '';
                  if (ok) {
                    _toggleAdded(userKey);
                    if (mounted) showAppMessage(context, msg.isNotEmpty ? msg : 'Request sent');
                  } else {
                    if (mounted) showAppError(context, msg.isNotEmpty ? msg : 'Failed to send request');
                  }
                }
              },
              dark,
              compact: true,
              color: isAdded ? Colors.grey.withValues(alpha: 0.5) : (dark ? kYellow : kBlack),
              foreground: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _inviteCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [ref.watch(isDarkProvider) ? kYellow : kBlack, kAmber]),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Invite to circle',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Bring in someone who should see the real version of your life.',
            style: TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () async {
                    await SharePlus.instance.share(
                      ShareParams(
                        text: 'Join my circle on Memory! https://memory.app/invite/roy',
                      ),
                    );
                  },
                  child: Container(
                    height: 34,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE4405F),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Text(
                      'Instagram',
                      style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: GestureDetector(
                  onTap: () async {
                    await SharePlus.instance.share(
                      ShareParams(
                        text: 'Join my circle on Memory! https://memory.app/invite/roy',
                      ),
                    );
                  },
                  child: Container(
                    height: 34,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: const Color(0xFF25D366),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Text(
                      'WhatsApp',
                      style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// Global UI helper methods aligned with main.dart prototypes
TextStyle _headline(Color color, double size) => TextStyle(
      color: color,
      fontSize: size,
      fontWeight: FontWeight.w900,
      height: 1,
    );

TextStyle _small(Color color) => TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w900);

Widget _status(String text, bool ok) => Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Text(
        text,
        style: TextStyle(
          color: ok ? const Color(0xFF20A978) : kBlack,
          fontSize: 10,
          fontWeight: FontWeight.w900,
        ),
      ),
    );

Widget _field(
  String label,
  TextEditingController controller,
  String hint,
  bool dark, {
  bool obscure = false,
  TextInputType? keyboard,
  VoidCallback? onToggleObscure,
}) =>
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: dark ? kCream : kCharcoal,
            fontSize: 11,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 7),
        TextField(
          controller: controller,
          obscureText: obscure,
          keyboardType: keyboard,
          inputFormatters: keyboard == TextInputType.phone ? [FilteringTextInputFormatter.digitsOnly] : null,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w900,
            color: dark ? kBlack : Colors.white,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              color: (dark ? kBlack : Colors.white).withValues(alpha: 0.35),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
            filled: true,
            fillColor: dark ? kYellow : kBlack,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 13,
              vertical: 14,
            ),
            suffixIcon: onToggleObscure == null
                ? null
                : GestureDetector(
                    onTap: onToggleObscure,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: Icon(
                        obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                        size: 20,
                        color: (dark ? kBlack : Colors.white).withValues(alpha: 0.8),
                      ),
                    ),
                  ),
          ),
        ),
      ],
    );

Widget _passwordRequirements(String pass, String confirm) {
  final lengthOk = pass.length >= 8;
  final upper = RegExp(r'[A-Z]').hasMatch(pass);
  final lower = RegExp(r'[a-z]').hasMatch(pass);
  final digit = RegExp(r'\d').hasMatch(pass);
  final special = RegExp(r'[!@#\$%\^&*(),.?":{}|<>~`_\-\\/\[\];\+=]').hasMatch(pass);

  Widget row(bool ok, String text) => Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Row(
          children: [
            Icon(ok ? Icons.check_circle_rounded : Icons.radio_button_unchecked, size: 14, color: ok ? const Color(0xFF20A978) : kBlack),
            const SizedBox(width: 8),
            Text(text, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: kBlack)),
          ],
        ),
      );

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      row(lengthOk, 'At least 8 characters'),
      row(upper, 'Contains an uppercase letter'),
      row(lower, 'Contains a lowercase letter'),
      row(digit, 'Contains a number'),
      row(special, 'Contains a special character'),
      if (pass.isNotEmpty || confirm.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(pass == confirm ? 'Passwords match' : 'Passwords do not match', style: TextStyle(color: pass == confirm ? const Color(0xFF20A978) : kBlack, fontWeight: FontWeight.w800, fontSize: 12)),
        ),
    ],
  );
}

Widget _pill(
  String text,
  VoidCallback onTap,
  bool dark, {
  Color? color,
  Color? foreground,
  bool compact = false,
  double? width,
  bool isLoading = false,
  bool disabled = false,
}) =>
    GestureDetector(
      onTap: disabled || isLoading ? null : onTap,
      child: Container(
        width: width ?? double.infinity,
        height: compact ? 34 : 46,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: disabled || isLoading
              ? (dark ? kBlack.withValues(alpha: 0.12) : kCharcoal.withValues(alpha: 0.06))
              : (color ?? (dark ? kYellow : kBlack)),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Opacity(
              opacity: isLoading ? 0 : 1,
              child: Text(
                text,
                style: TextStyle(
                  color: foreground ?? (dark ? kBlack : kYellow),
                  fontSize: compact ? 10 : 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            if (isLoading) const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.2)),
          ],
        ),
      ),
    );
