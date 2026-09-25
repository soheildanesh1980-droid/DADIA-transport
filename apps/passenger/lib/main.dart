import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/auth/auth_service.dart';
import 'core/config/app_config.dart';
import 'core/country/country_config.dart';
import 'core/language/app_localization.dart';
import 'core/language/language_config.dart';
import 'core/network/api_client.dart';
import 'core/project/project_stages_page.dart';

void main() {
  runApp(const DadiaPassengerApp());
}

final api = ApiClient();
final auth = AuthService(api);

String uiText(
  String code,
  String key,
) {
  const values = <String, Map<String, String>>{
    'FA': {
      'login_title': 'ورود به دادیا',
      'register_title': 'ثبت نام مسافر',
      'phone': 'شماره تلفن',
      'country': 'کشور',
      'continue': 'دریافت کد تایید',
      'login': 'ورود',
      'register_account': 'حساب ندارم؛ ثبت نام میکنم',
      'have_account': 'حساب دارم؛ ورود',
      'otp_title': 'کد تایید',
      'otp_hint': 'کد ۶ رقمی پیامک شده را وارد کنید',
      'verify': 'تایید کد',
      'resend': 'ارسال مجدد کد',
      'change_phone': 'تغییر شماره',
      'sending': 'در حال ارسال...',
      'verifying': 'در حال بررسی...',
      'invalid_phone': 'شماره تلفن معتبر وارد کنید',
      'otp_sent': 'کد تایید ارسال شد',
    },
    'EN': {
      'login_title': 'Sign in to DADIA',
      'register_title': 'Passenger registration',
      'phone': 'Phone number',
      'country': 'Country',
      'continue': 'Send verification code',
      'login': 'Sign in',
      'register_account': 'I do not have an account',
      'have_account': 'I already have an account',
      'otp_title': 'Verification code',
      'otp_hint': 'Enter the 6-digit code sent to you',
      'verify': 'Verify code',
      'resend': 'Resend code',
      'change_phone': 'Change number',
      'sending': 'Sending...',
      'verifying': 'Verifying...',
      'invalid_phone': 'Enter a valid phone number',
      'otp_sent': 'Verification code sent',
    },
    'RU': {
      'login_title': 'Вход в DADIA',
      'register_title': 'Регистрация пассажира',
      'phone': 'Номер телефона',
      'country': 'Страна',
      'continue': 'Получить код',
      'login': 'Войти',
      'register_account': 'У меня нет аккаунта',
      'have_account': 'У меня уже есть аккаунт',
      'otp_title': 'Код подтверждения',
      'otp_hint': 'Введите 6-значный код',
      'verify': 'Подтвердить',
      'resend': 'Отправить код снова',
      'change_phone': 'Изменить номер',
      'sending': 'Отправка...',
      'verifying': 'Проверка...',
      'invalid_phone': 'Введите корректный номер',
      'otp_sent': 'Код отправлен',
    },
    'HY': {
      'login_title': 'Մուտք DADIA',
      'register_title': 'Ուղեւորի գրանցում',
      'phone': 'Հեռախոսահամար',
      'country': 'Երկիր',
      'continue': 'Ստանալ հաստատման կոդ',
      'login': 'Մուտք',
      'register_account': 'Ես հաշիվ չունեմ',
      'have_account': 'Ես արդեն հաշիվ ունեմ',
      'otp_title': 'Հաստատման կոդ',
      'otp_hint': 'Մուտքագրեք 6 նիշանոց կոդը',
      'verify': 'Հաստատել',
      'resend': 'Ուղարկել կրկին',
      'change_phone': 'Փոխել համարը',
      'sending': 'Ուղարկվում է...',
      'verifying': 'Ստուգվում է...',
      'invalid_phone': 'Մուտքագրեք ճիշտ համարը',
      'otp_sent': 'Կոդը ուղարկվեց',
    },
    'AZ': {
      'login_title': 'DADIA-ya giriş',
      'register_title': 'Sərnişin qeydiyyatı',
      'phone': 'Telefon nömrəsi',
      'country': 'Ölkə',
      'continue': 'Təsdiq kodu göndər',
      'login': 'Daxil ol',
      'register_account': 'Hesabım yoxdur',
      'have_account': 'Hesabım var',
      'otp_title': 'Təsdiq kodu',
      'otp_hint': '6 rəqəmli kodu daxil edin',
      'verify': 'Kodu təsdiqlə',
      'resend': 'Kodu yenidən göndər',
      'change_phone': 'Nömrəni dəyiş',
      'sending': 'Göndərilir...',
      'verifying': 'Yoxlanılır...',
      'invalid_phone': 'Düzgün nömrə daxil edin',
      'otp_sent': 'Təsdiq kodu göndərildi',
    },
    'TR': {
      'login_title': 'DADIA giriş',
      'register_title': 'Yolcu kaydı',
      'phone': 'Telefon numarası',
      'country': 'Ülke',
      'continue': 'Doğrulama kodu gönder',
      'login': 'Giriş',
      'register_account': 'Hesabım yok',
      'have_account': 'Hesabım var',
      'otp_title': 'Doğrulama kodu',
      'otp_hint': '6 haneli kodu girin',
      'verify': 'Kodu doğrula',
      'resend': 'Kodu tekrar gönder',
      'change_phone': 'Numarayı değiştir',
      'sending': 'Gönderiliyor...',
      'verifying': 'Kontrol ediliyor...',
      'invalid_phone': 'Geçerli bir numara girin',
      'otp_sent': 'Doğrulama kodu gönderildi',
    },
    'AR': {
      'login_title': 'تسجيل الدخول الى DADIA',
      'register_title': 'تسجيل الراكب',
      'phone': 'رقم الهاتف',
      'country': 'الدولة',
      'continue': 'ارسال رمز التحقق',
      'login': 'دخول',
      'register_account': 'ليس لدي حساب',
      'have_account': 'لدي حساب',
      'otp_title': 'رمز التحقق',
      'otp_hint': 'ادخل الرمز المكون من 6 ارقام',
      'verify': 'تأكيد الرمز',
      'resend': 'اعادة ارسال الرمز',
      'change_phone': 'تغيير الرقم',
      'sending': 'جار الارسال...',
      'verifying': 'جار التحقق...',
      'invalid_phone': 'ادخل رقما صحيحا',
      'otp_sent': 'تم ارسال رمز التحقق',
    },
  };

  return values[code]?[key] ??
      values['EN']![key] ??
      key;
}

