import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:memory_app/core/error_handler.dart';
import 'package:memory_app/core/theme.dart';

import '../services/profile_services.dart';

// As in profile_share_card.dart, these dialogs close over the caller's
// [context]: it outlives the dialog, and the export confirmation is shown
// after the dialog has already been popped.

void showExportDialog(BuildContext context, bool dark) {
  showDialog(
    context: context,
    builder: (ctx) => Consumer(
      builder: (_, ref, _) => AlertDialog(
        backgroundColor: dark ? kBlack : Colors.white,
        title: Text(
          'Export My Data',
          style: TextStyle(color: dark ? kCream : kCharcoal),
        ),
        content: Text(
          'Requesting an export will compile all your Profile statistics, Memories, Messages, Settings, and Activity history into an archive. Compile starts in the background.',
          style: TextStyle(
            color: (dark ? kCream : kCharcoal).withValues(alpha: 0.8),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: (dark ? kCream : kCharcoal).withValues(alpha: 0.6),
              ),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final exportService = ref.read(accountExportServiceProvider);
              try {
                final res = await exportService.requestExport();
                if (context.mounted) {
                  showAppMessage(
                    context,
                    res['message'] as String? ?? 'Export ready',
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  showAppError(context, 'Export failed: $e');
                }
              }
            },
            child: const Text(
              'Request Export',
              style: TextStyle(color: kYellow, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    ),
  );
}

void showDeleteAccountDialog(BuildContext context, bool dark) {
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: dark ? kBlack : Colors.white,
      title: const Text(
        'Delete Account',
        style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
      ),
      content: const Text(
        'WARNING: Deleting your account is permanent and irreversible. All your memories, messages, circle associations, and history will be securely deleted from our databases.',
        style: TextStyle(color: Colors.red),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: Text(
            'Cancel',
            style: TextStyle(
              color: (dark ? kCream : kCharcoal).withValues(alpha: 0.6),
            ),
          ),
        ),
        TextButton(
          onPressed: () {
            Navigator.pop(ctx);
            _confirmAccountDeletion(context, dark);
          },
          child: const Text(
            'Continue Deletion',
            style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    ),
  );
}

void _confirmAccountDeletion(BuildContext context, bool dark) {
  showDialog(
    context: context,
    builder: (ctx) => Consumer(
      builder: (_, ref, _) => AlertDialog(
        backgroundColor: dark ? kBlack : Colors.white,
        title: const Text(
          'Final Confirmation',
          style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Please confirm you wish to remove your account. We will proceed to validate requests and sign you out.',
          style: TextStyle(color: dark ? kCream : kCharcoal),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: (dark ? kCream : kCharcoal).withValues(alpha: 0.6),
              ),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx); // Close dialog
              final deletionService = ref.read(accountDeletionServiceProvider);
              try {
                // Deletes the account server-side, then signs out — which
                // tears the profile sheet down with the rest of the session.
                await deletionService.confirmDeletion();
              } catch (e) {
                if (context.mounted) {
                  showAppError(context, 'Could not delete your account: $e');
                }
              }
            },
            child: const Text(
              'Delete Permanently',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    ),
  );
}
