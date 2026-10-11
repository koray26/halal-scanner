/// Mehrstufige Recherche für jede kritische Zutat.
///
/// Ablauf je Zutat:
///  1. Stoffidentität (Name, Synonyme, E-Nummer, Stoffklasse)
///  2. Strukturierte Zutatendaten des Produkts (Open Food Facts)
///  3. Herkunftsangaben in der Zutatenliste selbst (z. B. "pflanzlich")
///  4. Kennzeichnungen der Verpackung laut Datenbank (vegan/vegetarisch)
///  5. Allgemeine Stoffinformation (Open-Food-Facts-Taxonomie, online)
///  6. Herstellerinformation (Link laut Datenbank)
///  7. Entscheidung: Jede Prüffrage gilt nur als beantwortet, wenn ein
///     PRODUKTBEZOGENER Beleg vorliegt. Allgemeine Stoffinformationen und
///     Nutzerhinweise beantworten nie eine Prüffrage.
library;

import '../knowledge/substances.dart';
import '../models.dart';
import '../rules/catalog.dart';

enum QuestionState { open, answeredNo, answeredYes, notApplicable }

/// Wie stark ein Beleg ist.
enum EvidenceStrength {
  /// Angabe zu genau diesem Produkt (Zutatenliste, Verpackungskennzeichnung).
  productSpecific,

  /// Allgemeines Stoffwissen – gilt nicht automatisch für dieses Produkt.
  general,
}

enum EvidenceKind {
  ingredientText,
  productLabel,
  structuredIngredient,
  additiveIdentity,
  taxonomy,
  manufacturer,
}

class Evidence {
  const Evidence({
    required this.kind,
    required this.strength,
    required this.key,
    this.params = const {},
    this.url,
    this.answers = const {},
  });

  final EvidenceKind kind;
  final EvidenceStrength strength;

  /// Übersetzungsschlüssel `evidence.<key>`.
  final String key;
  final Map<String, String> params;
  final String? url;

  /// Welche Prüffragen dieser Beleg beantwortet (nur bei productSpecific).
  final Map<OriginQuestion, QuestionState> answers;

  Map<String, dynamic> toJson() => {
        'kind': kind.name,
        'strength': strength.name,
        'key': key,
        'params': params,
        'url': url,
        'answers': answers.map((k, v) => MapEntry(k.name, v.name)),
      };

  factory Evidence.fromJson(Map<String, dynamic> j) => Evidence(
        kind: EvidenceKind.values.byName(j['kind'] as String),
        strength: EvidenceStrength.values.byName(j['strength'] as String),
        key: j['key'] as String,
        params: ((j['params'] as Map?) ?? const {})
            .map((k, v) => MapEntry(k as String, v as String)),
        url: j['url'] as String?,
        answers: ((j['answers'] as Map?) ?? const {}).map((k, v) => MapEntry(
            OriginQuestion.values.byName(k as String),
            QuestionState.values.byName(v as String))),
      );
}

enum StepKind {
  identity,
  productIngredients,
  ingredientText,
  productLabels,
  taxonomy,
  manufacturer,
}

enum StepOutcome {
  /// Informationen gefunden.
  found,

  /// Geprüft, aber nichts Passendes gefunden.
  nothingFound,

  /// Quelle war nicht erreichbar (z. B. offline) – NICHT geprüft.
  unavailable,

  /// Schritt war nicht möglich (z. B. kein Produktdatensatz).
  notPossible,
}

class ResearchStep {
  const ResearchStep(this.kind, this.outcome, {this.detail = const {}});
  final StepKind kind;
  final StepOutcome outcome;
  final Map<String, String> detail;

  Map<String, dynamic> toJson() =>
      {'kind': kind.name, 'outcome': outcome.name, 'detail': detail};

  factory ResearchStep.fromJson(Map<String, dynamic> j) => ResearchStep(
        StepKind.values.byName(j['kind'] as String),
        StepOutcome.values.byName(j['outcome'] as String),
        detail: ((j['detail'] as Map?) ?? const {})
            .map((k, v) => MapEntry(k as String, v as String)),
      );
}

