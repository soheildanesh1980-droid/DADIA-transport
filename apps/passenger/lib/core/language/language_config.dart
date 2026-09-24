class AppLanguage {
  final String code;
  final String name;
  final String flag;

  const AppLanguage({
    required this.code,
    required this.name,
    required this.flag,
  });
}

const supportedLanguages = <AppLanguage>[
  AppLanguage(code: 'FA', name: 'فارسی', flag: '🇮🇷'),
  AppLanguage(code: 'EN', name: 'English', flag: '🇬🇧'),
  AppLanguage(code: 'RU', name: 'Русский', flag: '🇷🇺'),
  AppLanguage(code: 'HY', name: 'Հայերեն', flag: '🇦🇲'),
  AppLanguage(code: 'AZ', name: 'Azərbaycan dili', flag: '🇦🇿'),
  AppLanguage(code: 'TR', name: 'Türkçe', flag: '🇹🇷'),
  AppLanguage(code: 'AR', name: 'العربية', flag: '🇦🇪'),
];
