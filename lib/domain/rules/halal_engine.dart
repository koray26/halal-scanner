/// Deterministische Halal-Regel-Engine.
///
/// Keine KI, keine Zufälle: Gleiche Eingabe -> gleiches Ergebnis.
/// Entscheidungsreihenfolge siehe [HalalEngine.evaluate] und
/// docs/HALAL_REGELN.md.
library;

import 'dart:math' as math;

import '../barcode.dart';
import '../models.dart';
import 'catalog.dart';
import 'ingredient_parser.dart';

enum HalalStatus {
  /// Regel B: verifiziertes, gültiges, passendes Zertifikat.
  halalCertified,

  /// Regel C: Zutaten vollständig geprüft, nichts Problematisches gefunden.
  /// KEINE Zertifizierung.
  halalByIngredients,

  /// Regel A: verbotener Bestandteil ausdrücklich genannt.
  haram,

  /// Regel D: Entscheidungsrelevante Information fehlt / strittig.
  unclear,

  /// Regel E: Produkt nicht eindeutig identifiziert, Daten fehlen,
  /// sind unvollständig oder widersprüchlich.
  notVerified,
}

/// Textliche Aussagekraft – bewusst keine Prozentzahlen.
enum Certainty { documented, limited, notAssessable }

enum IdentityStatus {
  /// Barcode der Quelle stimmt mit gescanntem Barcode überein, Name vorhanden.
  confirmed,

  /// Barcode stimmt, aber Produktname fehlt -> Zuordnung schwach.
  weak,

  /// Quelle lieferte ein anderes Produkt.
  mismatch,

  /// Kein Datensatz gefunden.
  notFound,

  /// Kein Barcode-Bezug (z. B. nur fotografierte Zutatenliste).
  notApplicable,
}

enum UnknownReason {
  productNotFound,
  identityMismatch,
  identityWeak,
  notIdentifiedPhotoOnly,
  noIngredients,
  ingredientsIncomplete,
  possiblyTruncated,
  uncertainOcrText,
  userEditedText,
  conflictingSources,
  certificationExpired,
  certificationNotApplicable,
  certificationUnverified,
  dataOld,
  manufacturingNotVerified,
  languageNotSupported,
}

class Finding {
  const Finding({
    required this.ruleId,
    required this.effect,
    required this.matchedText,
    required this.ingredient,
    required this.source,
    this.escalatedByPork = false,
    this.resolvedBy,
    this.fromAdditiveTag = false,
  });

  final String ruleId;
  final RuleEffect effect;

  /// Wortlaut, wie er in der Quelle steht.
  final String matchedText;

  /// Vollständiger Bestandteil, in dem der Treffer liegt.
  final String ingredient;
  final SourceRef source;
  final bool escalatedByPork;

  /// Falls die Unklarheit durch eine Angabe aufgelöst wurde (z. B. plant).
  final Qualifier? resolvedBy;
  final bool fromAdditiveTag;

  bool get isResolved => resolvedBy != null;

  Map<String, dynamic> toJson() => {
        'ruleId': ruleId,
        'effect': effect.name,
        'matchedText': matchedText,
        'ingredient': ingredient,
        'source': source.toJson(),
        'escalatedByPork': escalatedByPork,
        'resolvedBy': resolvedBy?.name,
        'fromAdditiveTag': fromAdditiveTag,
      };

  factory Finding.fromJson(Map<String, dynamic> j) => Finding(
        ruleId: j['ruleId'] as String,
        effect: RuleEffect.values.byName(j['effect'] as String),
        matchedText: j['matchedText'] as String,
        ingredient: j['ingredient'] as String,
        source: SourceRef.fromJson(j['source'] as Map<String, dynamic>),
        escalatedByPork: j['escalatedByPork'] as bool? ?? false,
        resolvedBy: j['resolvedBy'] == null
            ? null
            : Qualifier.values.byName(j['resolvedBy'] as String),
        fromAdditiveTag: j['fromAdditiveTag'] as bool? ?? false,
      );
}

