/// Deterministische Halal-Regel-Engine.
///
/// Keine KI, keine Zufälle: Gleiche Eingabe -> gleiches Ergebnis.
/// Entscheidungsreihenfolge siehe [HalalEngine.evaluate] und
/// docs/HALAL_REGELN.md.
library;

import 'dart:math' as math;

import '../barcode.dart';
import '../models.dart';
import '../research/research.dart';
import 'catalog.dart';
import 'ingredient_parser.dart';

enum HalalStatus {
  /// Regel B: verifiziertes, gültiges, passendes Zertifikat.
  halalCertified,

  /// Regel C: HALAL NACH VOLLSTÄNDIGER ZUTATENPRÜFUNG – nur wenn ALLE
  /// [GreenCondition]s erfüllt sind. KEINE Zertifizierung, keine Garantie.
  halalByIngredients,

  /// Regel A: verbotener Bestandteil ausdrücklich genannt.
  haram,

  /// Regel D: Herkunft trotz Recherche ungeklärt oder Bewertung strittig.
  unclear,

  /// Regel E: Produkt, vollständige Zutatenliste oder relevante Information
  /// fehlt, ist unvollständig, widersprüchlich oder nicht zuverlässig.
  notVerified,
}

/// Textliche Aussagekraft – bewusst keine Prozentzahlen.
enum Certainty { documented, limited, notAssessable }

enum IdentityStatus { confirmed, weak, mismatch, notFound, notApplicable }

