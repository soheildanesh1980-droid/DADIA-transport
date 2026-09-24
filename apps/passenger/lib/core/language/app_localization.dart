import 'package:flutter/material.dart';

class AppLocalization {
  final String code;

  const AppLocalization(this.code);

  static const supported = <String>[
    'FA',
    'EN',
    'RU',
    'HY',
    'AZ',
    'TR',
    'AR',
  ];

  static String text(String code, String key) {
    const translations = <String, Map<String, String>>{
      'FA': {
        'login': 'ورود',
        'login_title': 'ورود به دادیا',
        'register': 'ثبت نام مسافر',
        'register_account': 'حساب ندارم؛ ثبت نام می‌کنم',
        'phone': 'شماره تلفن',
        'country': 'کشور',
        'get_code': 'دریافت کد تایید',
        'loading': 'در حال ورود...',
        'language': 'زبان',
      },
      'EN': {
        'login': 'Login',
        'login_title': 'Login to DADIA',
        'register': 'Passenger Registration',
        'register_account': 'I do not have an account; Register',
        'phone': 'Phone number',
        'country': 'Country',
        'get_code': 'Get verification code',
        'loading': 'Signing in...',
        'language': 'Language',
      },
      'RU': {
        'login': 'Войти',
        'login_title': 'Вход в DADIA',
        'register': 'Регистрация пассажира',
        'register_account': 'У меня нет аккаунта; Регистрация',
        'phone': 'Номер телефона',
        'country': 'Страна',
        'get_code': 'Получить код подтверждения',
        'loading': 'Выполняется вход...',
        'language': 'Язык',
      },
      'HY': {
        'login': 'Մուտք',
        'login_title': 'Մուտք DADIA',
        'register': 'Ուղևորի գրանցում',
        'register_account': 'Ես հաշիվ չունեմ; Գրանցվել',
        'phone': 'Հեռախոսահամար',
        'country': 'Երկիր',
        'get_code': 'Ստանալ հաստատման կոդը',
        'loading': 'Մուտք...',
        'language': 'Լեզու',
      },
      'AZ': {
        'login': 'Giriş',
        'login_title': 'DADIA-ya giriş',
        'register': 'Sərnişin qeydiyyatı',
        'register_account': 'Hesabım yoxdur; Qeydiyyatdan keç',
        'phone': 'Telefon nömrəsi',
        'country': 'Ölkə',
        'get_code': 'Təsdiq kodunu al',
        'loading': 'Giriş edilir...',
        'language': 'Dil',
      },
      'TR': {
        'login': 'Giriş',
        'login_title': 'DADIA giriş',
        'register': 'Yolcu kaydı',
        'register_account': 'Hesabım yok; Kayıt ol',
        'phone': 'Telefon numarası',
        'country': 'Ülke',
        'get_code': 'Doğrulama kodu al',
        'loading': 'Giriş yapılıyor...',
        'language': 'Dil',
      },
      'AR': {
        'login': 'تسجيل الدخول',
        'login_title': 'تسجيل الدخول إلى داديا',
        'register': 'تسجيل الراكب',
        'register_account': 'ليس لدي حساب؛ تسجيل',
        'phone': 'رقم الهاتف',
        'country': 'الدولة',
        'get_code': 'الحصول على رمز التحقق',
        'loading': 'جار تسجيل الدخول...',
        'language': 'اللغة',
      },
    };

    return translations[code]?[key] ??
        translations['EN']?[key] ??
        key;
  }
}

class LanguageController extends ChangeNotifier {
  String _code = 'FA';

  String get code => _code;

  void setLanguage(String code) {
    if (!AppLocalization.supported.contains(code)) return;
    if (_code == code) return;

    _code = code;
    notifyListeners();
  }
}

final languageController = LanguageController();
