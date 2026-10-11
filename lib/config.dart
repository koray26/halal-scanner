/// Zentrale Konfiguration. Keine Geheimnisse – die App benötigt keine
/// API-Schlüssel.
library;

class AppConfig {
  AppConfig._();

  static const appName = 'Halal Scanner';
  static const appVersion = '0.1.0';

  /// Open Food Facts verlangt eine Kontaktadresse im User-Agent.
  /// Beim Bauen setzen mit:
  ///   flutter build apk --dart-define=CONTACT_EMAIL=ihre@adresse.de
  /// Ohne Angabe wird ein neutraler Platzhalter gesendet.
  static const contactEmail = String.fromEnvironment(
    'CONTACT_EMAIL',
    defaultValue: 'kontakt-nicht-konfiguriert@example.invalid',
  );

  static bool get hasContactEmail => !contactEmail.endsWith('.invalid');

  static String get userAgent =>
      'HalalScanner/$appVersion (Flutter; $contactEmail)';

  static const offBaseUrl = 'https://world.openfoodfacts.org';

  /// Felder, die von Open Food Facts abgefragt werden (Datensparsamkeit).
  static const offFields = [
    'code',
    'product_name',
    'product_name_de',
    'product_name_en',
    'generic_name',
    'brands',
    'quantity',
    'countries_tags',
    'lang',
    'ingredients_text',
    'ingredients_text_de',
    'ingredients_text_en',
    'ingredients_text_fr',
    'ingredients_text_tr',
    'ingredients_text_ar',
    'labels_tags',
    'additives_tags',
    'states_tags',
    'image_front_url',
    'last_modified_t',
  ];

  /// Nach dieser Zeit gilt ein gespeichertes Ergebnis als veraltet.
  static const cacheFreshFor = Duration(days: 30);
}
