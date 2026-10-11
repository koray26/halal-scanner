/// Getrennte Sachaussagen zu Schweinebestandteilen und Alkohol.
///
/// Diese Auswertung leitet sich ausschließlich aus einem bereits berechneten
/// [Verdict] ab. Sie verändert keine Halal-Regel und keinen Halal-Status.
///
/// Bedeutung der Zustände:
/// - [DimensionState.detected]: in den geprüften Daten ausdrücklich genannt.
/// - [DimensionState.notDetected]: in den geprüften Quellen NICHT gefunden –
///   das heißt nicht „garantiert nicht enthalten“ (nicht deklarierte
///   Hilfsstoffe, Trägerstoffe und Verunreinigungen sind nicht geprüft).
/// - [DimensionState.unresolved]: Daten fehlen, sind unvollständig oder eine
///   Zutat kann den Stoff enthalten, ohne dass die Herkunft belegt ist.
library;

import '../knowledge/substances.dart';
import '../research/research.dart';
import 'catalog.dart';
import 'halal_engine.dart';

enum DimensionState { detected, notDetected, unresolved }

/// Warum ein Ergebnis „ungeklärt“ ist (Übersetzungsschlüssel `dimension.reason.<name>`).
enum DimensionReason {
  /// Keine (auswertbare) Zutatenliste.
  noIngredients,

  /// Zutatenliste unvollständig, abgeschnitten, unsicher erkannt oder in
  /// nicht unterstützter Sprache.
  ingredientsIncomplete,

  /// Angaben widersprechen sich.
  conflicting,

  /// Mindestens eine Zutat kann den Stoff enthalten; Herkunft nicht belegt.
  possibleSource,
}

class DimensionResult {
  const DimensionResult(this.state,
      {this.ingredients = const [], this.reasons = const {}});
  final DimensionState state;

  /// Betroffene Zutaten im Wortlaut der Quelle.
  final List<String> ingredients;
  final Set<DimensionReason> reasons;
}

class SubstanceDimensions {
  const SubstanceDimensions({required this.pork, required this.alcohol});
  final DimensionResult pork;
  final DimensionResult alcohol;
}

/// Hinweise in den Daten, die eine vollständige Prüfung verhindern.
const _incompleteReasons = {
  UnknownReason.ingredientsIncomplete,
  UnknownReason.possiblyTruncated,
  UnknownReason.uncertainOcrText,
  UnknownReason.languageNotSupported,
  UnknownReason.languageLimited,
  UnknownReason.compositeUnspecified,
  UnknownReason.languageMismatch,
  UnknownReason.ingredientsMostlyUnrecognized,
  UnknownReason.unsupportedScript,
};

const _noDataReasons = {
  UnknownReason.productNotFound,
  UnknownReason.identityMismatch,
  UnknownReason.noIngredients,
};

const _alcoholHaramRules = {'alcoholic_beverage', 'alcohol_declared'};

/// Regeln, bei denen Restalkohol möglich ist, ohne dass ein Wert belegt ist.
const _alcoholPossibleRules = {'wine_vinegar', 'alcohol_free_beverage'};

SubstanceDimensions assessDimensions(Verdict v) => SubstanceDimensions(
      pork: _assess(
        v,
        detected: (f) =>
            f.effect == RuleEffect.haram &&
            (f.ruleId == 'pork' || f.escalatedByPork),
        possible: (i) {
          if (i.labelContradiction) return true;
          final open = i.openQuestions;
          final animalOpen = open.contains(OriginQuestion.animalSource) ||
              open.contains(OriginQuestion.animalSpecies);
          final porkPossible = i.possibleOrigins.contains(PossibleOrigin.pork) ||
              i.possibleOrigins.contains(PossibleOrigin.animal);
          return animalOpen && porkPossible;
        },
      ),
      alcohol: _assess(
        v,
        detected: (f) =>
            f.effect == RuleEffect.haram && _alcoholHaramRules.contains(f.ruleId),
        possible: (i) =>
            i.openQuestions.contains(OriginQuestion.alcohol) ||
            _alcoholPossibleRules.contains(i.ruleId),
      ),
    );

DimensionResult _assess(
  Verdict v, {
  required bool Function(Finding) detected,
  required bool Function(Investigation) possible,
}) {
  final conflicting = v.unknowns.contains(UnknownReason.conflictingSources);
  final hits = v.findings.where(detected).map((f) => f.matchedText).toSet();
  if (hits.isNotEmpty) {
    return DimensionResult(DimensionState.detected,
        ingredients: hits.toList(),
        reasons: {if (conflicting) DimensionReason.conflicting});
  }

  final reasons = <DimensionReason>{};
  if (v.checkedIngredientCount == 0 || v.unknowns.any(_noDataReasons.contains)) {
    reasons.add(DimensionReason.noIngredients);
  }
  if (v.unknowns.any(_incompleteReasons.contains)) {
    reasons.add(DimensionReason.ingredientsIncomplete);
  }
  if (conflicting) reasons.add(DimensionReason.conflicting);
  final candidates = v.investigations
      .where((i) => i.effect == RuleEffect.unclear && possible(i))
      .map((i) => i.originalText)
      .toSet();
  if (candidates.isNotEmpty) reasons.add(DimensionReason.possibleSource);

  if (reasons.isEmpty) return const DimensionResult(DimensionState.notDetected);
  return DimensionResult(DimensionState.unresolved,
      ingredients: candidates.toList(), reasons: reasons);
}