/// Ausdrücklich definierte Voraussetzungen für ein grünes Ergebnis.
/// Ein grünes Ergebnis entsteht NUR, wenn alle erfüllt sind.
enum GreenCondition {
  productIdentified,
  ingredientListAvailable,
  databaseSource,
  languageSupported,
  listComplete,
  dataPlausible,
  noConflicts,
  noProhibited,
  allOriginsClarified,
  noDisputedSubstance,
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
  languageMismatch,
  ingredientsMostlyUnrecognized,
  labelContradiction,
  researchSourceUnavailable,
  unsupportedScript,
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
    this.fromStructuredData = false,
    this.qualifiers = const {},
    this.resolutionKeys = const [],
  });

  final String ruleId;
  final RuleEffect effect;

  /// Wortlaut, wie er in der Quelle steht.
  final String matchedText;

  /// Vollständiger Bestandteil, in dem der Treffer liegt.
  final String ingredient;
  final SourceRef source;
  final bool escalatedByPork;

  /// Durch welche produktbezogene Herkunftsangabe die Unklarheit
  /// aufgelöst wurde (von der Recherche gesetzt).
  final Qualifier? resolvedBy;
  final bool fromAdditiveTag;

  /// Aus der strukturierten Zutatenanalyse der Datenbank (nicht aus dem Text).
  final bool fromStructuredData;

  /// Herkunftsangaben im Kontext der Zutat.
  final Set<Qualifier> qualifiers;

  /// Produktbezogene Belege, die die Unklarheit aufgelöst haben
  /// (z. B. "qualifier.plant", "labelVegan").
  final List<String> resolutionKeys;

  bool get isResolved => resolvedBy != null || resolutionKeys.isNotEmpty;

  Finding withResolution(Qualifier? q, List<String> keys) => Finding(
        ruleId: ruleId,
        effect: effect,
        matchedText: matchedText,
        ingredient: ingredient,
        source: source,
        escalatedByPork: escalatedByPork,
        resolvedBy: q,
        fromAdditiveTag: fromAdditiveTag,
        fromStructuredData: fromStructuredData,
        qualifiers: qualifiers,
        resolutionKeys: keys,
      );

  Map<String, dynamic> toJson() => {
        'ruleId': ruleId,
        'effect': effect.name,
        'matchedText': matchedText,
        'ingredient': ingredient,
        'source': source.toJson(),
        'escalatedByPork': escalatedByPork,
        'resolvedBy': resolvedBy?.name,
        'fromAdditiveTag': fromAdditiveTag,
        'fromStructuredData': fromStructuredData,
        'qualifiers': qualifiers.map((q) => q.name).toList(),
        'resolutionKeys': resolutionKeys,
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
        fromStructuredData: j['fromStructuredData'] as bool? ?? false,
        qualifiers: ((j['qualifiers'] as List?) ?? const [])
            .map((e) => Qualifier.values.byName(e as String))
            .toSet(),
        resolutionKeys:
            (j['resolutionKeys'] as List?)?.cast<String>() ?? const [],
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
    this.investigations = const [],
    this.greenConditions = const {},
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

  /// Rechercheergebnis je kritischer Zutat.
  final List<Investigation> investigations;

  /// Erfüllte/nicht erfüllte Voraussetzungen für ein grünes Ergebnis.
  final Map<GreenCondition, bool> greenConditions;

  List<Finding> get haramFindings =>
      findings.where((f) => f.effect == RuleEffect.haram).toList();
  List<Finding> get unclearFindings => findings
      .where((f) => f.effect == RuleEffect.unclear && !f.isResolved)
      .toList();
  List<Finding> get resolvedFindings =>
      findings.where((f) => f.isResolved).toList();
  List<Finding> get infoFindings =>
      findings.where((f) => f.effect == RuleEffect.info).toList();

  bool get allGreenConditionsMet =>
      greenConditions.length == GreenCondition.values.length &&
      greenConditions.values.every((v) => v);

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
        'investigations': investigations.map((i) => i.toJson()).toList(),
        'greenConditions':
            greenConditions.map((k, v) => MapEntry(k.name, v)),
      };

  factory Verdict.fromJson(Map<String, dynamic> j) => Verdict(
        status: HalalStatus.values.byName(j['status'] as String),
        certainty: Certainty.values.byName(j['certainty'] as String),
        identity: IdentityStatus.values.byName(j['identity'] as String),
        findings: ((j['findings'] as List?) ?? const [])
            .map((e) => Finding.fromJson(e as Map<String, dynamic>))
            .toList(),
        unknowns: ((j['unknowns'] as List?) ?? const [])
            .map((e) => UnknownReason.values.asNameMap()[e as String])
            .whereType<UnknownReason>()
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
        investigations: ((j['investigations'] as List?) ?? const [])
            .map((e) => Investigation.fromJson(e as Map<String, dynamic>))
            .toList(),
        greenConditions: ((j['greenConditions'] as Map?) ?? const {}).map(
            (k, v) => MapEntry(GreenCondition.values.byName(k as String), v as bool)),
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
  TextAnalysis(this.findings, this.ingredientCount, this.tracesText,
      {this.unbalancedBrackets = false});
  final List<Finding> findings;
  final int ingredientCount;
  final String? tracesText;
  final bool unbalancedBrackets;
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
  static const _research = ResearchPipeline();

  /// Ab diesem Alter wird auf möglicherweise veraltete Daten hingewiesen.
  static const staleAfter = Duration(days: 365 * 3);

  /// Exklusionen werden nur im direkten Umfeld des Treffers geprüft.
  static const _exclusionWindow = 12;

  Set<Qualifier> _qualifiersIn(String context) => {
        for (final e in _qualifiers.entries)
          if (e.value.any((r) => r.hasMatch(context))) e.key,
      };

  /// Prüft einen einzelnen Bestandteil gegen alle Regeln.
  Map<String, Finding> _matchHead(String head, String context, String fullText,
      SourceRef source, {bool structured = false}) {
    final nodeFindings = <String, Finding>{};
    final quals = _qualifiersIn(context);
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
        if (effect == RuleEffect.unclear &&
            cr.rule.escalateOnPork &&
            quals.contains(Qualifier.porcine)) {
          effect = RuleEffect.haram;
          escalated = true;
        }
        nodeFindings[cr.rule.id] = Finding(
          ruleId: cr.rule.id,
          effect: effect,
          matchedText: matched.trim(),
          ingredient: fullText,
          source: source,
          escalatedByPork: escalated,
          fromStructuredData: structured,
          qualifiers: quals,
        );
        break; // ein Treffer pro Regel und Bestandteil genügt
      }
    }
    for (final cr in _rules) {
      if (!nodeFindings.containsKey(cr.rule.id)) continue;
      if (cr.rule.suppressedBy.any(nodeFindings.containsKey)) {
        nodeFindings.remove(cr.rule.id);
      }
    }
    if (nodeFindings.containsKey('pork') &&
        nodeFindings.values.any((f) => f.escalatedByPork)) {
      nodeFindings.remove('pork');
    }
    return nodeFindings;
  }

  /// Analysiert eine einzelne Zutatenliste.
  TextAnalysis analyzeText(IngredientText input) {
    final parsed = IngredientParser.parse(input.text);
    final findings = <Finding>[];
    var count = 0;
    for (final node in parsed.allNodes) {
      final head = node.head.trim();
      if (head.isEmpty) continue;
      count++;
      findings.addAll(
          _matchHead(head, node.qualifierContext, node.fullText, input.source).values);
    }
    final opens = '('.allMatches(parsed.normalizedText).length;
    final closes = ')'.allMatches(parsed.normalizedText).length;
    return TextAnalysis(findings, count, parsed.tracesText,
        unbalancedBrackets: opens != closes);
  }

  /// Wertet die strukturierte Zutatenanalyse der Datenbank aus (Kennungen
  /// wie "en:pork-gelatin"). Wird genutzt, wenn der Text in einer nicht
  /// unterstützten Sprache vorliegt. Kann nie zu einer Freigabe führen.
  List<Finding> analyzeStructured(ProductRecord p) {
    final out = <Finding>[];
    void walk(OffIngredient n, String parentContext) {
      if (n.id.startsWith('en:')) {
        final pseudo = n.id.substring(3).replaceAll('-', ' ');
        final context = '$pseudo | $parentContext';
        out.addAll(_matchHead(pseudo, context, '${n.text} (${n.id})', p.source,
                structured: true)
            .values);
      } else {
        // Nicht in der Taxonomie: Originaltext trotzdem prüfen (z. B. "gelatine").
        out.addAll(_matchHead(n.text, '${n.text} | $parentContext',
                '${n.text} (${n.id})', p.source, structured: true)
            .values);
      }
      for (final c in n.children) {
        walk(c, n.id);
      }
    }

    for (final n in p.structuredIngredients) {
      walk(n, '');
    }
    return out;
  }

  /// Gesamtbewertung. Reihenfolge (erste zutreffende Regel gewinnt):
  ///  1. Produkt nicht gefunden / anderes Produkt -> NICHT VERIFIZIERT
  ///  2. Keine Zutaten und kein gültiges Zertifikat -> NICHT VERIFIZIERT
  ///  3. Widersprüchliche Quellen/Kennzeichnungen -> NICHT VERIFIZIERT
  ///  4. Verbotener Bestandteil ausdrücklich genannt -> HARAM
  ///  5. Gültiges, verifiziertes, passendes Zertifikat -> HALAL-ZERTIFIZIERT
  ///  6. Herkunft trotz Recherche offen / strittig -> UNKLAR
  ///  7. Nicht alle [GreenCondition]s erfüllt -> NICHT VERIFIZIERT
  ///  8. Sonst -> HALAL NACH VOLLSTÄNDIGER ZUTATENPRÜFUNG (keine Zertifizierung)
  Verdict evaluate({
    required ProductRecord? product,
    String? scannedBarcode,
    List<IngredientText>? overrideTexts,
    ResearchContext? research,
    required DateTime now,
  }) {
    final unknowns = <UnknownReason>{};
    final ctx = research ?? ResearchContext(product: product);

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

    final conditions = <GreenCondition, bool>{
      for (final c in GreenCondition.values) c: false,
    };
    conditions[GreenCondition.productIdentified] =
        identity == IdentityStatus.confirmed;

    var findings = <Finding>[];
    var investigations = <Investigation>[];
    var count = 0;
    String? traces;
    Certification? validCert;
    final labelHalal =
        product?.labelTags.any((t) => t.toLowerCase().endsWith(':halal')) ??
            false;

    Verdict result(HalalStatus s, Certainty c) => Verdict(
          status: s,
          certainty: c,
          identity: identity,
          findings: findings,
          unknowns: unknowns.toList(),
          rulesetVersion: rulesetVersion,
          evaluatedAt: now,
          checkedIngredientCount: count,
          validCertification: s == HalalStatus.halalCertified ? validCert : null,
          tracesText: traces,
          labelHalalUnverified: labelHalal,
          investigations: investigations,
          greenConditions: Map.unmodifiable(conditions),
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

    if (product?.lastModified != null &&
        now.difference(product!.lastModified!) > staleAfter) {
      unknowns.add(UnknownReason.dataOld);
    }

    // --- Datenqualität laut Datenbank ----------------------------------------
    var plausible = true;
    if (product != null && overrideTexts == null) {
      final w = product.dataQualityWarnings.map((e) => e.toLowerCase());
      if (w.any((x) => x.contains('ingredients-language-mismatch'))) {
        unknowns.add(UnknownReason.languageMismatch);
        plausible = false;
      }
      final n = product.ingredientsN ?? 0;
      final unknownN = product.unknownIngredientsN ?? 0;
      if (w.any((x) => x.contains('ingredients-80-percent-unknown')) ||
          (n > 0 && unknownN * 2 > n)) {
        unknowns.add(UnknownReason.ingredientsMostlyUnrecognized);
        plausible = false;
      }
    }

    // --- Zertifikat --------------------------------------------------------
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
    final texts = available
        .where((t) =>
            t.source.kind != SourceKind.openFoodFacts ||
            supportedRuleLanguages.contains(t.lang))
        .toList();
    final unsupportedLanguage = available.isNotEmpty && texts.isEmpty;
    if (unsupportedLanguage) unknowns.add(UnknownReason.languageNotSupported);

    conditions[GreenCondition.ingredientListAvailable] = available.isNotEmpty;
    conditions[GreenCondition.databaseSource] = available.isNotEmpty &&
        available.every((t) => t.source.kind == SourceKind.openFoodFacts);

    final analyses = texts.map(analyzeText).toList();
    for (final a in analyses) {
      findings.addAll(a.findings);
      if (a.ingredientCount > count) count = a.ingredientCount;
      traces ??= a.tracesText;
    }
    if (analyses.any((a) => a.unbalancedBrackets)) {
      unknowns.add(UnknownReason.possiblyTruncated);
    }

    // Nicht unterstützte Sprache: strukturierte Datenbankanalyse nutzen.
    if (unsupportedLanguage && product != null && overrideTexts == null) {
      findings.addAll(analyzeStructured(product));
      count = product.allStructuredIngredients.length;
    }

    // Zusatzstoff-Tags der Quelle als Ergänzung (nur falls nicht im Text).
    if (product != null && overrideTexts == null) {
      final ruleIdsFound = findings.map((f) => f.ruleId).toSet();
      for (final tag in product.additiveTags) {
        final ruleId = additiveTagRules[tag.toLowerCase()];
        if (ruleId == null || ruleIdsFound.contains(ruleId)) continue;
        final code = tag.split(':').last.toUpperCase();
        findings.add(Finding(
          ruleId: ruleId,
          effect: RuleEffect.unclear,
          matchedText: code,
          ingredient: code,
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
      if (t.unsupportedScript) unknowns.add(UnknownReason.unsupportedScript);
    }

    // --- Recherche je kritischer Zutat --------------------------------------
    final allowed = {for (final r in ingredientRules) r.id: r.resolvedBy};
    final researched = <Finding>[];
    for (final f in findings) {
      if (f.effect == RuleEffect.info) {
        researched.add(f);
        continue;
      }
      final inv = _research.investigate(
        ResearchInput(
          ruleId: f.ruleId,
          effect: f.effect,
          matchedText: f.matchedText,
          ingredient: f.ingredient,
          qualifiers: f.qualifiers,
          allowedQualifiers: allowed[f.ruleId] ?? const {},
        ),
        ResearchContext(
          product: ctx.product ?? product,
          taxonomy: ctx.taxonomy,
          taxonomyStatus: ctx.taxonomyStatus,
        ),
      );
      investigations.add(inv);
      if (inv.labelContradiction) unknowns.add(UnknownReason.labelContradiction);
      if (inv.resolved) {
        final keys = inv.evidence
            .where((e) => e.strength == EvidenceStrength.productSpecific)
            .map((e) => e.key)
            .toList();
        final q = keys
            .where((k) => k.startsWith('qualifier.'))
            .map((k) => Qualifier.values.byName(k.substring(10)))
            .firstOrNull;
        researched.add(f.withResolution(q, keys.isEmpty ? const ['none'] : keys));
      } else {
        researched.add(f);
      }
    }
    findings = researched;
    if (investigations.any((i) =>
        i.steps.any((s) => s.outcome == StepOutcome.unavailable))) {
      unknowns.add(UnknownReason.researchSourceUnavailable);
    }

    // --- Widersprüche ---------------------------------------------------------
    var conflict = unknowns.contains(UnknownReason.labelContradiction);
    if (analyses.length > 1) {
      final haramSets = analyses
          .map((a) => a.findings
              .where((f) => f.effect == RuleEffect.haram)
              .map((f) => f.escalatedByPork ? 'pork' : f.ruleId)
              .toSet())
          .toList();
      final first = haramSets.first;
      if (haramSets.any((s) => s.length != first.length || !s.containsAll(first))) {
        conflict = true;
      }
    }
    final hasHaram = findings.any((f) => f.effect == RuleEffect.haram);
    if (hasHaram && validCert != null) conflict = true;
    if (conflict) unknowns.add(UnknownReason.conflictingSources);

    final hasUnclear =
        findings.any((f) => f.effect == RuleEffect.unclear && !f.isResolved);
    final disputed = investigations
        .any((i) => i.disputed && i.effect == RuleEffect.unclear);

    // --- Freigabebedingungen -----------------------------------------------
    conditions[GreenCondition.languageSupported] = !unsupportedLanguage &&
        !unknowns.contains(UnknownReason.languageMismatch) &&
        !unknowns.contains(UnknownReason.unsupportedScript);
    conditions[GreenCondition.listComplete] = available.isNotEmpty &&
        !unknowns.contains(UnknownReason.ingredientsIncomplete) &&
        !unknowns.contains(UnknownReason.possiblyTruncated) &&
        !unknowns.contains(UnknownReason.uncertainOcrText);
    conditions[GreenCondition.dataPlausible] = plausible;
    conditions[GreenCondition.noConflicts] = !conflict;
    conditions[GreenCondition.noProhibited] = !hasHaram;
    conditions[GreenCondition.allOriginsClarified] = !hasUnclear;
    conditions[GreenCondition.noDisputedSubstance] = !disputed;
    if (identity != IdentityStatus.confirmed) {
      conditions[GreenCondition.productIdentified] = false;
    }

    // --- Entscheidung --------------------------------------------------------
    if (available.isEmpty && validCert == null) {
      unknowns.add(UnknownReason.noIngredients);
      return result(HalalStatus.notVerified, Certainty.notAssessable);
    }
    if (conflict) {
      return result(HalalStatus.notVerified, Certainty.notAssessable);
    }
    if (hasHaram) {
      return result(HalalStatus.haram, Certainty.documented);
    }
    if (validCert != null) {
      unknowns.add(UnknownReason.manufacturingNotVerified);
      return result(HalalStatus.halalCertified, Certainty.documented);
    }
    if (hasUnclear) {
      return result(HalalStatus.unclear, Certainty.limited);
    }
    if (!conditions.values.every((v) => v)) {
      return result(HalalStatus.notVerified, Certainty.notAssessable);
    }
    unknowns.add(UnknownReason.manufacturingNotVerified);
    return result(HalalStatus.halalByIngredients, Certainty.limited);
  }
}
