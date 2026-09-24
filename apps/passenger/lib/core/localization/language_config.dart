class LanguageConfig {
  final String code;
  final String name;
  final bool rtl;

  const LanguageConfig(this.code, this.name, this.rtl);
}

class Languages {
  static const fa = LanguageConfig('fa', 'فارسی', true);
  static const en = LanguageConfig('en', 'English', false);
  static const tr = LanguageConfig('tr', 'Türkçe', false);
  static const az = LanguageConfig('az', 'Azərbaycan', false);
  static const ar = LanguageConfig('ar', 'العربية', true);
  static const hy = LanguageConfig('hy', 'Հայերեն', false);

  static const all = <LanguageConfig>[fa, en, tr, az, ar, hy];
}
