import 'package:flutter_test/flutter_test.dart';

import 'package:memory_app/main.dart';

void main() {
  testWidgets('Memory app boots', (WidgetTester tester) async {
    await tester.pumpWidget(const MemoryApp());

    expect(find.byType(MemoryPrototype), findsOneWidget);
  });
}
