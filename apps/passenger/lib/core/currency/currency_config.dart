class CurrencyConfig {
  final String code;
  final String symbol;

  const CurrencyConfig(this.code, this.symbol);
}

class Currencies {
  static const irr = CurrencyConfig('IRR', '﷼');
  static const usd = CurrencyConfig('USD', '\$');
  static const eur = CurrencyConfig('EUR', '€');
  static const azn = CurrencyConfig('AZN', '₼');
  static const tryCurrency = CurrencyConfig('TRY', '₺');
  static const amd = CurrencyConfig('AMD', '֏');
  static const aed = CurrencyConfig('AED', 'د.إ');
  static const iqd = CurrencyConfig('IQD', 'ع.د');
  static const gbp = CurrencyConfig('GBP', '£');

  static const all = <CurrencyConfig>[
    irr, usd, eur, azn, tryCurrency, amd, aed, iqd, gbp,
  ];
}
