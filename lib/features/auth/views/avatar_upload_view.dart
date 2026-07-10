import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import 'package:memory_app/core/theme.dart';
import 'package:memory_app/features/auth/auth.dart';
import 'package:memory_app/core/error_handler.dart';
import 'package:memory_app/shared/widgets/pills.dart';

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
    final bg = dark ? kCharcoal : kCream;
    final fg = dark ? kCream : kCharcoal;
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
              const SizedBox(height: 8),
              Text(
                'This helps your circle recognize your memories.',
                textAlign: TextAlign.center,
                style: smallStyle(fg.withValues(alpha: .7)),
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
                      if (_uploading) ...[
                        const SizedBox(height: 12),
                        const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.amber,
                          ),
                        ),
                      ],
                      CircleAvatar(
                        radius: 54,
                        backgroundColor: kAmber,
                        backgroundImage: _avatarBytes == null
                            ? null
                            : MemoryImage(_avatarBytes!),
                        child: _avatarBytes == null
                            ? Text(
                                initialText,
                                style: const TextStyle(
                                  fontSize: 36,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                ),
                              )
                            : null,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _uploading
                            ? 'Uploading picture...'
                            : 'Upload profile picture',
                        style: TextStyle(
                          color: fg,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'You can update it later from your profile.',
                        style: smallStyle(fg.withValues(alpha: .62)),
                      ),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              pill(
                'Continue',
                () => context.go('/contacts'),
                dark,
                color: dark ? kYellow : kBlack,
                foreground: Colors.white,
              ),
              const SizedBox(height: 10),
              pill(
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
