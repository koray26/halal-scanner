/// Zentrale Konfiguration. Keine Geheimnisse – in der App ist kein
/// API-Schlüssel eingebaut.
library;

class AppConfig {
  AppConfig._();

  static const appName = 'Halal Scanner';
  static const appVersion = '0.2.0';

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

  /// Offizielle Produktsuche von Open Food Facts (Search-a-licious).
  static const offSearchUrl = 'https://search.openfoodfacts.org/search';

  /// USDA FoodData Central. Bewusst KEIN Schlüssel in der App: Ein eingebauter
  /// Schlüssel wäre aus jeder APK/IPA auslesbar. Nutzer können in den
  /// Einstellungen freiwillig einen eigenen, kostenlosen Schlüssel hinterlegen;
  /// er liegt nur im sicheren Speicher des Geräts (siehe UsdaKeyStore).
  /// Ohne Schlüssel wird USDA nicht abgefragt.
  static const fdcBaseUrl = 'https://api.nal.usda.gov/fdc/v1';
  static const fdcSignupUrl = 'https://api.data.gov/signup/';

  /// Felder, die von Open Food Facts abgefragt werden (Datensparsamkeit).
  static const offFields = [
    'code',
    'product_name',
    // Alle sprachspezifischen Namen (product_name_xx) als Map {Sprachcode: Name}.
    'product_name_languages',
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
    'ingredients',
    'ingredients_analysis_tags',
    'categories_tags',
    'allergens_tags',
    'data_quality_warnings_tags',
    'link',
    'manufacturing_places',
    'customer_service',
    'unknown_ingredients_n',
    'ingredients_n',
  ];

  /// Nach dieser Zeit gilt ein gespeichertes Ergebnis als veraltet.
  static const cacheFreshFor = Duration(days: 30);
}