class Verdict {
  const Verdict({
    required this.status,
    required this.certainty,
    required this.identity,
    required this.findings,
    required this.unknowns,
    required this.rulesetVersion,
    required this.evaluatedAt,
    required this.checkedIngredientCount,
    this.validCertification,
    this.tracesText,
    this.labelHalalUnverified = false,
  });

  final HalalStatus status;
  final Certainty certainty;
  final IdentityStatus identity;

  /// Alle Treffer (auch aufgelöste und Hinweise) – für den Bericht.
  final List<Finding> findings;
  final List<UnknownReason> unknowns;
  final String rulesetVersion;
  final DateTime evaluatedAt;
  final int checkedIngredientCount;
  final Certification? validCertification;
  final String? tracesText;

  /// Quelle nennt ein Halal-Label, das NICHT verifiziert ist.
  final bool labelHalalUnverified;

  List<Finding> get haramFindings =>
      findings.where((f) => f.effect == RuleEffect.haram).toList();
  List<Finding> get unclearFindings => findings
      .where((f) => f.effect == RuleEffect.unclear && !f.isResolved)
      .toList();
  List<Finding> get resolvedFindings =>
      findings.where((f) => f.isResolved).toList();
  List<Finding> get infoFindings =>
      findings.where((f) => f.effect == RuleEffect.info).toList();

  Map<String, dynamic> toJson() => {
        'status': status.name,
        'certainty': certainty.name,
        'identity': identity.name,
        'findings': findings.map((f) => f.toJson()).toList(),
        'unknowns': unknowns.map((u) => u.name).toList(),
        'rulesetVersion': rulesetVersion,
        'evaluatedAt': evaluatedAt.toIso8601String(),
        'checkedIngredientCount': checkedIngredientCount,
        'validCertification': validCertification?.toJson(),
        'tracesText': tracesText,
        'labelHalalUnverified': labelHalalUnverified,
      };

  factory Verdict.fromJson(Map<String, dynamic> j) => Verdict(
        status: HalalStatus.values.byName(j['status'] as String),
        certainty: Certainty.values.byName(j['certainty'] as String),
        identity: IdentityStatus.values.byName(j['identity'] as String),
        findings: ((j['findings'] as List?) ?? const [])
            .map((e) => Finding.fromJson(e as Map<String, dynamic>))
            .toList(),
        unknowns: ((j['unknowns'] as List?) ?? const [])
            .map((e) => UnknownReason.values.byName(e as String))
            .toList(),
        rulesetVersion: j['rulesetVersion'] as String,
        evaluatedAt: DateTime.parse(j['evaluatedAt'] as String),
        checkedIngredientCount: j['checkedIngredientCount'] as int? ?? 0,
        validCertification: j['validCertification'] == null
            ? null
            : Certification.fromJson(
                j['validCertification'] as Map<String, dynamic>),
        tracesText: j['tracesText'] as String?,
        labelHalalUnverified: j['labelHalalUnverified'] as bool? ?? false,
      );
}

class _CompiledRule {
  _CompiledRule(this.rule)
      : patterns = rule.patterns
            .map((p) => RegExp(word(p), caseSensitive: false, unicode: true))
            .toList(),
        exclusions = rule.exclusions
            .map((p) => RegExp(p, caseSensitive: false, unicode: true))
            .toList();
  final IngredientRule rule;
  final List<RegExp> patterns;
  final List<RegExp> exclusions;
}

class TextAnalysis {
  TextAnalysis(this.findings, this.ingredientCount, this.tracesText);
  final List<Finding> findings;
  final int ingredientCount;
  final String? tracesText;
}

class HalalEngine {
  HalalEngine()
      : _rules = ingredientRules.map(_CompiledRule.new).toList(),
        _qualifiers = {
          for (final e in qualifierPatterns.entries)
            e.key: e.value
                .map((p) =>
                    RegExp(word(p), caseSensitive: false, unicode: true))
                .toList(),
        };

  final List<_CompiledRule> _rules;
  final Map<Qualifier, List<RegExp>> _qualifiers;

