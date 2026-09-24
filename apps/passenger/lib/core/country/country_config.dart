class CountryConfig {
  final String code;
  final String name;
  final String currencyCode;
  final String defaultLanguage;

  const CountryConfig({
    required this.code,
    required this.name,
    required this.currencyCode,
    required this.defaultLanguage,
  });
}

class CountryConfigs {
  static const supported = <CountryConfig>[
    CountryConfig(code: 'IR', name: 'Iran', currencyCode: 'IRR', defaultLanguage: 'fa'),
    CountryConfig(code: 'TR', name: 'Turkey', currencyCode: 'TRY', defaultLanguage: 'tr'),
    CountryConfig(code: 'AZ', name: 'Azerbaijan', currencyCode: 'AZN', defaultLanguage: 'az'),
    CountryConfig(code: 'AM', name: 'Armenia', currencyCode: 'AMD', defaultLanguage: 'hy'),
    CountryConfig(code: 'AE', name: 'United Arab Emirates', currencyCode: 'AED', defaultLanguage: 'ar'),
    CountryConfig(code: 'IQ', name: 'Iraq', currencyCode: 'IQD', defaultLanguage: 'ar'),
  ];
}
