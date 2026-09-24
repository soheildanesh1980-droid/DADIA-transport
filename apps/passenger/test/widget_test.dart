import 'package:flutter_test/flutter_test.dart';
import 'package:dadia_passenger/main.dart';

void main() {
  testWidgets('DADIA Passenger app starts', (tester) async {
    await tester.pumpWidget(const DadiaPassengerApp());

    expect(find.text('DADIA Passenger'), findsOneWidget);
    expect(find.text('ورود'), findsOneWidget);
  });
}
