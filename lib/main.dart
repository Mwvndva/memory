import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

void main() => runApp(const MemoryApp());

const kCream = Color(0xFFFFF8EF);
const kPaper = Color(0xFFFFFFFF);
const kCoral = Color(0xFFFF6B57);
const kCoralDark = Color(0xFFE84F3B);
const kAmber = Color(0xFFFFC857);
const kMint = Color(0xFF5ED6B3);
const kSky = Color(0xFF63B3FF);
const kLavender = Color(0xFFBBA7FF);
const kCharcoal = Color(0xFF292421);
const kDarkPaper = Color(0xFF25211F);
const kDarkCream = Color(0xFF191716);

class MemoryApp extends StatelessWidget {
  const MemoryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Memory',
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Arial',
        colorScheme: ColorScheme.fromSeed(seedColor: kCoral),
      ),
      home: const MemoryPrototype(),
    );
  }
}

enum AuthScreen { loading, login, create, avatar, contacts, app }

enum AppTab { memory, capture, circle }

enum ThemeChoice { system, dark, light }

class MemoryItem {
  const MemoryItem({
    required this.person,
    required this.initial,
    required this.time,
    required this.caption,
    required this.avatar,
    required this.colors,
    required this.ageHours,
  });

  final String person;
  final String initial;
  final String time;
  final String caption;
  final Color avatar;
  final List<Color> colors;
  final double ageHours;
}

class MemoryPrototype extends StatefulWidget {
  const MemoryPrototype({super.key});

  @override
  State<MemoryPrototype> createState() => _MemoryPrototypeState();
}

class _MemoryPrototypeState extends State<MemoryPrototype> {
  final memories = const [
    MemoryItem(
      person: 'Amara',
      initial: 'A',
      time: '8 min ago',
      caption: 'The ridiculous cake moment',
      avatar: kCoral,
      colors: [Color(0xFFFF826E), kAmber, kMint],
      ageHours: .13,
    ),
    MemoryItem(
      person: 'Mum',
      initial: 'M',
      time: 'Yesterday',
      caption: 'Found your old school song',
      avatar: kMint,
      colors: [kMint, kSky, Color(0xFFFFF0B8)],
      ageHours: 26,
    ),
    MemoryItem(
      person: 'Leo',
      initial: 'L',
      time: 'Friday',
      caption: 'Rainy walk after class',
      avatar: kSky,
      colors: [kSky, kLavender, Color(0xFFFFB23E)],
      ageHours: 72,
    ),
    MemoryItem(
      person: 'Nia',
      initial: 'N',
      time: '2 days ago',
      caption: 'Sunset on the way home',
      avatar: kLavender,
      colors: [kLavender, kCoral, kAmber],
      ageHours: 48,
    ),
  ];

  final _username = TextEditingController(text: '@roykeepsmemories');
  final _email = TextEditingController(text: 'roy@memory.app');
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();
  final _loginId = TextEditingController(text: 'roy@memory.app');
  final _loginPassword = TextEditingController();

  AuthScreen auth = AuthScreen.loading;
  AppTab tab = AppTab.memory;
  ThemeChoice themeChoice = ThemeChoice.system;
  bool hasRecording = false;
  bool composerOpen = false;
  bool gridOpen = false;
  bool fromGrid = false;
  bool captureCaptionOpen = false;
  String? activeChat;
  int activeMemory = 0;
  int newNotifications = 3;
  int circleCount = 12;
  final _captureCaption = TextEditingController();
  Offset captureCaptionOffset = const Offset(78, 250);
  double captureCaptionSize = 24;
  String usernameStatus = 'Choose something people recognize.';
  bool usernameOk = false;
  String passwordStatus = 'Use at least 8 characters.';
  bool passwordOk = false;
  Uint8List? avatarBytes;
  String accountEmail = 'roy@memory.app';
  String accountUsername = 'roykeepsmemories';
  String accountPassword = 'Password1';
  Timer? _loadingTimer;

  final unavailable = {'roy', 'memory', 'amara', 'leo', 'mum'};
  final countryCodes = const [
    '🇰🇪',
    '🇺🇸',
    '🇬🇧',
    '🇨🇦',
    '🇳🇬',
    '🇿🇦',
    '🇬🇭',
    '🇺🇬',
    '🇹🇿',
    '🇷🇼',
    '🇪🇹',
    '🇪🇬',
    '🇮🇳',
    '🇵🇰',
    '🇧🇩',
    '🇨🇳',
    '🇯🇵',
    '🇰🇷',
    '🇦🇺',
    '🇳🇿',
    '🇫🇷',
    '🇩🇪',
    '🇮🇹',
    '🇪🇸',
    '🇧🇷',
    '🇲🇽',
    '🇦🇪',
    '🇸🇦',
  ];
  String selectedCountry = '🇰🇪';

