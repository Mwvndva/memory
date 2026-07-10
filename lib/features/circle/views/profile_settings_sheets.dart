import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:memory_app/core/error_handler.dart';
import 'package:memory_app/core/theme.dart';
import 'package:memory_app/features/notification/models/notification_item.dart';
import 'package:memory_app/features/notification/services/notification_services.dart';

import '../services/profile_services.dart';
import '../widgets/profile_widgets.dart';

void showNotificationPreferences(BuildContext context, bool dark) {
  showModalBottomSheet(
    context: context,
    useRootNavigator: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _NotificationPreferencesSheet(dark: dark),
  );
}

class _NotificationPreferencesSheet extends ConsumerStatefulWidget {
  const _NotificationPreferencesSheet({required this.dark});

  final bool dark;

  @override
  ConsumerState<_NotificationPreferencesSheet> createState() =>
      _NotificationPreferencesSheetState();
}

class _NotificationPreferencesSheetState
    extends ConsumerState<_NotificationPreferencesSheet> {
  @override
  Widget build(BuildContext context) {
    final dark = widget.dark;
    final prefService = ref.read(notificationPreferencesServiceProvider);

    Widget typeSwitch(String label, NotificationType type) => SwitchListTile(
      title: Text(
        label,
        style: TextStyle(color: dark ? kCream : kCharcoal, fontSize: 13),
      ),
      value: prefService.isNotificationTypeEnabled(type),
      onChanged: (val) async {
        await prefService.setNotificationTypeEnabled(type, val);
        if (mounted) setState(() {});
      },
      activeThumbColor: kYellow,
    );

    return ProfileActionSheet(
      dark: dark,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Notification Preferences',
            style: TextStyle(
              color: dark ? kCream : kCharcoal,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            title: Text(
              'Push Notifications',
              style: TextStyle(color: dark ? kCream : kCharcoal, fontSize: 13),
            ),
            value: prefService.isAllNotificationsEnabled(),
            onChanged: (val) async {
              await prefService.setAllNotificationsEnabled(val);
              if (mounted) setState(() {});
            },
            activeThumbColor: kYellow,
          ),
          typeSwitch('Comments', NotificationType.reaction),
          typeSwitch('Messages', NotificationType.message),
          typeSwitch('Circle Invitations', NotificationType.circleRequest),
          const SizedBox(height: 12),
          ProfilePill(
            text: 'Done',
            onTap: () => Navigator.pop(context),
            dark: dark,
          ),
        ],
      ),
    );
  }
}

void showPrivacySettings(BuildContext context, bool dark) {
  showModalBottomSheet(
    context: context,
    useRootNavigator: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _PrivacySettingsSheet(dark: dark),
  );
}

class _PrivacySettingsSheet extends ConsumerStatefulWidget {
  const _PrivacySettingsSheet({required this.dark});

  final bool dark;

  @override
  ConsumerState<_PrivacySettingsSheet> createState() =>
      _PrivacySettingsSheetState();
}

class _PrivacySettingsSheetState extends ConsumerState<_PrivacySettingsSheet> {
  @override
  Widget build(BuildContext context) {
    final dark = widget.dark;
    final privacyService = ref.read(privacySettingsServiceProvider);

    Widget toggle(
      String label,
      bool value,
      Future<void> Function(bool) onSet,
    ) => SwitchListTile(
      title: Text(
        label,
        style: TextStyle(color: dark ? kCream : kCharcoal, fontSize: 13),
      ),
      value: value,
      onChanged: (val) async {
        await onSet(val);
        if (mounted) setState(() {});
      },
      activeThumbColor: kYellow,
    );

    return ProfileActionSheet(
      dark: dark,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Privacy Settings',
            style: TextStyle(
              color: dark ? kCream : kCharcoal,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          toggle(
            'Profile Visibility',
            privacyService.isProfileVisible(),
            privacyService.setProfileVisible,
          ),
          toggle(
            'Discoverable by Phone',
            privacyService.isDiscoverable(),
            privacyService.setDiscoverable,
          ),
          toggle(
            'Contact Synchronization',
            privacyService.isContactDiscoveryEnabled(),
            privacyService.setContactDiscoveryEnabled,
          ),
          toggle(
            'Receive Circle Invites',
            privacyService.canReceiveCircleInvitations(),
            privacyService.setCanReceiveCircleInvitations,
          ),
          const SizedBox(height: 12),
          ProfilePill(
            text: 'Done',
            onTap: () => Navigator.pop(context),
            dark: dark,
          ),
        ],
      ),
    );
  }
}

void showSecuritySettings(BuildContext context, bool dark) {
  showModalBottomSheet(
    context: context,
    useRootNavigator: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _SecuritySettingsSheet(dark: dark),
  );
}

class _SecuritySettingsSheet extends ConsumerStatefulWidget {
  const _SecuritySettingsSheet({required this.dark});

  final bool dark;

  @override
  ConsumerState<_SecuritySettingsSheet> createState() =>
      _SecuritySettingsSheetState();
}

class _SecuritySettingsSheetState
    extends ConsumerState<_SecuritySettingsSheet> {
  late Future<List<ActiveSession>> _sessions;
  bool _signingOut = false;

  @override
  void initState() {
    super.initState();
    _sessions = ref.read(securitySettingsServiceProvider).fetchActiveSessions();
  }

  Future<void> _signOutOthers() async {
    setState(() => _signingOut = true);
    try {
      final revoked = await ref
          .read(securitySettingsServiceProvider)
          .signOutAllDevices();
      if (!mounted) return;
      Navigator.pop(context);
      showAppMessage(
        context,
        revoked == 0
            ? 'No other devices were signed in.'
            : 'Signed out of $revoked other device${revoked == 1 ? '' : 's'}.',
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _signingOut = false);
      showAppError(context, e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = widget.dark;

    return ProfileActionSheet(
      dark: dark,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Security & Active Sessions',
            style: TextStyle(
              color: dark ? kCream : kCharcoal,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          FutureBuilder<List<ActiveSession>>(
            future: _sessions,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (snapshot.hasError) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    'Could not load your active sessions.',
                    style: TextStyle(
                      color: (dark ? kCream : kCharcoal).withValues(alpha: 0.7),
                      fontSize: 12,
                    ),
                  ),
                );
              }

              final sessions = snapshot.data ?? const <ActiveSession>[];
              if (sessions.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    'No active sessions.',
                    style: TextStyle(
                      color: (dark ? kCream : kCharcoal).withValues(alpha: 0.7),
                      fontSize: 12,
                    ),
                  ),
                );
              }

              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final s in sessions)
                    ListTile(
                      title: Text(
                        s.isCurrent ? '${s.device} (this device)' : s.device,
                        style: TextStyle(
                          color: dark ? kCream : kCharcoal,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      subtitle: Text(
                        s.lastActive,
                        style: TextStyle(
                          color: (dark ? kCream : kCharcoal).withValues(
                            alpha: 0.6,
                          ),
                          fontSize: 11,
                        ),
                      ),
                      trailing: s.isCurrent
                          ? Icon(Icons.check_circle, color: kMint, size: 18)
                          : null,
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          ProfilePill(
            text: _signingOut
                ? 'Signing out…'
                : 'Sign out of all other devices',
            onTap: _signingOut ? () {} : _signOutOthers,
            dark: dark,
            color: Colors.red,
            foreground: Colors.white,
          ),
          const SizedBox(height: 8),
          ProfilePill(
            text: 'Close',
            onTap: () => Navigator.pop(context),
            dark: dark,
          ),
        ],
      ),
    );
  }
}