/// Allgemeiner Eintrag der Open-Food-Facts-Taxonomie.
class TaxonomyEntry {
  const TaxonomyEntry({
    required this.id,
    this.names = const {},
    this.vegan,
    this.vegetarian,
    this.description,
    this.wikidata,
  });
  final String id;
  final Map<String, String> names;
  final String? vegan;
  final String? vegetarian;
  final String? description;
  final String? wikidata;

  Map<String, dynamic> toJson() => {
        'id': id,
        'names': names,
        'vegan': vegan,
        'vegetarian': vegetarian,
        'description': description,
        'wikidata': wikidata,
      };

  factory TaxonomyEntry.fromJson(Map<String, dynamic> j) => TaxonomyEntry(
        id: j['id'] as String,
        names: ((j['names'] as Map?) ?? const {})
            .map((k, v) => MapEntry(k as String, v as String)),
        vegan: j['vegan'] as String?,
        vegetarian: j['vegetarian'] as String?,
        description: j['description'] as String?,
        wikidata: j['wikidata'] as String?,
      );
}

enum OnlineSourceStatus {
  /// Nicht abgefragt (z. B. keine unklaren Zutaten oder Foto ohne Netz).
  notRequested,
  ok,

  /// Abfrage versucht, aber fehlgeschlagen (offline, Zeitüberschreitung, Limit).
  unavailable,
}

class ResearchContext {
  const ResearchContext({
    this.product,
    this.taxonomy = const {},
    this.taxonomyStatus = OnlineSourceStatus.notRequested,
  });
  final ProductRecord? product;
  final Map<String, TaxonomyEntry> taxonomy;
  final OnlineSourceStatus taxonomyStatus;
}

class Investigation {
  const Investigation({
    required this.ruleId,
    required this.effect,
    required this.originalText,
    required this.ingredient,
    required this.questions,
    required this.evidence,
    required this.steps,
    this.additiveCode,
    this.additiveName,
    this.functionClass,
    this.possibleOrigins = const [],
    this.offIngredientId,
    this.labelContradiction = false,
  });

  final String ruleId;
  final RuleEffect effect;

  /// Wortlaut aus der Zutatenliste.
  final String originalText;
  final String ingredient;
  final String? additiveCode;

  /// Normalisierter Name (deutsch/englisch) der E-Nummer, falls bekannt.
  final String? additiveName;
  final String? functionClass;
  final List<PossibleOrigin> possibleOrigins;
  final Map<OriginQuestion, QuestionState> questions;
  final List<Evidence> evidence;
  final List<ResearchStep> steps;
  final String? offIngredientId;

  /// Verpackungskennzeichnung widerspricht der Zutat (z. B. vegan + Gelatine).
  final bool labelContradiction;

  List<OriginQuestion> get openQuestions => questions.entries
      .where((e) => e.value == QuestionState.open)
      .map((e) => e.key)
      .toList();

  bool get disputed => questions.containsKey(OriginQuestion.scholarlyDispute);

  /// Alle Prüffragen produktbezogen beantwortet und keine strittige Bewertung.
  bool get resolved =>
      effect == RuleEffect.unclear && openQuestions.isEmpty && !labelContradiction;

  Map<String, dynamic> toJson() => {
        'ruleId': ruleId,
        'effect': effect.name,
        'originalText': originalText,
        'ingredient': ingredient,
        'additiveCode': additiveCode,
        'additiveName': additiveName,
        'functionClass': functionClass,
        'possibleOrigins': possibleOrigins.map((e) => e.name).toList(),
        'questions': questions.map((k, v) => MapEntry(k.name, v.name)),
        'evidence': evidence.map((e) => e.toJson()).toList(),
        'steps': steps.map((e) => e.toJson()).toList(),
        'offIngredientId': offIngredientId,
        'labelContradiction': labelContradiction,
      };

