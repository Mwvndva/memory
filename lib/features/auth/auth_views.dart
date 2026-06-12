import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:share_plus/share_plus.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/theme.dart';
import '../../repositories/auth_repository.dart';

class LoadingView extends ConsumerStatefulWidget {
  const LoadingView({super.key});

  @override
  ConsumerState<LoadingView> createState() => _LoadingViewState();
}

class _LoadingViewState extends ConsumerState<LoadingView> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(milliseconds: 1100), () {
      if (mounted) {
        context.go('/login');
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = ref.watch(isDarkProvider);
    final bg = dark ? kCharcoal : Colors.white;
    return Scaffold(
      backgroundColor: bg,
      body: Center(
        child: Image.asset(
          'assets/images/memory-logo.png',
          width: 220,
          height: 220,
          fit: BoxFit.contain,
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
  final _loginId = TextEditingController(text: 'roy@memory.app');
  final _loginPassword = TextEditingController();
  String _errorMessage = '';

  @override
  void dispose() {
    _loginId.dispose();
    _loginPassword.dispose();
    super.dispose();
  }

  Future<void> _onLogin() async {
    final success = await ref.read(authProvider.notifier).login(
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
  }

  @override
  Widget build(BuildContext context) {
    final dark = ref.watch(isDarkProvider);
    final bg = dark ? kCharcoal : Colors.white;
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
                _field('Email or username', _loginId, 'roy@memory.app or @roy', dark),
                const SizedBox(height: 12),
                _field('Password', _loginPassword, 'Your password', dark, obscure: true),
                if (_errorMessage.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    _errorMessage,
                    style: const TextStyle(color: kCoralDark, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ],
                const SizedBox(height: 12),
                _pill('Continue', _onLogin, dark, color: kCoral, foreground: Colors.white),
                const SizedBox(height: 28),
                _pill(
                  'Create account',
                  () => context.push('/create'),
                  dark,
                  color: dark ? kCream : kCharcoal,
                  foreground: dark ? kCharcoal : Colors.white,
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
  final _firstName = TextEditingController(text: 'Roy');
  final _lastName = TextEditingController(text: 'Nthiga');
  final _username = TextEditingController(text: '@roykeepsmemories');
  final _email = TextEditingController(text: 'roy@memory.app');
  final _phone = TextEditingController(text: '712 345 678');
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();

  String usernameStatus = 'Choose something people recognize.';
  bool usernameOk = false;
  String passwordStatus = 'Use at least 8 characters.';
  bool passwordOk = false;
  String selectedCountry = '🇰🇪';

  final countryCodes = const [
    '🇰🇪', '🇺🇸', '🇬🇧', '🇨🇦', '🇳🇬', '🇿🇦', '🇬🇭', '🇺🇬', '🇹🇿', '🇷🇼', '🇪🇹', '🇪🇬', '🇮🇳', '🇵🇰', '🇧🇩', '🇨🇳', '🇯🇵', '🇰🇷', '🇦🇺', '🇳🇿', '🇫🇷', '🇩🇪', '🇮🇹', '🇪🇸', '🇧🇷', '🇲🇽', '🇦🇪', '🇸🇦',
  ];

  @override
  void initState() {
    super.initState();
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
    final result = await ref.read(authProvider.notifier).checkUsername(_username.text);
    if (!mounted) return;
    setState(() {
      usernameStatus = result['message'];
      usernameOk = result['ok'];
    });
  }

  void _validatePassword() {
    final result = ref.read(authProvider.notifier).checkPassword(_password.text, _confirmPassword.text);
    setState(() {
      passwordStatus = result['message'];
      passwordOk = result['ok'];
    });
  }

  Future<void> _onSubmit() async {
    await _validateUsername();
    _validatePassword();
    if (!usernameOk || !passwordOk) return;

    await ref.read(authProvider.notifier).createAccount(
          firstName: _firstName.text.trim(),
          lastName: _lastName.text.trim(),
          username: _username.text.trim(),
          email: _email.text.trim().toLowerCase(),
          phone: '$selectedCountry ${_phone.text.trim()}',
          password: _password.text,
        );

    if (!mounted) return;
    context.go('/avatar');
  }

  @override
  Widget build(BuildContext context) {
    final dark = ref.watch(isDarkProvider);
    final bg = dark ? kCharcoal : Colors.white;
    final fg = dark ? kCream : kCharcoal;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: SingleChildScrollView(
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                padding: EdgeInsets.fromLTRB(
                  26,
                  78,
                  26,
                  28 + MediaQuery.viewInsetsOf(context).bottom,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Create account', style: _headline(fg, 32)),
                    const SizedBox(height: 8),
                    Text(
                      'Start your circle with the real you.',
                      style: _small(fg.withValues(alpha: .68)),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: _field('First name', _firstName, 'Roy', dark),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _field('Last name', _lastName, 'Nthiga', dark),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _field('Username', _username, '@roykeepsmemories', dark),
                    _status(usernameStatus, usernameOk),
                    const SizedBox(height: 10),
                    _field(
                      'Email',
                      _email,
                      'roy@memory.app',
                      dark,
                      keyboard: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 12),
                    _phoneField(dark),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _field('Password', _password, 'Password', dark, obscure: true),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _field('Confirm password', _confirmPassword, 'Repeat password', dark, obscure: true),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    _status(passwordStatus, passwordOk),
                    const SizedBox(height: 14),
                    _pill(
                      'Create account',
                      _onSubmit,
                      dark,
                      color: kCoral,
                      foreground: Colors.white,
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              left: 18,
              top: 8,
              child: SizedBox(
                width: 58,
                height: 34,
                child: _pill(
                  'Back',
                  () => context.pop(),
                  dark,
                  compact: true,
                ),
              ),
            ),
          ],
        ),
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
              width: 84,
              child: DropdownButtonFormField<String>(
                initialValue: selectedCountry,
                iconSize: 16,
                isDense: true,
                menuMaxHeight: 270,
                items: countryCodes
                    .map(
                      (c) => DropdownMenuItem(
                        value: c,
                        child: Center(
                          child: Text(c, style: const TextStyle(fontSize: 18)),
                        ),
                      ),
                    )
                    .toList(),
                selectedItemBuilder: (context) => countryCodes
                    .map(
                      (c) => Center(
                        child: Text(c, style: const TextStyle(fontSize: 18)),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setState(() => selectedCountry = v ?? '🇰🇪'),
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
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900),
                decoration: InputDecoration(
                  hintText: '712 345 678',
                  filled: true,
                  fillColor: dark ? kDarkCream : kCream,
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
    ref.read(authProvider.notifier).updateAvatar(bytes);
  }

  @override
  Widget build(BuildContext context) {
    final dark = ref.watch(isDarkProvider);
    final bg = dark ? kCharcoal : Colors.white;
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
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 38,
                                  fontWeight: FontWeight.w900,
                                ),
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
                color: kCoral,
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
  List<Contact> _contacts = [];
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
        setState(() {
          _contacts = contacts;
          _permissionGranted = true;
          _isLoading = false;
        });
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
    final bg = dark ? kCharcoal : Colors.white;
    final fg = dark ? kCream : kCharcoal;

    final List<Widget> listItems = [];

    // Prepend mock suggestions representing users already on Memory
    final mockSuggestions = [
      ('A', 'Amara', '@amara', kCoral),
      ('M', 'Mum', '@mumsmemories', kMint),
      ('L', 'Leo', '@leowalks', kSky),
    ];

    for (final c in mockSuggestions) {
      listItems.add(_contactRow(
        initial: c.$1,
        name: c.$2,
        subtitle: c.$3,
        color: c.$4,
        fg: fg,
        dark: dark,
        isMock: true,
        userKey: c.$3,
      ));
    }

    if (_permissionGranted && _contacts.isNotEmpty) {
      listItems.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          child: Text(
            'Contacts from your phone',
            style: TextStyle(
              color: kCoralDark,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      );

      final displayContacts = _contacts.take(4).toList();
      for (final contact in displayContacts) {
        final displayName = contact.displayName ?? '';
        final initial = displayName.isNotEmpty ? displayName[0].toUpperCase() : '?';
        final name = displayName.isNotEmpty ? displayName : 'Unknown';
        final subtitle = contact.phones.isNotEmpty 
            ? contact.phones.first.number 
            : (contact.emails.isNotEmpty ? contact.emails.first.address : 'No contact info');
        
        listItems.add(_contactRow(
          initial: initial,
          name: name,
          subtitle: subtitle,
          color: kCoral.withValues(alpha: 0.6),
          fg: fg,
          dark: dark,
          isMock: false,
          userKey: name,
        ));
      }
    } else if (_isLoading) {
      listItems.add(
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 20),
          child: Center(
            child: CircularProgressIndicator(color: kCoral),
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
                  ref.read(authProvider.notifier).authenticate();
                  context.go('/feed');
                },
                dark,
                color: kCoral,
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
            child: Text(
              initial,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
              ),
            ),
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
              isMock
                  ? (isAdded ? 'Added' : 'Add to circle')
                  : 'Invite',
              () async {
                if (isMock) {
                  _toggleAdded(userKey);
                } else {
                  await SharePlus.instance.share(
                    ShareParams(
                      text: 'Hey $name, join my circle on Memory! https://memory.app/invite/roy',
                    ),
                  );
                }
              },
              dark,
              compact: true,
              color: isMock
                  ? (isAdded ? Colors.grey.withValues(alpha: 0.5) : kCoral)
                  : kCoral,
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
        gradient: const LinearGradient(colors: [kCoral, kAmber]),
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
          color: ok ? const Color(0xFF20A978) : kCoralDark,
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
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900),
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: dark ? kDarkCream : kCream,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 13,
              vertical: 14,
            ),
          ),
        ),
      ],
    );

Widget _pill(
  String text,
  VoidCallback onTap,
  bool dark, {
  Color? color,
  Color? foreground,
  bool compact = false,
  double? width,
}) =>
    GestureDetector(
      onTap: onTap,
      child: Container(
        width: width ?? double.infinity,
        height: compact ? 34 : 46,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color ?? (dark ? kDarkCream : kCream),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: foreground ?? (dark ? kCream : kCharcoal),
            fontSize: compact ? 10 : 13,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
