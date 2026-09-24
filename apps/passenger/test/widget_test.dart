import 'package:flutter_test/flutter_test.dart';
import 'package:dadia_passenger/main.dart';

void main() {
  testWidgets('DADIA Passenger login and registration are available', (tester) async {
    await tester.pumpWidget(const DadiaPassengerApp());
    expect(find.text('DADIA Passenger'), findsOneWidget);
    expect(find.text('ورود'), findsOneWidget);
    expect(find.text('حساب ندارم؛ ثبت نام می‌کنم'), findsOneWidget);

    await tester.tap(find.text('حساب ندارم؛ ثبت نام می‌کنم'));
    await tester.pumpAndSettle();

    expect(find.text('ثبت نام مسافر'), findsOneWidget);
    expect(find.text('ثبت نام'), findsOneWidget);
    expect(find.text('کشور'), findsOneWidget);
  });
}