  @override
  void initState() {
    super.initState();
    _loadingTimer = Timer(const Duration(milliseconds: 1100), () {
      if (mounted) setState(() => auth = AuthScreen.login);
    });
    _username.addListener(_checkUsername);
    _password.addListener(_checkPassword);
    _confirmPassword.addListener(_checkPassword);
  }

  @override
  void dispose() {
    _loadingTimer?.cancel();
    _loginId.dispose();
    _loginPassword.dispose();
    _username.dispose();
    _email.dispose();
    _password.dispose();
    _confirmPassword.dispose();
    _captureCaption.dispose();
    super.dispose();
  }

  bool get dark {
    if (themeChoice == ThemeChoice.dark) return true;
    if (themeChoice == ThemeChoice.light) return false;
    final platform =
        WidgetsBinding.instance.platformDispatcher.platformBrightness;
    return platform == Brightness.dark;
  }

  List<int> get feedIndexes {
    final indexes = <int>[];
    for (var i = 0; i < memories.length; i++) {
      if (memories[i].ageHours < 24) indexes.add(i);
    }
    return indexes;
  }

  List<int> get gridIndexes {
    final archived = <int>[];
    for (var i = 0; i < memories.length; i++) {
      if (memories[i].ageHours >= 24) archived.add(i);
    }
    return List.generate(12, (i) => archived[i % archived.length]);
  }

  MemoryItem get current {
    final source = fromGrid ? gridIndexes : feedIndexes;
    return memories[source[activeMemory % source.length]];
  }

  void _checkUsername() {
    final value = _username.text.trim().replaceFirst('@', '').toLowerCase();
    String message;
    var ok = false;
    if (value.length < 3) {
      message = 'Use at least 3 characters.';
    } else if (value.length > 30) {
      message = 'Use 30 characters or fewer.';
    } else if (!RegExp(r'^[a-z0-9._]+$').hasMatch(value)) {
      message = 'Only letters, numbers, periods, and underscores.';
    } else if (value.startsWith('.') ||
        value.endsWith('.') ||
        value.contains('..')) {
      message = 'Periods cannot start, end, or repeat.';
    } else if (unavailable.contains(value)) {
      message = '@$value is taken.';
    } else {
      message = '@$value is available.';
      ok = true;
    }
    setState(() {
      usernameStatus = message;
      usernameOk = ok;
    });
  }

  void _checkPassword() {
    final pass = _password.text;
    String message;
    var ok = false;
    if (pass.length < 8) {
      message = 'Use at least 8 characters.';
    } else if (!RegExp('[A-Z]').hasMatch(pass) ||
        !RegExp('[a-z]').hasMatch(pass)) {
      message = 'Use uppercase and lowercase letters.';
    } else if (pass != _confirmPassword.text) {
      message = 'Passwords do not match.';
    } else {
      message = 'Passwords match.';
      ok = true;
    }
    setState(() {
      passwordStatus = message;
      passwordOk = ok;
    });
  }