String cleanError(Object e) {
  return e.toString().replaceFirst(
    'Exception: ',
    '',
  );
}

String buildFullPhone(
  CountryConfig country,
  String raw,
) {
  var value = raw.trim();

  value = value.replaceAll(
    RegExp(r'[\s()-]'),
    '',
  );

  if (value.startsWith('00')) {
    value = '+${value.substring(2)}';
  }

  if (value.startsWith('+')) {
    if (!value.startsWith(country.dialCode)) {
      throw Exception(
        '${country.name}: ${country.dialCode}',
      );
    }

    return value;
  }

  value = value.replaceFirst(
    RegExp(r'^0+'),
    '',
  );

  if (value.length < 6) {
    throw Exception('INVALID_PHONE');
  }

  return '${country.dialCode}$value';
}

mixin LanguageAwareState<T extends StatefulWidget> on State<T> {
  void _languageChanged() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    languageController.addListener(_languageChanged);
  }

  @override
  void dispose() {
    languageController.removeListener(_languageChanged);
    super.dispose();
  }
}

class LanguageSelector extends StatelessWidget {
  const LanguageSelector({super.key});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<AppLanguage>(
      tooltip: uiText(languageController.code, 'language'),
      icon: const Icon(Icons.language),
      onSelected: (language) {
        languageController.setLanguage(
          language.code,
        );
      },
      itemBuilder: (context) {
        return supportedLanguages.map(
          (language) {
            return PopupMenuItem<AppLanguage>(
              value: language,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    language.flag,
                    style: const TextStyle(
                      fontSize: 22,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '${language.code} - ${language.name}',
                    textDirection:
                        TextDirection.ltr,
                  ),
                ],
              ),
            );
          },
        ).toList();
      },
    );
  }
}

