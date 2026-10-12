import 'package:flutter_test/flutter_test.dart';

import 'package:rent_go/src/app.dart';

void main() {
  testWidgets('app boots on the landing screen', (WidgetTester tester) async {
    await tester.pumpWidget(const RentGoApp());

    expect(find.text('RentGo Tunisia'), findsOneWidget);
    expect(find.text('Get started'), findsOneWidget);
  });
}
