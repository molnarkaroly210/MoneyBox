import 'package:flutter_test/flutter_test.dart';
import 'package:moneybox/main.dart';

void main() {
  testWidgets('MoneyBox smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const MoneyBoxApp());
    expect(find.text('MoneyBox'), findsWidgets);
  });
}
