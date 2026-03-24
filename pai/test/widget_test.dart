import 'package:flutter_test/flutter_test.dart';

import 'package:pai/main.dart';

void main() {
  testWidgets('app shell boots', (WidgetTester tester) async {
    await tester.pumpWidget(const PaiApp());
    await tester.pump();

    expect(find.byType(AppShell), findsOneWidget);
  });
}
