/// Datenmodelle der Domäne. Reines Dart – keine Flutter-Abhängigkeit,
/// damit alles ohne Gerät testbar ist.
library;

enum SourceKind {
  /// Datensatz aus der Open-Food-Facts-Datenbank (Community-Daten, ODbL).
  openFoodFacts,

  /// Vom Nutzer fotografierter und per OCR gelesener Text.
  ocrPhoto,

  /// Vom Nutzer manuell eingegebener oder korrigierter Text.
  userEdited,

  /// Zertifikatsregister (derzeit keine kostenlose, verifizierbare Quelle angebunden).
  certificationRegistry,

  /// USDA FoodData Central, Datentyp „Branded Foods“ (Public Domain, CC0).
  /// Herstellerangaben für den US-Markt; nur bei exakt gleicher GTIN genutzt.
  usdaFdc,
}

/// Ergebnis der Abfrage einer Quelle bei einem Scan (Nachweis, was geprüft wurde).
enum SourceCheckStatus {
  /// Passender Datensatz gefunden.
  found,

  /// Abgefragt, aber kein passender Datensatz.
  notFound,

  /// Abfrage fehlgeschlagen (offline, Zeitüberschreitung, Limit) – NICHT geprüft.
  unavailable,

  /// Quelle braucht einen kostenlosen Schlüssel, der nicht hinterlegt ist.
  notConfigured,

  /// Nicht nötig, weil eine vorrangige Quelle bereits Zutaten lieferte.
  skipped,
}

class SourceCheck {
  const SourceCheck(this.kind, this.status, {this.checkedAt});
  final SourceKind kind;
  final SourceCheckStatus status;
  final DateTime? checkedAt;

  Map<String, dynamic> toJson() => {
        'kind': kind.name,
        'status': status.name,
        'checkedAt': checkedAt?.toIso8601String(),
      };

  factory SourceCheck.fromJson(Map<String, dynamic> j) => SourceCheck(
        SourceKind.values.byName(j['kind'] as String),
        SourceCheckStatus.values.byName(j['status'] as String),
        checkedAt: j['checkedAt'] == null ? null : DateTime.parse(j['checkedAt'] as String),
      );
}

class SourceRef {
  const SourceRef({
    required this.kind,
    required this.retrievedAt,
    this.url,
    this.version,
    this.note,
  });

  final SourceKind kind;
  final DateTime retrievedAt;
  final String? url;

  /// z. B. Zeitstempel der letzten Änderung in Open Food Facts.
  final String? version;
  final String? note;

  Map<String, dynamic> toJson() => {
        'kind': kind.name,
        'retrievedAt': retrievedAt.toIso8601String(),
        'url': url,
        'version': version,
        'note': note,
      };

  factory SourceRef.fromJson(Map<String, dynamic> j) => SourceRef(
        kind: SourceKind.values.byName(j['kind'] as String),
        retrievedAt: DateTime.parse(j['retrievedAt'] as String),
        url: j['url'] as String?,
        version: j['version'] as String?,
        note: j['note'] as String?,
      );
}

/// Eine Zutatenliste, so wie sie in einer Quelle steht – unverändert.
class IngredientText {
  const IngredientText({
    required this.text,
    required this.source,
    this.lang,
    this.markedIncomplete = false,
    this.possiblyTruncated = false,
    this.uncertainFragments = const [],
    this.unsupportedScript = false,
  });

  final String text;
  final String? lang;
  final SourceRef source;

  /// Quelle selbst kennzeichnet die Liste als unvollständig.
  final bool markedIncomplete;

  /// Hinweis, dass die Liste abgeschnitten sein könnte (z. B. OCR-Bildrand).
  final bool possiblyTruncated;

  /// Textstellen, die die OCR nur unsicher erkannt hat.
  final List<String> uncertainFragments;

  /// Foto enthält vermutlich nicht unterstützte Schrift.
  final bool unsupportedScript;

  Map<String, dynamic> toJson() => {
        'text': text,
        'lang': lang,
        'source': source.toJson(),
        'markedIncomplete': markedIncomplete,
        'possiblyTruncated': possiblyTruncated,
        'uncertainFragments': uncertainFragments,
        'unsupportedScript': unsupportedScript,
      };

  factory IngredientText.fromJson(Map<String, dynamic> j) => IngredientText(
        text: j['text'] as String,
        lang: j['lang'] as String?,
        source: SourceRef.fromJson(j['source'] as Map<String, dynamic>),
        markedIncomplete: j['markedIncomplete'] as bool? ?? false,
        possiblyTruncated: j['possiblyTruncated'] as bool? ?? false,
        uncertainFragments:
            (j['uncertainFragments'] as List?)?.cast<String>() ?? const [],
        unsupportedScript: j['unsupportedScript'] as bool? ?? false,
      );
}

