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

  Map<String, dynamic> toJson() => {
        'text': text,
        'lang': lang,
        'source': source.toJson(),
        'markedIncomplete': markedIncomplete,
        'possiblyTruncated': possiblyTruncated,
        'uncertainFragments': uncertainFragments,
      };

  factory IngredientText.fromJson(Map<String, dynamic> j) => IngredientText(
        text: j['text'] as String,
        lang: j['lang'] as String?,
        source: SourceRef.fromJson(j['source'] as Map<String, dynamic>),
        markedIncomplete: j['markedIncomplete'] as bool? ?? false,
        possiblyTruncated: j['possiblyTruncated'] as bool? ?? false,
        uncertainFragments:
            (j['uncertainFragments'] as List?)?.cast<String>() ?? const [],
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

class ProductRecord {
  const ProductRecord({
    required this.barcode,
    required this.source,
    this.name,
    this.brand,
    this.quantity,
    this.countries = const [],
    this.imageUrl,
    this.lastModified,
    this.ingredientTexts = const [],
    this.labelTags = const [],
    this.additiveTags = const [],
    this.certifications = const [],
  });

  /// Barcode, den die Quelle zurückgemeldet hat.
  final String barcode;
  final SourceRef source;
  final String? name;
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

  ProductRecord copyWith({List<IngredientText>? ingredientTexts}) =>
      ProductRecord(
        barcode: barcode,
        source: source,
        name: name,
        brand: brand,
        quantity: quantity,
        countries: countries,
        imageUrl: imageUrl,
        lastModified: lastModified,
        ingredientTexts: ingredientTexts ?? this.ingredientTexts,
        labelTags: labelTags,
        additiveTags: additiveTags,
        certifications: certifications,
      );

  Map<String, dynamic> toJson() => {
        'barcode': barcode,
        'source': source.toJson(),
        'name': name,
        'brand': brand,
        'quantity': quantity,
        'countries': countries,
        'imageUrl': imageUrl,
        'lastModified': lastModified?.toIso8601String(),
        'ingredientTexts': ingredientTexts.map((e) => e.toJson()).toList(),
        'labelTags': labelTags,
        'additiveTags': additiveTags,
        'certifications': certifications.map((e) => e.toJson()).toList(),
      };

  factory ProductRecord.fromJson(Map<String, dynamic> j) => ProductRecord(
        barcode: j['barcode'] as String,
        source: SourceRef.fromJson(j['source'] as Map<String, dynamic>),
        name: j['name'] as String?,
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
      );
}