  factory Investigation.fromJson(Map<String, dynamic> j) => Investigation(
        ruleId: j['ruleId'] as String,
        effect: RuleEffect.values.byName(j['effect'] as String),
        originalText: j['originalText'] as String,
        ingredient: j['ingredient'] as String,
        additiveCode: j['additiveCode'] as String?,
        additiveName: j['additiveName'] as String?,
        functionClass: j['functionClass'] as String?,
        possibleOrigins: ((j['possibleOrigins'] as List?) ?? const [])
            .map((e) => PossibleOrigin.values.byName(e as String))
            .toList(),
        questions: ((j['questions'] as Map?) ?? const {}).map((k, v) => MapEntry(
            OriginQuestion.values.byName(k as String),
            QuestionState.values.byName(v as String))),
        evidence: ((j['evidence'] as List?) ?? const [])
            .map((e) => Evidence.fromJson(e as Map<String, dynamic>))
            .toList(),
        steps: ((j['steps'] as List?) ?? const [])
            .map((e) => ResearchStep.fromJson(e as Map<String, dynamic>))
            .toList(),
        offIngredientId: j['offIngredientId'] as String?,
        labelContradiction: j['labelContradiction'] as bool? ?? false,
      );
}

/// Eingabe für eine Untersuchung (unabhängig von der Finding-Klasse).
class ResearchInput {
  const ResearchInput({
    required this.ruleId,
    required this.effect,
    required this.matchedText,
    required this.ingredient,
    required this.qualifiers,
    this.allowedQualifiers = const {},
  });
  final String ruleId;
  final RuleEffect effect;
  final String matchedText;
  final String ingredient;

  /// Herkunftsangaben im Kontext dieser Zutat (aus der Zutatenliste).
  final Set<Qualifier> qualifiers;

  /// Welche Herkunftsangaben bei dieser Regel als Beleg zählen dürfen.
  final Set<Qualifier> allowedQualifiers;
}

class ResearchPipeline {
  const ResearchPipeline();

  /// Regeln, bei denen ein Vegetarisch-Label tierische Schlachtprodukte ausschließt.
  static const _vegetarianExcludes = {
    'rennet',
    'cheese',
    'animal_fat',
    'e_number_animal_possible',
    'bone_phosphate',
    'flavouring',
  };

  /// Regeln, bei denen Vegan-/Vegetarisch-Label der Zutat widersprechen.
  static const _labelContradicts = {'gelatine', 'meat', 'bone_phosphate'};