/// Halal-Zertifikat. Wird nur als gültig gewertet, wenn es verifiziert ist,
/// zum exakten Barcode passt und im Gültigkeitszeitraum liegt.
class Certification {
  const Certification({
    required this.certifier,
    required this.gtins,
    required this.verified,
    required this.source,
    this.manufacturer,
    this.validFrom,
    this.validUntil,
    this.certificateId,
  });

  final String certifier;
  final List<String> gtins;
  final bool verified;
  final SourceRef source;
  final String? manufacturer;
  final DateTime? validFrom;
  final DateTime? validUntil;
  final String? certificateId;

  Map<String, dynamic> toJson() => {
        'certifier': certifier,
        'gtins': gtins,
        'verified': verified,
        'source': source.toJson(),
        'manufacturer': manufacturer,
        'validFrom': validFrom?.toIso8601String(),
        'validUntil': validUntil?.toIso8601String(),
        'certificateId': certificateId,
      };

  factory Certification.fromJson(Map<String, dynamic> j) => Certification(
        certifier: j['certifier'] as String,
        gtins: (j['gtins'] as List).cast<String>(),
        verified: j['verified'] as bool,
        source: SourceRef.fromJson(j['source'] as Map<String, dynamic>),
        manufacturer: j['manufacturer'] as String?,
        validFrom: j['validFrom'] == null
            ? null
            : DateTime.parse(j['validFrom'] as String),
        validUntil: j['validUntil'] == null
            ? null
            : DateTime.parse(j['validUntil'] as String),
        certificateId: j['certificateId'] as String?,
      );
}

/// Eine von Open Food Facts strukturiert erkannte Zutat (mit Unterzutaten).
/// `vegan`/`vegetarian` stammen aus der allgemeinen OFF-Taxonomie und sind
/// keine produktspezifische Herstellerangabe.
class OffIngredient {
  const OffIngredient({
    required this.id,
    required this.text,
    this.inTaxonomy = false,
    this.vegan,
    this.vegetarian,
    this.children = const [],
  });

  final String id;
  final String text;
  final bool inTaxonomy;
  final String? vegan;
  final String? vegetarian;
  final List<OffIngredient> children;

  Iterable<OffIngredient> get allNodes sync* {
    yield this;
    for (final c in children) {
      yield* c.allNodes;
    }
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'text': text,
        'inTaxonomy': inTaxonomy,
        'vegan': vegan,
        'vegetarian': vegetarian,
        'children': children.map((c) => c.toJson()).toList(),
      };

