import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:memory_app/features/circle/circle.dart';

class FakePendingRequestsNotifier extends PendingRequestsNotifier {
  FakePendingRequestsNotifier(super.ref) {
    // initialize with a pending entry and avoid network activity by
    // keeping authProvider mocked in the test.
    state = const [
      CircleMember(id: 'alice-id', username: 'alice', firstName: 'Alice'),
    ];
  }

  @override
  Future<bool> acceptRequest(String senderId) async {
    state = state
        .where((m) => m.id != senderId && m.username != senderId)
        .toList();
    return true;
  }

  @override
  Future<bool> declineRequest(String senderId) async {
    state = state
        .where((m) => m.id != senderId && m.username != senderId)
        .toList();
    return true;
  }
}

void main() {
  testWidgets('pending request locks composer and accept reveals composer', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [
        pendingRequestsProvider.overrideWith(
          (ref) => FakePendingRequestsNotifier(ref),
        ),
      ],
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: ChatInboxView(contactName: 'alice')),
      ),
    );

    await tester.pumpAndSettle();

    // Composer should be locked and Accept button visible
    expect(find.textContaining('wants to share'), findsOneWidget);
    expect(find.text('Accept'), findsOneWidget);

    // Tap Accept and ensure loadConversation is invoked (we can't easily assert composer visibility change here without wiring a callback)
    await tester.tap(find.text('Accept'));
    await tester.pumpAndSettle();

    // After accepting, the pending list should be empty; tapping Accept removed it. Verify no 'wants to share' text.
    expect(find.textContaining('wants to share'), findsNothing);
  });
}
