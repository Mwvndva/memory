import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:memory_app/core/error_handler.dart';
import 'package:memory_app/design_system/design_system.dart';

import '../services/profile_services.dart';

// As in profile_share_card.dart, these dialogs close over the caller's
// [context]: it outlives the dialog, and the export confirmation is shown
// after the dialog has already been popped.

void showExportDialog(BuildContext context, bool dark) {
  MemoryDialog.show(
    context: context,
    builder: (ctx) => Consumer(
      builder: (_, ref, _) => MemoryDialog(
        title: 'Export My Data',
        dark: dark,
        message:
            'Requesting an export will compile all your Profile statistics, Memories, Messages, Settings, and Activity history into an archive. Compile starts in the background.',
        actions: [
          MemoryDialogAction(
            label: 'Cancel',
            onPressed: () => Navigator.pop(ctx),
          ),
          MemoryDialogAction(
            label: 'Request Export',
            isPrimary: true,
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
          ),
        ],
      ),
    ),
  );
}

void showDeleteAccountDialog(BuildContext context, bool dark) {
  MemoryDialog.show(
    context: context,
    builder: (ctx) => MemoryDialog(
      title: 'Delete Account',
      dark: dark,
      isDestructive: true,
      message:
          'WARNING: Deleting your account is permanent and irreversible. All your memories, messages, circle associations, and history will be securely deleted from our databases.',
      actions: [
        MemoryDialogAction(
          label: 'Cancel',
          onPressed: () => Navigator.pop(ctx),
        ),
        MemoryDialogAction(
          label: 'Continue Deletion',
          isDestructive: true,
          onPressed: () {
            Navigator.pop(ctx);
            _confirmAccountDeletion(context, dark);
          },
        ),
      ],
    ),
  );
}

void _confirmAccountDeletion(BuildContext context, bool dark) {
  MemoryDialog.show(
    context: context,
    builder: (ctx) => Consumer(
      builder: (_, ref, _) => MemoryDialog(
        title: 'Final Confirmation',
        dark: dark,
        isDestructive: true,
        message:
            'Please confirm you wish to remove your account. We will proceed to validate requests and sign you out.',
        actions: [
          MemoryDialogAction(
            label: 'Cancel',
            onPressed: () => Navigator.pop(ctx),
          ),
          MemoryDialogAction(
            label: 'Delete Permanently',
            isDestructive: true,
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
          ),
        ],
      ),
    ),
  );
}
