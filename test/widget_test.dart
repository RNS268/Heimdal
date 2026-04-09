import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:heimdall/app.dart';

void main() {
  testWidgets('HEIMDALL app smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: HeimdallApp(),
      ),
    );

    expect(find.text('HEIMDALL'), findsWidgets);
  });
}
