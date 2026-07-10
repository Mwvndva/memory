import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:memory_app/core/error_handler.dart';
import 'package:memory_app/design_system/design_system.dart';
import 'package:memory_app/features/notification/models/notification_item.dart';
import 'package:memory_app/features/notification/services/notification_services.dart';

import '../services/profile_services.dart';

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

    Widget typeSwitch(String label, NotificationType type) => MemorySwitchTile(
      label: label,
      dark: dark,
      value: prefService.isNotificationTypeEnabled(type),
      onChanged: (val) async {
        await prefService.setNotificationTypeEnabled(type, val);
        if (mounted) setState(() {});
      },
    );

    return MemoryBottomSheet(
      dark: dark,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Notification Preferences',
            style: MemoryTypography.titleMedium.copyWith(
              color: dark ? MemoryColors.cream : MemoryColors.charcoal,
            ),
          ),
          const SizedBox(height: MemorySpacing.xl),
          MemorySwitchTile(
            label: 'Push Notifications',
            dark: dark,
            value: prefService.isAllNotificationsEnabled(),
            onChanged: (val) async {
              await prefService.setAllNotificationsEnabled(val);
              if (mounted) setState(() {});
            },
          ),
          typeSwitch('Comments', NotificationType.reaction),
          typeSwitch('Messages', NotificationType.message),
          typeSwitch('Circle Invitations', NotificationType.circleRequest),
          const SizedBox(height: MemorySpacing.xl),
          MemoryButton(
            label: 'Done',
            onPressed: () => Navigator.pop(context),
            dark: dark,
            variant: MemoryButtonVariant.secondary,
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
    ) => MemorySwitchTile(
      label: label,
      dark: dark,
      value: value,
      onChanged: (val) async {
        await onSet(val);
        if (mounted) setState(() {});
      },
    );

    return MemoryBottomSheet(
      dark: dark,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Privacy Settings',
            style: MemoryTypography.titleMedium.copyWith(
              color: dark ? MemoryColors.cream : MemoryColors.charcoal,
            ),
          ),
          const SizedBox(height: MemorySpacing.xl),
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
          const SizedBox(height: MemorySpacing.xl),
          MemoryButton(
            label: 'Done',
            onPressed: () => Navigator.pop(context),
            dark: dark,
            variant: MemoryButtonVariant.secondary,
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

    return MemoryBottomSheet(
      dark: dark,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Security & Active Sessions',
            style: MemoryTypography.titleMedium.copyWith(
              color: dark ? MemoryColors.cream : MemoryColors.charcoal,
            ),
          ),
          const SizedBox(height: MemorySpacing.xl),
          FutureBuilder<List<ActiveSession>>(
            future: _sessions,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const MemoryLoading.block();
              }
              if (snapshot.hasError) {
                return Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: MemorySpacing.xl,
                  ),
                  child: Text(
                    'Could not load your active sessions.',
                    style: MemoryTypography.bodySmall.copyWith(
                      color: (dark ? MemoryColors.cream : MemoryColors.charcoal)
                          .withValues(alpha: 0.7),
                    ),
                  ),
                );
              }

              final sessions = snapshot.data ?? const <ActiveSession>[];
              if (sessions.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: MemorySpacing.xl,
                  ),
                  child: Text(
                    'No active sessions.',
                    style: MemoryTypography.bodySmall.copyWith(
                      color: (dark ? MemoryColors.cream : MemoryColors.charcoal)
                          .withValues(alpha: 0.7),
                    ),
                  ),
                );
              }

              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final s in sessions)
                    MemoryDetailRow(
                      title: s.isCurrent
                          ? '${s.device} (this device)'
                          : s.device,
                      subtitle: s.lastActive,
                      dark: dark,
                      trailing: s.isCurrent
                          ? const Icon(
                              Icons.check_circle,
                              color: MemoryColors.mint,
                              size: 18,
                            )
                          : null,
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: MemorySpacing.xl),
          MemoryButton(
            label: 'Sign out of all other devices',
            // The button now owns its own in-flight state: it dims and shows a
            // spinner rather than swapping its label for "Signing out…".
            onPressed: _signOutOthers,
            isLoading: _signingOut,
            dark: dark,
            variant: MemoryButtonVariant.danger,
          ),
          const SizedBox(height: MemorySpacing.md),
          MemoryButton(
            label: 'Close',
            onPressed: () => Navigator.pop(context),
            dark: dark,
            variant: MemoryButtonVariant.secondary,
          ),
        ],
      ),
    );
  }
}