  /// Ab diesem Alter wird auf möglicherweise veraltete Daten hingewiesen.
  static const staleAfter = Duration(days: 365 * 3);

  /// Exklusionen werden nur im direkten Umfeld des Treffers geprüft.
  static const _exclusionWindow = 12;

  bool _hasQualifier(String context, Qualifier q) =>
      _qualifiers[q]!.any((r) => r.hasMatch(context));

  /// Analysiert eine einzelne Zutatenliste.
  TextAnalysis analyzeText(IngredientText input) {
    final parsed = IngredientParser.parse(input.text);
    final findings = <Finding>[];
    var count = 0;

    for (final node in parsed.allNodes) {
      final head = node.head.trim();
      if (head.isEmpty) continue;
      count++;
      final context = node.qualifierContext;
      final nodeFindings = <String, Finding>{};

      for (final cr in _rules) {
        for (final re in cr.patterns) {
          final m = re.firstMatch(head);
          if (m == null) continue;
          final from = math.max(0, m.start - _exclusionWindow);
          final to = math.min(head.length, m.end + _exclusionWindow);
          final window = head.substring(from, to);
          final matched = m.group(0)!;
          if (cr.exclusions.any((x) => x.hasMatch(matched) || x.hasMatch(window))) {
            continue;
          }

          var effect = cr.rule.effect;
          var escalated = false;
          Qualifier? resolved;
          if (effect == RuleEffect.unclear) {
            if (cr.rule.escalateOnPork &&
                _hasQualifier(context, Qualifier.porcine)) {
              effect = RuleEffect.haram;
              escalated = true;
            } else {
              for (final q in cr.rule.resolvedBy) {
                if (_hasQualifier(context, q)) {
                  resolved = q;
                  break;
                }
              }
            }
          }
          nodeFindings[cr.rule.id] = Finding(
            ruleId: cr.rule.id,
            effect: effect,
            matchedText: matched.trim(),
            ingredient: node.fullText,
            source: input.source,
            escalatedByPork: escalated,
            resolvedBy: resolved,
          );
          break; // ein Treffer pro Regel und Bestandteil genügt
        }
      }

      // Unterdrückungen (z. B. Weinessig ist kein Wein).
      for (final cr in _rules) {
        if (!nodeFindings.containsKey(cr.rule.id)) continue;
        if (cr.rule.suppressedBy.any(nodeFindings.containsKey)) {
          nodeFindings.remove(cr.rule.id);
        }
      }
      // "Schweinegelatine": eskalierte Gelatine ersetzt den reinen Schwein-Treffer.
      if (nodeFindings.containsKey('pork') &&
          nodeFindings.values.any((f) => f.escalatedByPork)) {
        nodeFindings.remove('pork');
      }
      findings.addAll(nodeFindings.values);
    }
    return TextAnalysis(findings, count, parsed.tracesText);
  }

