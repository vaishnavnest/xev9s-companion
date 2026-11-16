import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xev9s_app/app/app.dart';

void main() {
  testWidgets('App renders dashboard placeholder smoke test',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: App(),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Dashboard Page (Placeholder)'), findsOneWidget);
  });
}
