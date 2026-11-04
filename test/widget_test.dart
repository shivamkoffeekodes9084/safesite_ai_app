import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:safesite_ai/main.dart';

void main() {
  testWidgets('SafeSiteApp boots with ProviderScope', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: SafeSiteApp(),
      ),
    );
    expect(find.byType(SafeSiteApp), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
  });
}
