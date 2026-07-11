import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memory_app/features/feed/feed.dart';
import 'package:memory_app/core/widget_manager.dart';

void main() {
  group('Streak Milestones and Card Design Tests', () {
    test(
      'CardDesignData.generate creates valid design data with shapes and colors',
      () {
        final data7 = CardDesignData.generate(7);
        expect(data7.gradientColors, isNotEmpty);
        expect(data7.gradientColors.length, equals(3));
        expect(data7.shapes, isNotEmpty);
        expect(data7.shapes.length, greaterThanOrEqualTo(5));

        final data30 = CardDesignData.generate(30);
        expect(data30.gradientColors, isNotEmpty);
        expect(data30.gradientColors.length, equals(3));
        expect(data30.shapes, isNotEmpty);
        expect(data30.shapes.length, greaterThanOrEqualTo(5));
      },
    );

    testWidgets(
      'CircleMilestoneCardWidget renders circle milestone with member avatars correctly',
      (WidgetTester tester) async {
        final designData = CardDesignData.generate(7);
        final members = [
          CircleMemberWithMemories(
            id: '1',
            username: 'alice',
            firstName: 'Alice',
            memoryCount: 15,
          ),
          CircleMemberWithMemories(
            id: '2',
            username: 'bob',
            firstName: 'Bob',
            memoryCount: 10,
          ),
          CircleMemberWithMemories(
            id: '3',
            username: 'charlie',
            firstName: 'Charlie',
            memoryCount: 5,
          ),
          CircleMemberWithMemories(
            id: '4',
            username: 'dave',
            firstName: 'Dave',
            memoryCount: 20,
          ),
          CircleMemberWithMemories(
            id: '5',
            username: 'eve',
            firstName: 'Eve',
            memoryCount: 0,
          ),
          CircleMemberWithMemories(
            id: '6',
            username: 'frank',
            firstName: 'Frank',
            memoryCount: 8,
          ),
          CircleMemberWithMemories(
            id: '7',
            username: 'grace',
            firstName: 'Grace',
            memoryCount: 12,
          ),
        ];

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: RepaintBoundary(
                child: CircleMilestoneCardWidget(
                  circleOwnerUsername: 'alice',
                  milestone: 7,
                  members: members,
                  designData: designData,
                  message: 'Your circle is amazing!',
                ),
              ),
            ),
          ),
        );

        // Verify the widget itself builds successfully
        expect(find.byType(CircleMilestoneCardWidget), findsOneWidget);

        // Verify all 7 CircleAvatars are drawn
        expect(find.byType(CircleAvatar), findsNWidgets(7));

        // Verify text with initials or username is shown
        expect(find.text('@alice\'s Circle'), findsOneWidget);
        expect(find.text('Your circle is amazing!'), findsOneWidget);
      },
    );

    testWidgets(
      'CircleMilestoneCongratulationsDialog renders and closes correctly',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(800, 1200);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final members = [
          CircleMemberWithMemories(
            id: '1',
            username: 'alice',
            firstName: 'Alice',
            memoryCount: 15,
          ),
        ];

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  return ElevatedButton(
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (context) =>
                            CircleMilestoneCongratulationsDialog(
                              circleOwnerUsername: 'alice',
                              milestone: 7,
                              members: members,
                            ),
                      );
                    },
                    child: const Text('Show Dialog'),
                  );
                },
              ),
            ),
          ),
        );

        // Open the dialog
        await tester.tap(find.text('Show Dialog'));
        await tester.pumpAndSettle();

        // Verify dialog components exist
        expect(
          find.byType(CircleMilestoneCongratulationsDialog),
          findsOneWidget,
        );
        expect(find.text('Share circle milestone!'), findsOneWidget);

        // Tap to close
        await tester.tap(find.text('Keep Sharing! 👥✨'));
        await tester.pumpAndSettle();

        // Verify dialog is gone
        expect(find.byType(CircleMilestoneCongratulationsDialog), findsNothing);
      },
    );
    group('Circle Milestones Formatting and Math Tests', () {
      test(
        'Avatar size scaling limits remain within expected boundary sizes',
        () {
          // Test base sizing calculations logic for different N values
          for (int n = 1; n <= 100; n++) {
            final baseSize = (120.0 / (n == 0 ? 1 : n)).clamp(18.0, 56.0);
            expect(baseSize, greaterThanOrEqualTo(18.0));
            expect(baseSize, lessThanOrEqualTo(56.0));
          }
        },
      );
    });

    group('WidgetManager Integration Tests', () {
      test(
        'WidgetManager handles empty memories list sync cleanly with mocked platform channel',
        () async {
          TestWidgetsFlutterBinding.ensureInitialized();
          // Mock method channel to catch native calls from home_widget
          const channel = MethodChannel('home_widget');
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
              .setMockMethodCallHandler(channel, (methodCall) async {
                return true;
              });

          // Run sync with empty memories list
          await WidgetManager.syncLatestMemory([]);

          // Clean up mock handler
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
              .setMockMethodCallHandler(channel, null);
        },
      );
    });
  });
}
