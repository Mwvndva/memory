import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import 'package:memory_app/core/app_providers.dart';
import 'package:memory_app/features/auth/auth.dart';
import 'package:memory_app/core/error_handler.dart';
import 'package:memory_app/design_system/design_system.dart';

class AvatarUploadView extends ConsumerStatefulWidget {
  const AvatarUploadView({super.key});

  @override
  ConsumerState<AvatarUploadView> createState() => _AvatarUploadViewState();
}

class _AvatarUploadViewState extends ConsumerState<AvatarUploadView> {
  Uint8List? _avatarBytes;

  bool _uploading = false;

  Future<void> _pickAvatar() async {
    if (_uploading) return;
    try {
      final file = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 65, // Enforce compression constraint
      );
      if (file == null) return;

      final length = await file.length();
      if (length > 5 * 1024 * 1024) {
        if (mounted) {
          showAppError(context, 'Image must be less than 5 MB.');
        }
        return;
      }

      final ext = file.path.split('.').last.toLowerCase();
      if (ext != 'jpg' && ext != 'jpeg' && ext != 'png' && ext != 'webp') {
        if (mounted) {
          showAppError(
            context,
            'Only JPEG, PNG, or WebP formats are supported.',
          );
        }
        return;
      }

      final bytes = await file.readAsBytes();
      if (!mounted) return;
      setState(() {
        _avatarBytes = bytes;
        _uploading = true;
      });

      await ref.read(sessionProvider.notifier).updateAvatar(bytes);
    } catch (e) {
      if (mounted) {
        showAppError(context, e.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _uploading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = ref.watch(isDarkProvider);
    final bg = dark ? MemoryColors.charcoal : MemoryColors.cream;
    final fg = dark ? MemoryColors.cream : MemoryColors.charcoal;
    final user = ref.watch(authProvider);

    final initialText = user.firstName.isNotEmpty
        ? user.firstName[0].toUpperCase()
        : 'R';

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
                style: headlineStyle(fg).copyWith(fontSize: 34),
              ),
              const SizedBox(height: MemorySpacing.md),
              Text(
                'This helps your circle recognize your memories.',
                textAlign: TextAlign.center,
                style: smallStyle(fg.withValues(alpha: .7)),
              ),
              const SizedBox(height: 26),
              InkWell(
                onTap: _pickAvatar,
                borderRadius: BorderRadius.circular(MemoryRadius.xxl),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: fg.withValues(alpha: .08),
                    borderRadius: BorderRadius.circular(MemoryRadius.xxl),
                  ),
                  child: Column(
                    children: [
                      if (_uploading) ...[
                        const SizedBox(height: MemorySpacing.xl),
                        const MemoryLoading(size: 20),
                      ],
                      MemoryAvatar(
                        radius: 54,
                        dark: dark,
                        bytes: _avatarBytes,
                        initial: initialText,
                        background: MemoryColors.amber,
                      ),
                      const SizedBox(height: MemorySpacing.xl),
                      Text(
                        _uploading
                            ? 'Uploading picture...'
                            : 'Upload profile picture',
                        style: TextStyle(
                          color: fg,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: MemorySpacing.xs),
                      Text(
                        'You can update it later from your profile.',
                        style: smallStyle(fg.withValues(alpha: .62)),
                      ),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              MemoryButton(
                label: 'Continue',
                onPressed: () => context.go('/contacts'),
                dark: dark,
                background: dark ? MemoryColors.accent : MemoryColors.ink,
                foreground: Colors.white,
              ),
              const SizedBox(height: MemorySpacing.lg),
              MemoryButton(
                label: 'Skip for now',
                onPressed: () => context.go('/contacts'),
                dark: dark,
                background: dark ? MemoryColors.cream : MemoryColors.charcoal,
                foreground: dark ? MemoryColors.charcoal : Colors.white,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
