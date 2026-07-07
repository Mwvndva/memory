import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:memory_app/main.dart';
import 'package:memory_app/features/auth/auth.dart';
import 'package:memory_app/core/theme.dart';

void main() {
  testWidgets('Memory app boots and shows loading view', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final sharedPreferences = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(sharedPreferences),
        ],
        child: const MemoryApp(),
      ),
    );

    await tester.pump();

    expect(find.byType(LoadingView), findsOneWidget);
  });
}
