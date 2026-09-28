// Language definitions

class AppLanguage {
  final String code;
  final String name;
  final String nativeName;

  const AppLanguage({
    required this.code,
    required this.name,
    required this.nativeName,
  });
}

const List<AppLanguage> supportedLanguages = [
  AppLanguage(code: 'es', name: 'Spanish', nativeName: 'Español'),
  AppLanguage(code: 'en', name: 'English', nativeName: 'English'),
];

// Get language list
List<Map<String, String>> getLanguageList() {
  return supportedLanguages
      .map((lang) => {'code': lang.code, 'name': lang.nativeName})
      .toList();
}

// Get language by code
AppLanguage? getLanguageByCode(String code) {
  return supportedLanguages.firstWhere(
    (lang) => lang.code == code,
    orElse: () => supportedLanguages[0],
  );
}