  factory OffIngredient.fromJson(Map<String, dynamic> j) => OffIngredient(
        id: j['id'] as String? ?? '',
        text: j['text'] as String? ?? '',
        inTaxonomy: j['inTaxonomy'] as bool? ?? false,
        vegan: j['vegan'] as String?,
        vegetarian: j['vegetarian'] as String?,
        children: ((j['children'] as List?) ?? const [])
            .map((e) => OffIngredient.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class ProductRecord {
  const ProductRecord({
    required this.barcode,
    required this.source,
    this.name,
    this.localizedNames = const {},
    this.brand,
    this.quantity,
    this.countries = const [],
    this.imageUrl,
    this.lastModified,
    this.ingredientTexts = const [],
    this.labelTags = const [],
    this.additiveTags = const [],
    this.certifications = const [],
    this.structuredIngredients = const [],
    this.analysisTags = const [],
    this.categoryTags = const [],
    this.allergenTags = const [],
    this.dataQualityWarnings = const [],
    this.manufacturerLink,
    this.manufacturingPlaces,
    this.customerService,
    this.unknownIngredientsN,
    this.ingredientsN,
  });

  /// Barcode, den die Quelle zurückgemeldet hat.
  final String barcode;
  final SourceRef source;

  /// Hauptname laut Quelle (Hauptsprache des Datensatzes, sonst ein Name in
  /// einer anderen Sprache). Die Marke ist bewusst KEIN Ersatz für den Namen.
  final String? name;

  /// Produktnamen je Sprachcode laut Quelle (bereinigt). Namen, die dem
  /// Hauptnamen gleichen, sind nicht doppelt enthalten.
  final Map<String, String> localizedNames;
  final String? brand;
  final String? quantity;
  final List<String> countries;
  final String? imageUrl;
  final DateTime? lastModified;
  final List<IngredientText> ingredientTexts;

  /// Labels laut Quelle (z. B. "en:halal") – NICHT verifiziert.
  final List<String> labelTags;

  /// Zusatzstoffe laut Quelle (z. B. "en:e471").
  final List<String> additiveTags;
  final List<Certification> certifications;

  /// Strukturierte Zutatenanalyse von Open Food Facts (inkl. Unterzutaten).
  final List<OffIngredient> structuredIngredients;

  /// z. B. en:non-vegan, en:vegan-status-unknown (aus allgemeiner Taxonomie berechnet).
  final List<String> analysisTags;
  final List<String> categoryTags;
  final List<String> allergenTags;

  /// Datenqualitäts-Warnungen der Datenbank.
  final List<String> dataQualityWarnings;

  /// Link zur Produktseite des Herstellers (laut Datenbank).
  final String? manufacturerLink;
  final String? manufacturingPlaces;
  final String? customerService;
  final int? unknownIngredientsN;
  final int? ingredientsN;

  /// Name für die Anzeige: bevorzugt in der App-Sprache [lang], sonst der
  /// Hauptname. Liefert `null`, wenn die Quelle keinen Namen enthält.
  String? nameFor(String lang) => localizedNames[lang] ?? name;

  Iterable<OffIngredient> get allStructuredIngredients sync* {
    for (final i in structuredIngredients) {
      yield* i.allNodes;
    }
  }

  ProductRecord copyWith({List<IngredientText>? ingredientTexts, String? name}) =>
      ProductRecord(
        barcode: barcode,
        source: source,
        name: name ?? this.name,
        localizedNames: localizedNames,
        brand: brand,
        quantity: quantity,
        countries: countries,
        imageUrl: imageUrl,
        lastModified: lastModified,
        ingredientTexts: ingredientTexts ?? this.ingredientTexts,
        labelTags: labelTags,
        additiveTags: additiveTags,
        certifications: certifications,
        structuredIngredients: structuredIngredients,
        analysisTags: analysisTags,
        categoryTags: categoryTags,
        allergenTags: allergenTags,
        dataQualityWarnings: dataQualityWarnings,
        manufacturerLink: manufacturerLink,
        manufacturingPlaces: manufacturingPlaces,
        customerService: customerService,
        unknownIngredientsN: unknownIngredientsN,
        ingredientsN: ingredientsN,
      );

  Map<String, dynamic> toJson() => {
        'barcode': barcode,
        'source': source.toJson(),
        'name': name,
        'localizedNames': localizedNames,
        'brand': brand,
        'quantity': quantity,
        'countries': countries,
        'imageUrl': imageUrl,
        'lastModified': lastModified?.toIso8601String(),
        'ingredientTexts': ingredientTexts.map((e) => e.toJson()).toList(),
        'labelTags': labelTags,
        'additiveTags': additiveTags,
        'certifications': certifications.map((e) => e.toJson()).toList(),
        'structuredIngredients':
            structuredIngredients.map((e) => e.toJson()).toList(),
        'analysisTags': analysisTags,
        'categoryTags': categoryTags,
        'allergenTags': allergenTags,
        'dataQualityWarnings': dataQualityWarnings,
        'manufacturerLink': manufacturerLink,
        'manufacturingPlaces': manufacturingPlaces,
        'customerService': customerService,
        'unknownIngredientsN': unknownIngredientsN,
        'ingredientsN': ingredientsN,
      };

  factory ProductRecord.fromJson(Map<String, dynamic> j) => ProductRecord(
        barcode: j['barcode'] as String,
        source: SourceRef.fromJson(j['source'] as Map<String, dynamic>),
        name: j['name'] as String?,
        localizedNames: (j['localizedNames'] as Map?)?.cast<String, String>() ?? const {},
        brand: j['brand'] as String?,
        quantity: j['quantity'] as String?,
        countries: (j['countries'] as List?)?.cast<String>() ?? const [],
        imageUrl: j['imageUrl'] as String?,
        lastModified: j['lastModified'] == null
            ? null
            : DateTime.parse(j['lastModified'] as String),
        ingredientTexts: ((j['ingredientTexts'] as List?) ?? const [])
            .map((e) => IngredientText.fromJson(e as Map<String, dynamic>))
            .toList(),
        labelTags: (j['labelTags'] as List?)?.cast<String>() ?? const [],
        additiveTags: (j['additiveTags'] as List?)?.cast<String>() ?? const [],
        certifications: ((j['certifications'] as List?) ?? const [])
            .map((e) => Certification.fromJson(e as Map<String, dynamic>))
            .toList(),
        structuredIngredients: ((j['structuredIngredients'] as List?) ?? const [])
            .map((e) => OffIngredient.fromJson(e as Map<String, dynamic>))
            .toList(),
        analysisTags: (j['analysisTags'] as List?)?.cast<String>() ?? const [],
        categoryTags: (j['categoryTags'] as List?)?.cast<String>() ?? const [],
        allergenTags: (j['allergenTags'] as List?)?.cast<String>() ?? const [],
        dataQualityWarnings:
            (j['dataQualityWarnings'] as List?)?.cast<String>() ?? const [],
        manufacturerLink: j['manufacturerLink'] as String?,
        manufacturingPlaces: j['manufacturingPlaces'] as String?,
        customerService: j['customerService'] as String?,
        unknownIngredientsN: j['unknownIngredientsN'] as int?,
        ingredientsN: j['ingredientsN'] as int?,
      );
}
