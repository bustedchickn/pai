import 'package:flutter_test/flutter_test.dart';

import 'package:pai/main.dart';

void main() {
  testWidgets('app shell renders dashboard content', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const PaiApp());

    expect(find.text('pai'), findsWidgets);
    expect(find.text('workspace'), findsOneWidget);
    expect(find.text('Projects'), findsOneWidget);
  });
}