  Future<void> _pickAvatar() async {
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 82,
    );
    if (file == null) return;
    avatarBytes = await file.readAsBytes();
    setState(() {});
  }

  void _createAccount() {
    _checkUsername();
    _checkPassword();
    if (!usernameOk || !passwordOk) return;
    accountEmail = _email.text.trim().toLowerCase();
    accountUsername = _username.text.trim().replaceFirst('@', '').toLowerCase();
    accountPassword = _password.text;
    setState(() => auth = AuthScreen.avatar);
  }

  void _login() {
    final id = _loginId.text.trim().replaceFirst('@', '').toLowerCase();
    final raw = _loginId.text.trim().toLowerCase();
    if ((raw == accountEmail || id == accountUsername) &&
        _loginPassword.text == accountPassword) {
      setState(() => auth = AuthScreen.app);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bg = dark ? const Color(0xFF11100F) : const Color(0xFFFFF4E4);
    final viewport = MediaQuery.sizeOf(context);
    final useDeviceViewport = viewport.width < 430;
    return Scaffold(
      backgroundColor: bg,
      body: Align(
        alignment: Alignment.center,
        child: SizedBox(
          width: useDeviceViewport ? viewport.width : 390,
          height: useDeviceViewport ? viewport.height : 844,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(useDeviceViewport ? 0 : 34),
            child: auth == AuthScreen.app ? _appScaffold() : _authLayer(),
          ),
        ),
      ),
    );
  }

  Widget _authLayer() {
    final bg = dark ? kCharcoal : Colors.white;
    final fg = dark ? kCream : kCharcoal;
    return Container(
      color: bg,
      child: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 240),
          child: switch (auth) {
            AuthScreen.loading => _loading(bg),
            AuthScreen.login => _loginScreen(fg),
            AuthScreen.create => _createScreen(fg),
            AuthScreen.avatar => _avatarScreen(fg),
            AuthScreen.contacts => _contactsScreen(fg),
            AuthScreen.app => const SizedBox.shrink(),
          },
        ),
      ),
    );
  }

  Widget _logo({double size = 170}) => Image.asset(
    'assets/images/memory-logo.png',
    width: size,
    height: size,
    fit: BoxFit.contain,
  );

  Widget _loading(Color bg) => Container(
    key: const ValueKey('loading'),
    color: bg,
    child: Center(child: _logo(size: 220)),
  );

  Widget _loginScreen(Color fg) => Padding(
    key: const ValueKey('login'),
    padding: const EdgeInsets.fromLTRB(26, 38, 26, 28),
    child: Column(
      children: [
        const Spacer(),
        _logo(size: 170),
        Text('Memory', style: _headline(fg, 34)),
        const SizedBox(height: 8),
        Text(
          'Your circle is waiting.',
          style: _small(fg.withValues(alpha: .68)),
        ),
        const Spacer(),
        _field('Email or username', _loginId, 'roy@memory.app or @roy'),
        const SizedBox(height: 12),
        _field('Password', _loginPassword, 'Your password', obscure: true),
        const SizedBox(height: 12),
        _pill('Continue', _login, color: kCoral, foreground: Colors.white),
        const SizedBox(height: 110),
        _pill(
          'Create account',
          () => setState(() => auth = AuthScreen.create),
          color: dark ? kCream : kCharcoal,
          foreground: dark ? kCharcoal : Colors.white,
        ),
      ],
    ),
  );

  Widget _createScreen(Color fg) => Stack(
    key: const ValueKey('create'),
    children: [
      Positioned.fill(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(26, 78, 26, 28),
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
                    child: _field(
                      'First name',
                      TextEditingController(text: 'Roy'),
                      'Roy',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _field(
                      'Last name',
                      TextEditingController(text: 'Nthiga'),
                      'Nthiga',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _field('Username', _username, '@roykeepsmemories'),
              _status(usernameStatus, usernameOk),
              const SizedBox(height: 10),
              _field(
                'Email',
                _email,
                'roy@memory.app',
                keyboard: TextInputType.emailAddress,
              ),
              const SizedBox(height: 12),
              _phoneField(),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _field(
                      'Password',
                      _password,
                      'Password',
                      obscure: true,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _field(
                      'Confirm password',
                      _confirmPassword,
                      'Repeat password',
                      obscure: true,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              _status(passwordStatus, passwordOk),
              const SizedBox(height: 14),
              _pill(
                'Create account',
                _createAccount,
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
            () => setState(() => auth = AuthScreen.login),
            compact: true,
          ),
        ),
      ),
    ],
  );

  Widget _avatarScreen(Color fg) => Padding(
    key: const ValueKey('avatar'),
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
                  backgroundImage: avatarBytes == null
                      ? null
                      : MemoryImage(avatarBytes!),
                  child: avatarBytes == null
                      ? const Text(
                          'R',
                          style: TextStyle(
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
          () => setState(() => auth = AuthScreen.contacts),
          color: kCoral,
          foreground: Colors.white,
        ),
        const SizedBox(height: 10),
        _pill(
          'Skip for now',
          () => setState(() => auth = AuthScreen.contacts),
          color: dark ? kCream : kCharcoal,
          foreground: dark ? kCharcoal : Colors.white,
        ),
      ],
    ),
  );

  Widget _contactsScreen(Color fg) => Padding(
    key: const ValueKey('contacts'),
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
        ...[
          ('A', 'Amara', '@amara', kCoral),
          ('M', 'Mum', '@mumsmemories', kMint),
          ('L', 'Leo', '@leowalks', kSky),
        ].map((c) => _contactRow(c.$1, c.$2, c.$3, c.$4, fg)),
        const SizedBox(height: 14),
        _inviteCard(),
        const Spacer(),
        _pill(
          'Start using Memory',
          () => setState(() => auth = AuthScreen.app),
          color: kCoral,
          foreground: Colors.white,
        ),
      ],
    ),
  );

  Widget _contactRow(
    String initial,
    String name,
    String user,
    Color color,
    Color fg,
  ) => Container(
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
              Text(user, style: _small(fg.withValues(alpha: .58))),
            ],
          ),
        ),
        SizedBox(
          width: 104,
          height: 34,
          child: _pill(
            'Add to circle',
            () {},
            compact: true,
            color: kCoral,
            foreground: Colors.white,
          ),
        ),
      ],
    ),
  );

  Widget _inviteCard() => Container(
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
              child: _pill(
                'Instagram',
                () {},
                compact: true,
                color: const Color(0xFFE4405F),
                foreground: Colors.white,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _pill(
                'WhatsApp',
                () {},
                compact: true,
                color: const Color(0xFF25D366),
                foreground: Colors.white,
              ),
            ),
          ],
        ),
      ],
    ),
  );

  Widget _appScaffold() {
    return Container(
      color: dark ? kDarkCream : kCream,
      child: Stack(
        children: [
          Positioned.fill(
            child: switch (tab) {
              AppTab.memory => _memoryScreen(),
              AppTab.capture => _captureScreen(),
              AppTab.circle => _circleScreen(),
            },
          ),
          Positioned(left: 18, right: 18, bottom: 18, child: _tabBar()),
        ],
      ),
    );
  }

  Widget _memoryScreen() {
    final m = current;
    final top = MediaQuery.paddingOf(context).top;
    return GestureDetector(
      onVerticalDragEnd: (details) {
        if ((details.primaryVelocity ?? 0) < 0) _nextMemory();
        if ((details.primaryVelocity ?? 0) > 0) _previousMemory();
      },
      onTap: () => setState(() => composerOpen = !composerOpen),
      child: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: m.colors,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
          ),
          Positioned(
            top: top + 16,
            left: 22,
            child: _roundIcon(
              fromGrid && !gridOpen
                  ? Icons.arrow_back_ios_new_rounded
                  : Icons.grid_view_rounded,
              () {
                setState(() {
                  gridOpen = true;
                  composerOpen = false;
                });
              },
            ),
          ),
          Positioned(
            top: top + 16,
            right: 22,
            child: _roundIcon(Icons.volume_up_rounded, () {}),
          ),
          Positioned(
            top: top + 34,
            left: 0,
            right: 0,
            child: Column(
              children: [
                CircleAvatar(
                  radius: 23,
                  backgroundColor: m.avatar,
                  child: Text(
                    m.initial,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  m.person,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  m.time,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 56),
              child: Text(
                m.caption,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  height: 1.05,
                ),
              ),
            ),
          ),
          if (composerOpen)
            Positioned(
              left: 44,
              right: 16,
              bottom: 94,
              child: _messageComposer(m),
            ),
          if (gridOpen) _memoryGrid(),
        ],
      ),
    );
  }

  Widget _memoryGrid() => GestureDetector(
    onHorizontalDragEnd: (details) {
      if ((details.primaryVelocity ?? 0) < 0) setState(() => gridOpen = false);
    },
    child: Container(
      color: dark ? kCharcoal : kPaper,
      padding: const EdgeInsets.fromLTRB(26, 82, 26, 90),
      child: Column(
        children: [
          Row(
            children: [
              const Spacer(),
              Text(
                'All memories',
                style: TextStyle(
                  color: dark ? kCream : kCharcoal,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const Spacer(),
              _smallClose(() {
                setState(() {
                  gridOpen = false;
                  if (fromGrid) {
                    fromGrid = false;
                    activeMemory = 0;
                  }
                });
              }),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: GridView.builder(
              itemCount: gridIndexes.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                mainAxisSpacing: 7,
                crossAxisSpacing: 7,
                childAspectRatio: .74,
              ),
              itemBuilder: (_, i) {
                final m = memories[gridIndexes[i]];
                return GestureDetector(
                  onTap: () => setState(() {
                    fromGrid = true;
                    activeMemory = i;
                    gridOpen = false;
                  }),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      gradient: LinearGradient(
                        colors: m.colors,
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Align(
                      alignment: Alignment.bottomLeft,
                      child: Padding(
                        padding: const EdgeInsets.all(7),
                        child: CircleAvatar(
                          radius: 11,
                          backgroundColor: m.avatar,
                          child: Text(
                            m.initial,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
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

  Widget _messageComposer(MemoryItem m) => SizedBox(
    height: 118,
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Container(
            height: 50,
            padding: const EdgeInsets.only(left: 16, right: 6),
            decoration: BoxDecoration(
              color: dark ? kDarkPaper : Colors.white,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Send ${m.person} a message',
                    style: TextStyle(
                      color: dark ? kCream : kCharcoal,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Container(
                  width: 54,
                  height: 38,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: kCoral,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Text(
                    'Send',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 28,
          height: 118,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text('❤️', style: TextStyle(fontSize: 18)),
              Text('😂', style: TextStyle(fontSize: 18)),
              Text('🔥', style: TextStyle(fontSize: 18)),
              Text('😭', style: TextStyle(fontSize: 18)),
              Text('✨', style: TextStyle(fontSize: 18)),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _captureScreen() => Container(
    decoration: _softBackground(),
    child: SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 24, 28, 94),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'What made you smile today?',
              style: TextStyle(
                color: dark ? kCream : kCharcoal,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 16),
            Expanded(child: _capturePreview()),
            const SizedBox(height: 12),
            Center(
              child: hasRecording
                  ? _pill(
                      'Send to circle',
                      () => setState(() {
                        hasRecording = false;
                        captureCaptionOpen = false;
                        _captureCaption.clear();
                      }),
                      color: dark ? kCoral : kCharcoal,
                      foreground: Colors.white,
                      width: 282,
                    )
                  : GestureDetector(
                      onTap: () => setState(() {
                        hasRecording = true;
                        captureCaptionOpen = false;
                      }),
                      child: Container(
                        width: 82,
                        height: 82,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: kCoral,
                          border: Border.all(
                            color: const Color(0xFFFFE7DD),
                            width: 10,
                          ),
                        ),
                        child: const Icon(
                          Icons.circle,
                          color: Colors.white,
                          size: 30,
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _capturePreview() => GestureDetector(
    onTap: hasRecording
        ? () => setState(() => captureCaptionOpen = true)
        : null,
    child: Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          colors: [Color(0xFF4A2B27), Color(0xFFA84538)],
        ),
      ),
      child: Stack(
        children: [
          if (!hasRecording)
            const Center(
              child: Icon(
                Icons.videocam_rounded,
                color: Colors.white24,
                size: 54,
              ),
            ),
          if (hasRecording && captureCaptionOpen) _captureCaptionEditor(),
        ],
      ),
    ),
  );

  Widget _captureCaptionEditor() => Positioned(
    left: captureCaptionOffset.dx,
    top: captureCaptionOffset.dy,
    child: GestureDetector(
      onScaleUpdate: (details) => setState(() {
        captureCaptionOffset += details.focalPointDelta;
        captureCaptionSize = (captureCaptionSize * details.scale).clamp(16, 42);
      }),
      child: SizedBox(
        width: 210,
        child: TextField(
          controller: _captureCaption,
          autofocus: true,
          maxLines: 2,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontSize: captureCaptionSize,
            fontWeight: FontWeight.w900,
            height: 1.05,
          ),
          decoration: const InputDecoration(
            border: InputBorder.none,
            hintText: 'Add caption',
            hintStyle: TextStyle(color: Colors.white70),
          ),
        ),
      ),
    ),
  );

  Widget _circleScreen() =>
      activeChat == null ? _chatListScreen() : _inboxScreen(activeChat!);

  Widget _chatListScreen() => Container(
    padding: const EdgeInsets.fromLTRB(22, 74, 22, 94),
    decoration: _softBackground(),
    child: Stack(
      children: [
        Column(
          children: [
            Row(
              children: [
                const SizedBox(width: 44),
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        'Chats',
                        style: TextStyle(
                          color: kCoralDark,
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        'Your circle',
                        style: TextStyle(
                          color: dark ? kCream : kCharcoal,
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => _showProfileSheet(),
                  child: const CircleAvatar(
                    radius: 22,
                    backgroundColor: kCoral,
                    child: Text(
                      'R',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            ...['Amara', 'Mum', 'Leo', 'Nia'].map((name) => _chatRow(name)),
          ],
        ),
      ],
    ),
  );

  Widget _inboxScreen(String name) => Container(
    padding: const EdgeInsets.fromLTRB(22, 64, 22, 94),
    decoration: _softBackground(),
    child: Column(
      children: [
        Row(
          children: [
            _smallClose(() => setState(() => activeChat = null)),
            const SizedBox(width: 12),
            CircleAvatar(backgroundColor: kCoral, child: Text(name[0])),
            const SizedBox(width: 10),
            Text(
              name,
              style: TextStyle(
                color: dark ? kCream : kCharcoal,
                fontSize: 24,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        _inboxBubble(name, 'Reacted 😂 to your memory', false),
        _inboxBubble(name, 'That video made my day.', false),
        _inboxBubble('You', 'I still can’t believe it happened.', true),
        const Spacer(),
        Container(
          height: 52,
          padding: const EdgeInsets.only(left: 16, right: 6),
          decoration: BoxDecoration(
            color: dark ? kDarkPaper : kPaper,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Message $name',
                  style: TextStyle(
                    color: dark ? kCream : kCharcoal,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Container(
                width: 56,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: kCoral,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text(
                  'Send',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _inboxBubble(String from, String text, bool mine) => Align(
    alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
    child: Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      constraints: const BoxConstraints(maxWidth: 260),
      decoration: BoxDecoration(
        color: mine ? kCoral : (dark ? kDarkPaper : kPaper),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: mine ? Colors.white : (dark ? kCream : kCharcoal),
          fontSize: 13,
          fontWeight: FontWeight.w800,
        ),
      ),
    ),
  );

  Future<void> _showProfileSheet() => showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => StatefulBuilder(
      builder: (context, sheetSetState) => _profilePanel(sheetSetState),
    ),
  );

  Widget _profilePanel(StateSetter sheetSetState) => Container(
    height: 710,
    margin: const EdgeInsets.all(18),
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: dark ? kDarkPaper : kPaper,
      borderRadius: BorderRadius.circular(30),
    ),
    child: Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Close',
                style: TextStyle(
                  color: dark ? kCream : kCharcoal,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
              decoration: BoxDecoration(
                color: dark ? kDarkCream : kCream,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                children: [
                  const Text(
                    '🇰🇪',
                    style: TextStyle(
                      color: kCoral,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '12',
                    style: TextStyle(
                      color: dark ? kCream : kCharcoal,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Icon(
                    Icons.public_rounded,
                    color: dark ? kCream : kCharcoal,
                    size: 13,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    '428',
                    style: TextStyle(
                      color: dark ? kCream : kCharcoal,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        CircleAvatar(
          radius: 29,
          backgroundColor: kCoral,
          backgroundImage: avatarBytes == null
              ? null
              : MemoryImage(avatarBytes!),
          child: avatarBytes == null
              ? const Text(
                  'R',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 23,
                    fontWeight: FontWeight.w900,
                  ),
                )
              : null,
        ),
        const SizedBox(height: 8),
        Text(
          'Roy Nthiga',
          style: TextStyle(
            color: dark ? kCream : kCharcoal,
            fontSize: 21,
            fontWeight: FontWeight.w900,
          ),
        ),
        Text(
          '@roykeepsmemories',
          style: _small(
            dark ? const Color(0xFFC9B8AA) : const Color(0xFF776B62),
          ),
        ),
        const SizedBox(height: 12),
        _themePicker(sheetSetState),
        const SizedBox(height: 8),
        _statCards(),
        const SizedBox(height: 8),
        _detail('First name', 'Roy'),
        _detail('Last name', 'Nthiga'),
        _detail('Email', accountEmail),
        _detail('Phone', '+254 712 345 678'),
        _detail('Username', '@$accountUsername'),
        const SizedBox(height: 10),
        _addPersonCard(),
      ],
    ),
  );

  Widget _themePicker([StateSetter? sheetSetState]) => Container(
    width: 236,
    padding: const EdgeInsets.all(7),
    decoration: BoxDecoration(
      color: dark ? kDarkCream : kCream,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Row(
      children: ThemeChoice.values.map((choice) {
        final label = choice == ThemeChoice.system
            ? 'Device'
            : choice.name[0].toUpperCase() + choice.name.substring(1);
        final active = choice == themeChoice;
        return Expanded(
          child: GestureDetector(
            onTap: () {
              setState(() => themeChoice = choice);
              sheetSetState?.call(() {});
            },
            child: Container(
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: active ? kCoral : Colors.transparent,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                label,
                style: TextStyle(
                  color: active ? Colors.white : (dark ? kCream : kCharcoal),
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    ),
  );

  Widget _statCards() => Column(
    children: [
      _statCard('Memories', '14 days', const [kCoral, kAmber]),
      const SizedBox(height: 8),
      _statCard('Circle Pulse', '8 days', const [kMint, kSky]),
    ],
  );

  Widget _statCard(String title, String value, List<Color> colors) => Container(
    height: 64,
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      gradient: LinearGradient(colors: colors),
      borderRadius: BorderRadius.circular(18),
    ),
    child: Row(
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(width: 12),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 19,
            fontWeight: FontWeight.w900,
          ),
        ),
        const Spacer(),
        _sharePill(
          'Instagram',
          () => _showShareCard(title, value, 'Instagram', colors),
        ),
        const SizedBox(width: 5),
        _sharePill(
          'WhatsApp',
          () => _showShareCard(title, value, 'WhatsApp', colors),
        ),
      ],
    ),
  );

  Widget _sharePill(String text, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 58,
      height: 28,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .92),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: kCharcoal,
          fontSize: 8,
          fontWeight: FontWeight.w900,
        ),
      ),
    ),
  );

  Future<void> _showShareCard(
    String title,
    String value,
    String channel,
    List<Color> colors,
  ) => showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (_) => _actionSheet(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _funCard(
            title: title,
            value: value,
            label: 'Memory is alive',
            colors: colors,
            icon: channel == 'Instagram'
                ? Icons.camera_alt_rounded
                : Icons.chat_bubble_rounded,
          ),
          const SizedBox(height: 14),
          _pill(
            'Send to $channel',
            () => Navigator.pop(context),
            color: kCoral,
            foreground: Colors.white,
          ),
        ],
      ),
    ),
  );

  Future<void> _showInviteOptions() => showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (_) => _actionSheet(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _funCard(
            title: 'Join my circle',
            value: '12 / 30',
            label: 'memory.app/invite/roy',
            colors: const [kCoral, kAmber],
            icon: Icons.favorite_rounded,
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _pill(
                  'Instagram',
                  () => Navigator.pop(context),
                  compact: true,
                  color: const Color(0xFFE1306C),
                  foreground: Colors.white,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _pill(
                  'WhatsApp',
                  () => Navigator.pop(context),
                  compact: true,
                  color: const Color(0xFF25D366),
                  foreground: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _pill(
            'Copy invite link',
            () {
              Clipboard.setData(
                const ClipboardData(text: 'https://memory.app/invite/roy'),
              );
              Navigator.pop(context);
            },
            color: dark ? kCream : kCharcoal,
            foreground: dark ? kCharcoal : Colors.white,
          ),
        ],
      ),
    ),
  );

  Widget _actionSheet({required Widget child}) => Container(
    margin: const EdgeInsets.all(18),
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: dark ? kDarkPaper : kPaper,
      borderRadius: BorderRadius.circular(26),
    ),
    child: child,
  );

  Widget _funCard({
    required String title,
    required String value,
    required String label,
    required List<Color> colors,
    required IconData icon,
  }) => Container(
    width: double.infinity,
    height: 230,
    padding: const EdgeInsets.all(22),
    decoration: BoxDecoration(
      gradient: LinearGradient(colors: colors),
      borderRadius: BorderRadius.circular(28),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: Colors.white, size: 34),
        const Spacer(),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 38,
            fontWeight: FontWeight.w900,
          ),
        ),
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    ),
  );

  Widget _detail(String a, String b) => Container(
    margin: const EdgeInsets.only(bottom: 6),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
    decoration: BoxDecoration(
      color: dark ? kDarkCream : kCream,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Row(
      children: [
        Text(
          a,
          style: _small(
            dark ? const Color(0xFFC9B8AA) : const Color(0xFF776B62),
          ),
        ),
        const Spacer(),
        Text(
          b,
          style: TextStyle(
            color: dark ? kCream : kCharcoal,
            fontSize: 12,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    ),
  );

  Widget _addPersonCard() => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: dark ? kDarkCream : kCream,
      borderRadius: BorderRadius.circular(18),
    ),
    child: Row(
      children: [
        Text(
          '$circleCount / 30\nin your circle',
          style: const TextStyle(
            color: kCoralDark,
            fontSize: 19,
            fontWeight: FontWeight.w900,
          ),
        ),
        const Spacer(),
        SizedBox(
          width: 116,
          child: _pill(
            'Add someone',
            circleCount < 30 ? _showInviteOptions : () {},
            compact: true,
            color: kCoral,
            foreground: Colors.white,
          ),
        ),
      ],
    ),
  );

  Widget _chatRow(String name) => GestureDetector(
    onTap: () => setState(() {
      activeChat = name;
      if (newNotifications > 0) newNotifications--;
    }),
    child: Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: dark ? kDarkPaper : kPaper,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: kCoral,
            child: Text(
              name[0],
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
                  style: TextStyle(
                    color: dark ? kCream : kCharcoal,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  'Sent a memory',
                  style: _small(
                    dark ? const Color(0xFFC9B8AA) : const Color(0xFF776B62),
                  ),
                ),
              ],
            ),
          ),
          const Text(
            '8m',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              color: kCoralDark,
            ),
          ),
        ],
      ),
    ),
  );

  Widget _tabBar() => Container(
    height: 58,
    padding: const EdgeInsets.all(7),
    decoration: BoxDecoration(
      color: (dark ? kDarkPaper : kPaper).withValues(alpha: .9),
      borderRadius: BorderRadius.circular(999),
    ),
    child: Row(
      children: [
        _tab(AppTab.memory, Icons.more_horiz_rounded, 'Memory'),
        _tab(
          AppTab.capture,
          Icons.radio_button_checked_rounded,
          'Capture',
          wide: true,
        ),
        _tab(
          AppTab.circle,
          Icons.circle_outlined,
          'Circle',
          badge: newNotifications > 0 ? '$newNotifications' : null,
        ),
      ],
    ),
  );

  Widget _tab(
    AppTab value,
    IconData icon,
    String label, {
    bool wide = false,
    String? badge,
  }) {
    final active = tab == value;
    return Expanded(
      flex: wide ? 12 : 10,
      child: GestureDetector(
        onTap: () => setState(() => tab = value),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              height: 44,
              decoration: BoxDecoration(
                color: active
                    ? (dark ? const Color(0xFF4A2B27) : const Color(0xFFFFE7DD))
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    icon,
                    size: 18,
                    color: active
                        ? kCoral
                        : (dark
                              ? const Color(0xFFC9B8AA)
                              : const Color(0xFF776B62)),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: TextStyle(
                      color: active
                          ? kCoral
                          : (dark
                                ? const Color(0xFFC9B8AA)
                                : const Color(0xFF776B62)),
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
            if (badge != null)
              Positioned(
                right: 8,
                top: -3,
                child: CircleAvatar(
                  radius: 9,
                  backgroundColor: kCoral,
                  child: Text(
                    badge,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  BoxDecoration _softBackground() => BoxDecoration(
    color: dark ? kDarkCream : kCream,
    gradient: LinearGradient(
      colors: dark
          ? const [kDarkCream, kCharcoal]
          : const [Color(0xFFFFF4E4), Color(0xFFEFFFF8)],
      begin: Alignment.topRight,
      end: Alignment.bottomLeft,
    ),
  );

  Widget _roundIcon(IconData icon, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .22),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: Colors.white, size: 20),
    ),
  );

  Widget _smallClose(VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: dark ? kDarkCream : kCream,
        shape: BoxShape.circle,
      ),
      child: Icon(
        Icons.close_rounded,
        color: dark ? kCream : kCharcoal,
        size: 18,
      ),
    ),
  );

  void _nextMemory() {
    final count = fromGrid ? gridIndexes.length : feedIndexes.length;
    setState(() => activeMemory = (activeMemory + 1) % count);
  }

  void _previousMemory() {
    final count = fromGrid ? gridIndexes.length : feedIndexes.length;
    setState(() => activeMemory = (activeMemory - 1 + count) % count);
  }

  Widget _field(
    String label,
    TextEditingController controller,
    String hint, {
    bool obscure = false,
    TextInputType? keyboard,
  }) => Column(
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

  Widget _phoneField() => Column(
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
          Expanded(child: _plainInput('712 345 678')),
        ],
      ),
    ],
  );

  Widget _plainInput(String hint) => TextField(
    keyboardType: TextInputType.phone,
    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900),
    decoration: InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: dark ? kDarkCream : kCream,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 13, vertical: 14),
    ),
  );

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

  Widget _pill(
    String text,
    VoidCallback onTap, {
    Color? color,
    Color? foreground,
    bool compact = false,
    double? width,
  }) => GestureDetector(
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

  TextStyle _headline(Color color, double size) => TextStyle(
    color: color,
    fontSize: size,
    fontWeight: FontWeight.w900,
    height: 1,
  );
  TextStyle _small(Color color) =>
      TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w900);
}
