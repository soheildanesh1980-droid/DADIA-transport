class AppConfig {
  static const appName = 'DADIA Passenger';
  static const apiBaseUrl = String.fromEnvironment(
    'DADIA_API_BASE_URL',
    defaultValue: 'http://127.0.0.1:3000',
  );

  static const defaultCountryCode = String.fromEnvironment(
    'DADIA_COUNTRY',
    defaultValue: 'IR',
  );

  static const defaultLanguageCode = String.fromEnvironment(
    'DADIA_LANGUAGE',
    defaultValue: 'fa',
  );

  static const defaultCurrencyCode = String.fromEnvironment(
    'DADIA_CURRENCY',
    defaultValue: 'IRR',
  );
}