  /// Gesamtbewertung. Reihenfolge (erste zutreffende Regel gewinnt):
  ///  1. Produkt nicht gefunden / anderes Produkt -> NICHT VERIFIZIERT
  ///  2. Keine Zutatenliste und kein gültiges Zertifikat -> NICHT VERIFIZIERT
  ///  3. Quellen widersprechen sich bei verbotenen Bestandteilen -> NICHT VERIFIZIERT
  ///  4. Verbotener Bestandteil ausdrücklich genannt -> HARAM
  ///     (falls zugleich gültiges Zertifikat: Widerspruch -> NICHT VERIFIZIERT)
  ///  5. Gültiges, verifiziertes, passendes Zertifikat -> HALAL-ZERTIFIZIERT
  ///  6. Ungeklärte Bestandteile -> UNKLAR
  ///  7. Daten unvollständig / nur Foto / Nutzertext / schwache Zuordnung
  ///     -> NICHT VERIFIZIERT
  ///  8. Sonst -> HALAL NACH ZUTATENPRÜFUNG (keine Zertifizierung!)
  Verdict evaluate({
    required ProductRecord? product,
    String? scannedBarcode,
    List<IngredientText>? overrideTexts,
    required DateTime now,
  }) {
    final unknowns = <UnknownReason>{};

    // --- Identität ---------------------------------------------------------
    IdentityStatus identity;
    if (scannedBarcode == null) {
      identity = IdentityStatus.notApplicable;
    } else if (product == null) {
      identity = IdentityStatus.notFound;
    } else if (!Barcode.sameProduct(product.barcode, scannedBarcode)) {
      identity = IdentityStatus.mismatch;
    } else if ((product.name ?? '').trim().isEmpty) {
      identity = IdentityStatus.weak;
    } else {
      identity = IdentityStatus.confirmed;
    }

    Verdict result(HalalStatus s, Certainty c,
            {List<Finding> findings = const [],
            int count = 0,
            Certification? cert,
            String? traces,
            bool label = false}) =>
        Verdict(
          status: s,
          certainty: c,
          identity: identity,
          findings: findings,
          unknowns: unknowns.toList(),
          rulesetVersion: rulesetVersion,
          evaluatedAt: now,
          checkedIngredientCount: count,
          validCertification: cert,
          tracesText: traces,
          labelHalalUnverified: label,
        );

    if (identity == IdentityStatus.notFound) {
      unknowns.add(UnknownReason.productNotFound);
      return result(HalalStatus.notVerified, Certainty.notAssessable);
    }
    if (identity == IdentityStatus.mismatch) {
      unknowns.add(UnknownReason.identityMismatch);
      return result(HalalStatus.notVerified, Certainty.notAssessable);
    }
    if (identity == IdentityStatus.weak) unknowns.add(UnknownReason.identityWeak);
    if (identity == IdentityStatus.notApplicable) {
      unknowns.add(UnknownReason.notIdentifiedPhotoOnly);
    }

    final labelHalal =
        product?.labelTags.any((t) => t.toLowerCase().endsWith(':halal')) ??
            false;

    if (product?.lastModified != null &&
        now.difference(product!.lastModified!) > staleAfter) {
      unknowns.add(UnknownReason.dataOld);
    }

    // --- Zertifikat --------------------------------------------------------
    Certification? validCert;
    for (final c in product?.certifications ?? const <Certification>[]) {
      if (!c.verified) {
        unknowns.add(UnknownReason.certificationUnverified);
        continue;
      }
      final matches = scannedBarcode != null &&
          c.gtins.any((g) => Barcode.sameProduct(g, scannedBarcode));
      if (!matches) {
        unknowns.add(UnknownReason.certificationNotApplicable);
        continue;
      }
      final started = c.validFrom == null || !now.isBefore(c.validFrom!);
      final notExpired = c.validUntil != null && !now.isAfter(c.validUntil!);
      if (!started || !notExpired) {
        unknowns.add(UnknownReason.certificationExpired);
        continue;
      }
      validCert = c;
    }

    // --- Zutaten -----------------------------------------------------------
    final available = (overrideTexts ?? product?.ingredientTexts ?? const [])
        .where((t) => t.text.trim().length >= 3)
        .toList();
    // Datenbanktexte nur in Sprachen auswerten, für die Regeln existieren.
    // Fotos/Nutzertexte können ohnehin keine Halal-Freigabe erzeugen.
    final texts = available
        .where((t) =>
            t.source.kind != SourceKind.openFoodFacts ||
            supportedRuleLanguages.contains(t.lang))
        .toList();
    if (available.isNotEmpty && texts.isEmpty) {
      unknowns.add(UnknownReason.languageNotSupported);
    }

    if (texts.isEmpty) {
      if (validCert != null) {
        unknowns.add(UnknownReason.manufacturingNotVerified);
        return result(HalalStatus.halalCertified, Certainty.documented,
            cert: validCert, label: labelHalal);
      }
      unknowns.add(UnknownReason.noIngredients);
      return result(HalalStatus.notVerified, Certainty.notAssessable,
          label: labelHalal);
    }

    final analyses = texts.map(analyzeText).toList();
    final findings = <Finding>[];
    var count = 0;
    String? traces;
    for (final a in analyses) {
      findings.addAll(a.findings);
      if (a.ingredientCount > count) count = a.ingredientCount;
      traces ??= a.tracesText;
    }

    // Zusatzstoff-Tags der Quelle als Ergänzung (nur falls nicht im Text).
    if (product != null && overrideTexts == null) {
      final ruleIdsFound = findings.map((f) => f.ruleId).toSet();
      for (final tag in product.additiveTags) {
        final ruleId = additiveTagRules[tag.toLowerCase()];
        if (ruleId == null || ruleIdsFound.contains(ruleId)) continue;
        findings.add(Finding(
          ruleId: ruleId,
          effect: RuleEffect.unclear,
          matchedText: tag.split(':').last.toUpperCase(),
          ingredient: tag.split(':').last.toUpperCase(),
          source: product.source,
          fromAdditiveTag: true,
        ));
        ruleIdsFound.add(ruleId);
      }
    }

    for (final t in texts) {
      if (t.markedIncomplete) unknowns.add(UnknownReason.ingredientsIncomplete);
      if (t.possiblyTruncated) unknowns.add(UnknownReason.possiblyTruncated);
      if (t.uncertainFragments.isNotEmpty) {
        unknowns.add(UnknownReason.uncertainOcrText);
      }
      if (t.source.kind == SourceKind.userEdited) {
        unknowns.add(UnknownReason.userEditedText);
      }
    }

    // Widerspruch: verschiedene Listen desselben Produkts nennen
    // unterschiedliche verbotene Bestandteile.
    if (analyses.length > 1) {
      final haramSets = analyses
          .map((a) => a.findings
              .where((f) => f.effect == RuleEffect.haram)
              .map((f) => f.escalatedByPork ? 'pork' : f.ruleId)
              .toSet())
          .toList();
      final first = haramSets.first;
      final conflict = haramSets.any(
          (s) => s.length != first.length || !s.containsAll(first));
      if (conflict) {
        unknowns.add(UnknownReason.conflictingSources);
        return result(HalalStatus.notVerified, Certainty.notAssessable,
            findings: findings, count: count, traces: traces, label: labelHalal);
      }
    }

    final hasHaram = findings.any((f) => f.effect == RuleEffect.haram);
    final hasUnclear = findings
        .any((f) => f.effect == RuleEffect.unclear && !f.isResolved);

    if (hasHaram) {
      if (validCert != null) {
        unknowns.add(UnknownReason.conflictingSources);
        return result(HalalStatus.notVerified, Certainty.notAssessable,
            findings: findings, count: count, traces: traces, label: labelHalal);
      }
      return result(HalalStatus.haram, Certainty.documented,
          findings: findings, count: count, traces: traces, label: labelHalal);
    }

    if (validCert != null) {
      unknowns.add(UnknownReason.manufacturingNotVerified);
      return result(HalalStatus.halalCertified, Certainty.documented,
          findings: findings,
          count: count,
          cert: validCert,
          traces: traces,
          label: labelHalal);
    }

    if (hasUnclear) {
      return result(HalalStatus.unclear, Certainty.limited,
          findings: findings, count: count, traces: traces, label: labelHalal);
    }

    const blocking = {
      UnknownReason.identityWeak,
      UnknownReason.notIdentifiedPhotoOnly,
      UnknownReason.ingredientsIncomplete,
      UnknownReason.possiblyTruncated,
      UnknownReason.uncertainOcrText,
      UnknownReason.userEditedText,
    };
    if (unknowns.any(blocking.contains)) {
      return result(HalalStatus.notVerified, Certainty.notAssessable,
          findings: findings, count: count, traces: traces, label: labelHalal);
    }

    unknowns.add(UnknownReason.manufacturingNotVerified);
    return result(HalalStatus.halalByIngredients, Certainty.limited,
        findings: findings, count: count, traces: traces, label: labelHalal);
  }
}