class DadiaPassengerApp
    extends StatelessWidget {
  const DadiaPassengerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: languageController,
      builder: (context, _) {
        final code =
            languageController.code;
        final isRtl =
            code == 'FA' || code == 'AR';

        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'DADIA Passenger',
          theme: ThemeData(
            useMaterial3: true,
            colorSchemeSeed: Colors.indigo,
          ),
          locale: Locale(
            code.toLowerCase(),
          ),
          supportedLocales:
              AppLocalization.supported
                  .map(
                    (e) => Locale(
                      e.toLowerCase(),
                    ),
                  )
                  .toList(),
          localizationsDelegates:
              GlobalMaterialLocalizations
                  .delegates,
          builder: (context, child) {
            return Directionality(
              textDirection: isRtl
                  ? TextDirection.rtl
                  : TextDirection.ltr,
              child:
                  child ??
                      const SizedBox.shrink(),
            );
          },
          home: const LoginPage(),
        );
      },
    );
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() =>
      _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with LanguageAwareState<LoginPage> {
  final phone =
      TextEditingController();

  CountryConfig country =
      CountryConfigs.supported.first;

  bool loading = false;
  String? error;

  Future<void> login() async {
    setState(() {
      loading = true;
      error = null;
    });

    try {
      final fullPhone =
          buildFullPhone(
        country,
        phone.text,
      );

      await auth.requestLoginOtp(
        fullPhone,
        locale:
            languageController.code
                .toLowerCase(),
      );

      if (!mounted) return;

      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => OtpPage(
            phone: fullPhone,
            mode: OtpMode.login,
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(
          () => error =
              _mapUiError(e),
        );
      }
    } finally {
      if (mounted) {
        setState(
          () => loading = false,
        );
      }
    }
  }

  String _mapUiError(Object e) {
    final value =
        cleanError(e);

    if (value == 'INVALID_PHONE') {
      return uiText(
        languageController.code,
        'invalid_phone',
      );
    }

    return value;
  }

  @override
  void dispose() {
    phone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: uiText(
        languageController.code,
        'login_title',
      ),
      child: Column(
        children: [
          countryField(
            value: country,
            enabled: !loading,
            onChanged: (value) {
              if (value != null) {
                setState(
                  () => country = value,
                );
              }
            },
          ),
          const SizedBox(height: 14),
          phoneField(
            phone,
            hint: country.dialCode,
          ),
          if (error != null)
            errorText(error!),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed:
                  loading ? null : login,
              child: Text(
                loading
                    ? uiText(
                        languageController.code,
                        'sending',
                      )
                    : uiText(
                        languageController.code,
                        'continue',
                      ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          TextButton(
            onPressed: loading
                ? null
                : () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            const RegisterPage(),
                      ),
                    );
                  },
            child: Text(
              uiText(
                languageController.code,
                'register_account',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class RegisterPage
    extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() =>
      _RegisterPageState();
}

class _RegisterPageState
    extends State<RegisterPage>
    with LanguageAwareState<RegisterPage> {
  final phone =
      TextEditingController();

  CountryConfig country =
      CountryConfigs.supported.first;

  bool loading = false;
  String? error;

  Future<void> register() async {
    setState(() {
      loading = true;
      error = null;
    });

    try {
      final fullPhone =
          buildFullPhone(
        country,
        phone.text,
      );

      await auth.requestRegisterOtp(
        fullPhone,
        locale:
            languageController.code
                .toLowerCase(),
      );

      if (!mounted) return;

      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => OtpPage(
            phone: fullPhone,
            mode: OtpMode.registration,
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(
          () => error =
              cleanError(e),
        );
      }
    } finally {
      if (mounted) {
        setState(
          () => loading = false,
        );
      }
    }
  }

  @override
  void dispose() {
    phone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: uiText(
        languageController.code,
        'register_title',
      ),
      back: true,
      child: Column(
        children: [
          countryField(
            value: country,
            enabled: !loading,
            onChanged: (value) {
              if (value != null) {
                setState(
                  () => country = value,
                );
              }
            },
          ),
          const SizedBox(height: 14),
          phoneField(
            phone,
            hint: country.dialCode,
          ),
          if (error != null)
            errorText(error!),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed:
                  loading ? null : register,
              child: Text(
                loading
                    ? uiText(
                        languageController.code,
                        'sending',
                      )
                    : uiText(
                        languageController.code,
                        'continue',
                      ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          TextButton(
            onPressed: loading
                ? null
                : () =>
                    Navigator.of(context).pop(),
            child: Text(
              uiText(
                languageController.code,
                'have_account',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

enum OtpMode {
  login,
  registration,
}

class OtpPage extends StatefulWidget {
  final String phone;
  final OtpMode mode;

  const OtpPage({
    super.key,
    required this.phone,
    required this.mode,
  });

  @override
  State<OtpPage> createState() =>
      _OtpPageState();
}

class _OtpPageState
    extends State<OtpPage>
    with LanguageAwareState<OtpPage> {
  final code =
      TextEditingController();

  Timer? timer;
  int seconds = 60;
  bool loading = false;
  String? error;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    timer?.cancel();

    setState(() {
      seconds = 60;
    });

    timer =
        Timer.periodic(
      const Duration(seconds: 1),
      (_) {
        if (!mounted) return;

        if (seconds <= 1) {
          timer?.cancel();
          setState(
            () => seconds = 0,
          );
        } else {
          setState(
            () => seconds--,
          );
        }
      },
    );
  }

  Future<void> resend() async {
    if (seconds > 0 || loading) {
      return;
    }

    setState(() {
      loading = true;
      error = null;
    });

    try {
      final locale =
          languageController.code
              .toLowerCase();

      if (widget.mode ==
          OtpMode.login) {
        await auth.requestLoginOtp(
          widget.phone,
          locale: locale,
        );
      } else {
        await auth.requestRegisterOtp(
          widget.phone,
          locale: locale,
        );
      }

      _startTimer();
    } catch (e) {
      if (mounted) {
        setState(
          () =>
              error = cleanError(e),
        );
      }
    } finally {
      if (mounted) {
        setState(
          () => loading = false,
        );
      }
    }
  }

  Future<void> verify() async {
    final value =
        code.text.trim();

    if (!RegExp(r'^\d{6}$')
        .hasMatch(value)) {
      setState(
        () => error = uiText(
          languageController.code,
          'otp_hint',
        ),
      );
      return;
    }

    setState(() {
      loading = true;
      error = null;
    });

    try {
      if (widget.mode ==
          OtpMode.login) {
        await auth.verifyLoginOtp(
          widget.phone,
          value,
        );
      } else {
        final token =
            await auth.verifyRegisterOtp(
          widget.phone,
          value,
        );

        await auth.completeRegister(
          token,
        );
      }

      if (!mounted) return;

      Navigator.of(context)
          .pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) =>
              const HomePage(),
        ),
        (_) => false,
      );
    } catch (e) {
      if (mounted) {
        setState(
          () => error =
              cleanError(e),
        );
      }
    } finally {
      if (mounted) {
        setState(
          () => loading = false,
        );
      }
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    code.dispose();
    super.dispose();
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    return AuthScaffold(
      title: uiText(
        languageController.code,
        'otp_title',
      ),
      back: true,
      child: Column(
        children: [
          Text(
            '${uiText(languageController.code, 'otp_sent')}\n${widget.phone}',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          TextField(
            controller: code,
            keyboardType:
                TextInputType.number,
            maxLength: 6,
            textAlign: TextAlign.center,
            style:
                const TextStyle(
              fontSize: 28,
              letterSpacing: 8,
              fontWeight:
                  FontWeight.w700,
            ),
            decoration:
                InputDecoration(
              labelText:
                  uiText(
                languageController.code,
                'otp_title',
              ),
              hintText:
                  uiText(
                languageController.code,
                'otp_hint',
              ),
              border:
                  const OutlineInputBorder(),
              counterText: '',
            ),
          ),
          if (error != null)
            errorText(error!),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed:
                  loading ? null : verify,
              child: Text(
                loading
                    ? uiText(
                        languageController.code,
                        'verifying',
                      )
                    : uiText(
                        languageController.code,
                        'verify',
                      ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed:
                seconds == 0 &&
                        !loading
                    ? resend
                    : null,
            child: Text(
              seconds == 0
                  ? uiText(
                      languageController.code,
                      'resend',
                    )
                  : '${uiText(languageController.code, 'resend')} ($seconds)',
            ),
          ),
        ],
      ),
    );
  }
}

class AuthScaffold
    extends StatelessWidget {
  final String title;
  final Widget child;
  final bool back;

  const AuthScaffold({
    super.key,
    required this.title,
    required this.child,
    this.back = false,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        automaticallyImplyLeading: back,
        actions: const [
          LanguageSelector(),
        ],
      ),
      body: Center(
        child:
            SingleChildScrollView(
          padding:
              const EdgeInsets.all(24),
          child: Column(
            children: [
              const Icon(
                Icons.local_taxi,
                size: 72,
              ),
              const SizedBox(
                height: 16,
              ),
              const Text(
                'DADIA Passenger',
                style:
                    TextStyle(
                  fontSize: 25,
                  fontWeight:
                      FontWeight.bold,
                ),
              ),
              const SizedBox(
                height: 24,
              ),
              child,
              const SizedBox(
                height: 18,
              ),
              Text(
                'Backend: ${AppConfig.apiBaseUrl}',
                textAlign:
                    TextAlign.center,
                style:
                    Theme.of(context)
                        .textTheme
                        .bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class HomePage
    extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() =>
      _HomePageState();
}

class _HomePageState
    extends State<HomePage> {
  String result =
      'برای مشاهده اطلاعات یکی از گزینه‌ها را انتخاب کنید.';
  bool loading = false;

  Future<void> run(
    Future<Map<String, dynamic>>
        Function()
            action,
  ) async {
    setState(
      () => loading = true,
    );

    try {
      final data = await action();

      setState(
        () => result =
            const JsonEncoder
                .withIndent('  ')
                .convert(data),
      );
    } catch (e) {
      setState(
        () => result =
            cleanError(e),
      );
    } finally {
      setState(
        () => loading = false,
      );
    }
  }

  void logout() {
    auth.logout();

    Navigator.of(context)
        .pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) =>
            const LoginPage(),
      ),
      (_) => false,
    );
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      appBar: AppBar(
        title:
            const Text('دادیا | مسافر'),
        actions: [
          const LanguageSelector(),
          IconButton(
            onPressed: logout,
            icon:
                const Icon(Icons.logout),
          ),
        ],
      ),
      body: ListView(
        padding:
            const EdgeInsets.all(16),
        children: [
          ListTile(
            leading:
                const Icon(
              Icons.developer_mode,
            ),
            title: const Text(
              'مراحل توسعه DADIA',
            ),
            subtitle:
                const Text(
              'مشاهده مراحل تکمیل شده ۱ تا ۳۸',
            ),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) =>
                      const ProjectStagesPage(),
                ),
              );
            },
          ),
          const Card(
            child: Padding(
              padding:
                  EdgeInsets.all(18),
              child: Text(
                'به اپلیکیشن Passenger دادیا خوش آمدید.',
                style:
                    TextStyle(
                  fontSize: 18,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: loading
                ? null
                : () => run(api.me),
            icon:
                const Icon(Icons.person),
            label:
                const Text('پروفایل من'),
          ),
          FilledButton.icon(
            onPressed: loading
                ? null
                : () =>
                    run(api.trips),
            icon:
                const Icon(
              Icons.history,
            ),
            label:
                const Text('سفرهای من'),
          ),
          FilledButton.icon(
            onPressed: loading
                ? null
                : () =>
                    run(api.activeTrip),
            icon:
                const Icon(
              Icons.navigation,
            ),
            label:
                const Text('سفر فعال'),
          ),
          const SizedBox(height: 18),
          if (loading)
            const LinearProgressIndicator(),
          const SizedBox(height: 12),
          Card(
            child:
                Padding(
              padding:
                  const EdgeInsets.all(16),
              child:
                  SelectableText(result),
            ),
          ),
        ],
      ),
    );
  }
}

Widget countryField({
  required CountryConfig value,
  required bool enabled,
  required ValueChanged<CountryConfig?>
      onChanged,
}) {
  return DropdownButtonFormField<
      CountryConfig>(
    initialValue: value,
    decoration:
        const InputDecoration(
      labelText: uiText(languageController.code, 'country'),
      border:
          OutlineInputBorder(),
    ),
    isExpanded: true,
    items:
        CountryConfigs.supported.map(
      (country) {
        return DropdownMenuItem<
            CountryConfig>(
          value: country,
          child: Text(
            '${country.flag}  ${country.code}  ${country.dialCode}  ${country.name}',
            overflow:
                TextOverflow.ellipsis,
          ),
        );
      },
    ).toList(),
    onChanged:
        enabled ? onChanged : null,
  );
}

Widget phoneField(
  TextEditingController controller, {
  String hint = '',
}) {
  return TextField(
    controller: controller,
    keyboardType:
        TextInputType.phone,
    decoration:
        InputDecoration(
      labelText:
          uiText(
        languageController.code,
        'phone',
      ),
      hintText: hint,
      border:
          const OutlineInputBorder(),
    ),
  );
}

Widget errorText(
  String error,
) {
  return Padding(
    padding:
        const EdgeInsets.only(
      top: 12,
    ),
    child: Text(
      error,
      style:
          const TextStyle(
        color: Colors.red,
      ),
    ),
  );
}