  Investigation investigate(ResearchInput f, ResearchContext ctx) {
    final profile = ruleProfiles[f.ruleId];
    final steps = <ResearchStep>[];
    final evidence = <Evidence>[];
    final questions = <OriginQuestion, QuestionState>{
      for (final q in profile?.questions ?? const <OriginQuestion>{})
        q: QuestionState.open,
    };
    final product = ctx.product;

    void answer(Map<OriginQuestion, QuestionState> a) {
      a.forEach((q, s) {
        if (questions[q] == QuestionState.open) questions[q] = s;
      });
      // Kein tierischer Ursprung -> Tierart und Schlachtung entfallen.
      if (questions[OriginQuestion.animalSource] == QuestionState.answeredNo) {
        for (final q in [OriginQuestion.animalSpecies, OriginQuestion.slaughter]) {
          if (questions[q] == QuestionState.open) {
            questions[q] = QuestionState.notApplicable;
          }
        }
      }
    }

    // 1. Identität ----------------------------------------------------------
    final additive = identifyAdditive(f.ingredient) ?? identifyAdditive(f.matchedText);
    steps.add(ResearchStep(StepKind.identity,
        additive != null || profile != null ? StepOutcome.found : StepOutcome.nothingFound,
        detail: {
          if (additive != null) 'code': additive.code,
          if (additive != null) 'name': additive.de,
        }));
    if (additive != null) {
      evidence.add(Evidence(
        kind: EvidenceKind.additiveIdentity,
        strength: EvidenceStrength.general,
        key: 'additive',
        params: {'code': additive.code, 'name': additive.de, 'nameEn': additive.en},
        url: additive.wikidata == null
            ? null
            : 'https://www.wikidata.org/wiki/${additive.wikidata}',
      ));
    }

    // 2. Strukturierte Zutatendaten des Produkts -----------------------------
    OffIngredient? node;
    if (product == null || product.structuredIngredients.isEmpty) {
      steps.add(const ResearchStep(StepKind.productIngredients, StepOutcome.notPossible));
    } else {
      node = _findNode(product, f, additive);
      if (node == null) {
        steps.add(const ResearchStep(StepKind.productIngredients, StepOutcome.nothingFound));
      } else {
        final sub = node.children.map((c) => c.text).where((t) => t.isNotEmpty).join(', ');
        steps.add(ResearchStep(StepKind.productIngredients, StepOutcome.found, detail: {
          'id': node.id,
          if (node.vegan != null) 'vegan': node.vegan!,
          if (sub.isNotEmpty) 'sub': sub,
        }));
        evidence.add(Evidence(
          kind: EvidenceKind.structuredIngredient,
          strength: EvidenceStrength.general,
          key: 'structured',
          params: {'id': node.id, 'vegan': node.vegan ?? '?', 'vegetarian': node.vegetarian ?? '?'},
          url: product.source.url,
        ));
      }
    }

    // 3. Herkunftsangaben in der Zutatenliste (produktbezogen) ---------------
    final usable = f.qualifiers.where(f.allowedQualifiers.contains).toList();
    if (f.effect == RuleEffect.unclear && usable.isNotEmpty) {
      for (final q in usable) {
        final a = _qualifierAnswers(q);
        evidence.add(Evidence(
          kind: EvidenceKind.ingredientText,
          strength: EvidenceStrength.productSpecific,
          key: 'qualifier.${q.name}',
          params: {'ingredient': f.ingredient},
          url: product?.source.url,
          answers: a,
        ));
        answer(a);
      }
      steps.add(ResearchStep(StepKind.ingredientText, StepOutcome.found,
          detail: {'qualifiers': usable.map((q) => q.name).join(',')}));
    } else {
      steps.add(const ResearchStep(StepKind.ingredientText, StepOutcome.nothingFound));
    }

    // 4. Verpackungskennzeichnung laut Datenbank -----------------------------
    var contradiction = false;
    if (product == null) {
      steps.add(const ResearchStep(StepKind.productLabels, StepOutcome.notPossible));
    } else {
      final labels = product.labelTags.map((t) => t.toLowerCase()).toSet();
      final vegan = labels.contains('en:vegan');
      final vegetarian = vegan || labels.contains('en:vegetarian');
      if (vegetarian && f.effect != RuleEffect.info) {
        if (_labelContradicts.contains(f.ruleId) || f.effect == RuleEffect.haram) {
          contradiction = true;
          evidence.add(Evidence(
            kind: EvidenceKind.productLabel,
            strength: EvidenceStrength.productSpecific,
            key: 'labelContradiction',
            params: {'label': vegan ? 'vegan' : 'vegetarisch'},
            url: product.source.url,
          ));
        } else if (vegan || _vegetarianExcludes.contains(f.ruleId)) {
          final a = {OriginQuestion.animalSource: QuestionState.answeredNo};
          evidence.add(Evidence(
            kind: EvidenceKind.productLabel,
            strength: EvidenceStrength.productSpecific,
            key: vegan ? 'labelVegan' : 'labelVegetarian',
            url: product.source.url,
            answers: a,
          ));
          answer(a);
        }
        steps.add(ResearchStep(StepKind.productLabels, StepOutcome.found,
            detail: {'label': vegan ? 'en:vegan' : 'en:vegetarian'}));
      } else {
        steps.add(const ResearchStep(StepKind.productLabels, StepOutcome.nothingFound));
      }
    }

    // 5. Allgemeine Stoffinformation (Taxonomie) -----------------------------
    final taxId = (node != null && node.id.startsWith('en:') && node.inTaxonomy)
        ? node.id
        : additive?.offId ?? profile?.offTaxonomyId;
    if (taxId == null) {
      steps.add(const ResearchStep(StepKind.taxonomy, StepOutcome.notPossible));
    } else {
      switch (ctx.taxonomyStatus) {
        case OnlineSourceStatus.unavailable:
          steps.add(ResearchStep(StepKind.taxonomy, StepOutcome.unavailable, detail: {'id': taxId}));
        case OnlineSourceStatus.notRequested:
          steps.add(ResearchStep(StepKind.taxonomy, StepOutcome.notPossible, detail: {'id': taxId}));
        case OnlineSourceStatus.ok:
          final e = ctx.taxonomy[taxId];
          if (e == null) {
            steps.add(ResearchStep(StepKind.taxonomy, StepOutcome.nothingFound, detail: {'id': taxId}));
          } else {
            steps.add(ResearchStep(StepKind.taxonomy, StepOutcome.found, detail: {
              'id': taxId,
              if (e.vegan != null) 'vegan': e.vegan!,
              if (e.vegetarian != null) 'vegetarian': e.vegetarian!,
            }));
            evidence.add(Evidence(
              kind: EvidenceKind.taxonomy,
              strength: EvidenceStrength.general,
              key: 'taxonomy',
              params: {
                'id': taxId,
                'name': e.names['de'] ?? e.names['en'] ?? taxId,
                'vegan': e.vegan ?? '?',
                'vegetarian': e.vegetarian ?? '?',
              },
              url: e.wikidata != null
                  ? 'https://www.wikidata.org/wiki/${e.wikidata}'
                  : 'https://world.openfoodfacts.org/facets/ingredients/${taxId.substring(3)}',
            ));
          }
      }
    }

    // 6. Herstellerinformation ----------------------------------------------
    final link = product?.manufacturerLink?.trim();
    if (product == null) {
      steps.add(const ResearchStep(StepKind.manufacturer, StepOutcome.notPossible));
    } else if (link != null && link.startsWith('http')) {
      steps.add(ResearchStep(StepKind.manufacturer, StepOutcome.found, detail: {'url': link}));
      evidence.add(Evidence(
        kind: EvidenceKind.manufacturer,
        strength: EvidenceStrength.general,
        key: 'manufacturerLink',
        url: link,
      ));
    } else {
      steps.add(const ResearchStep(StepKind.manufacturer, StepOutcome.nothingFound));
    }

    return Investigation(
      ruleId: f.ruleId,
      effect: f.effect,
      originalText: f.matchedText,
      ingredient: f.ingredient,
      additiveCode: additive?.code,
      additiveName: additive?.de,
      functionClass: additive?.functionClass ?? profile?.functionClass,
      possibleOrigins: profile?.possibleOrigins ?? const [],
      questions: questions,
      evidence: evidence,
      steps: steps,
      offIngredientId: node?.id,
      labelContradiction: contradiction,
    );
  }

