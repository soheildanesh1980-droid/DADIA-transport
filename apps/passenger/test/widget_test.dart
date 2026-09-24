import 'package:flutter_test/flutter_test.dart';
import 'package:dadia_passenger/main.dart';
import 'package:dadia_passenger/core/language/app_localization.dart';


void main() {
  testWidgets('DADIA Passenger login and registration are available',
      (WidgetTester tester) async {
    languageController.setLanguage('FA');
    await tester.pumpWidget(const DadiaPassengerApp());

    expect(find.text('ورود به دادیا'), findsOneWidget);
    expect(find.text('حساب ندارم؛ ثبت نام می‌کنم'), findsOneWidget);

    await tester.tap(find.text('حساب ندارم؛ ثبت نام می‌کنم'));
    await tester.pumpAndSettle();

    expect(find.text('ثبت نام مسافر'), findsOneWidget);
    expect(find.text('دریافت کد تایید'), findsOneWidget);
  });
}
