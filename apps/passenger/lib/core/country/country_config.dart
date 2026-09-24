class CountryConfig {
  final String code;
  final String name;
  final String currencyCode;
  final String defaultLanguage;
  final String dialCode;
  final String flag;

  const CountryConfig({
    required this.code,
    required this.name,
    required this.currencyCode,
    required this.defaultLanguage,
    required this.dialCode,
    required this.flag,
  });
}

class CountryConfigs {
  static const supported = <CountryConfig>[
    CountryConfig(
      code: 'IR',
      name: 'Iran',
      currencyCode: 'IRR',
      defaultLanguage: 'fa',
      dialCode: '+98',
      flag: '🇮🇷',
    ),
    CountryConfig(
      code: 'AM',
      name: 'Armenia',
      currencyCode: 'AMD',
      defaultLanguage: 'hy',
      dialCode: '+374',
      flag: '🇦🇲',
    ),
    CountryConfig(
      code: 'AZ',
      name: 'Azerbaijan',
      currencyCode: 'AZN',
      defaultLanguage: 'az',
      dialCode: '+994',
      flag: '🇦🇿',
    ),
    CountryConfig(
      code: 'TR',
      name: 'Turkey',
      currencyCode: 'TRY',
      defaultLanguage: 'tr',
      dialCode: '+90',
      flag: '🇹🇷',
    ),
    CountryConfig(
      code: 'AE',
      name: 'United Arab Emirates',
      currencyCode: 'AED',
      defaultLanguage: 'ar',
      dialCode: '+971',
      flag: '🇦🇪',
    ),
    CountryConfig(
      code: 'IQ',
      name: 'Iraq',
      currencyCode: 'IQD',
      defaultLanguage: 'ar',
      dialCode: '+964',
      flag: '🇮🇶',
    ),
  ];
}