  static Map<OriginQuestion, QuestionState> _qualifierAnswers(Qualifier q) => switch (q) {
        Qualifier.plant || Qualifier.synthetic || Qualifier.nonAnimalEnzyme => {
            OriginQuestion.animalSource: QuestionState.answeredNo,
          },
        Qualifier.fish => {
            OriginQuestion.animalSource: QuestionState.answeredYes,
            OriginQuestion.animalSpecies: QuestionState.answeredNo,
            OriginQuestion.slaughter: QuestionState.notApplicable,
          },
        Qualifier.halalStated => {
            OriginQuestion.animalSource: QuestionState.notApplicable,
            OriginQuestion.animalSpecies: QuestionState.answeredNo,
            OriginQuestion.slaughter: QuestionState.answeredYes,
            OriginQuestion.alcohol: QuestionState.answeredNo,
          },
        Qualifier.alcoholFree => {OriginQuestion.alcohol: QuestionState.answeredNo},
        Qualifier.porcine => const {},
      };

  OffIngredient? _findNode(ProductRecord p, ResearchInput f, Additive? additive) {
    final needle = f.matchedText.toLowerCase().trim();
    final head = f.ingredient.toLowerCase().split('(').first.trim();
    OffIngredient? best;
    for (final n in p.allStructuredIngredients) {
      final t = n.text.toLowerCase().trim();
      if (additive != null && n.id == additive.offId) return n;
      if (t == head || t == needle) return n;
      if (best == null && t.isNotEmpty && (t.contains(needle) || head.contains(t))) {
        best = n;
      }
    }
    return best;
  }
}
