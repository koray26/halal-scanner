/// Stoffwissen: Was ist ein Stoff, welche Herkünfte sind möglich und welche
/// Fragen müssen für eine Halal-Bewertung beantwortet werden?
///
/// Grundsatz: Dieses Wissen beschreibt nur, was ein Stoff GRUNDSÄTZLICH sein
/// kann. Es belegt NIE, woraus der Stoff in einem bestimmten Produkt besteht.
/// E-Nummern und Bezeichnungen folgen der EU-Verordnung (EG) Nr. 1333/2008.
library;

/// Prüffragen, die je nach Stoff offen sein können.
enum OriginQuestion {
  /// Stammt der Stoff von (Schlacht-)Tieren?
  animalSource,

  /// Von welcher Tierart (insbesondere: Schwein ausgeschlossen)?
  animalSpecies,

  /// Wurde das Tier nach islamischen Vorschriften geschlachtet?
  slaughter,

  /// Enthält der Stoff Alkohol (z. B. als Lösungs- oder Trägerstoff)?
  alcohol,

  /// Bewertung hängt von einer dokumentierten Meinungsverschiedenheit ab.
  /// Kann durch Produktdaten nicht beantwortet werden.
  scholarlyDispute,
}

/// Mögliche Herkünfte eines Stoffes (allgemein, nicht produktbezogen).
enum PossibleOrigin {
  plant,
  animal,
  pork,
  fish,
  dairy,
  insect,
  microbial,
  synthetic,
  mineral,
  alcoholSolvent,
}

class SubstanceProfile {
  const SubstanceProfile({
    required this.key,
    required this.functionClass,
    required this.possibleOrigins,
    required this.questions,
    this.offTaxonomyId,
  });

  /// Schlüssel für Texte: `substance.<key>.identity` / `.clarify`.
  final String key;

  /// Schlüssel für die Stoffklasse: `class.<functionClass>`.
  final String functionClass;
  final List<PossibleOrigin> possibleOrigins;
  final Set<OriginQuestion> questions;

  /// Kennung in der Open-Food-Facts-Taxonomie (für allgemeine Stoffinfos).
  final String? offTaxonomyId;
}

/// Profile je Regel (siehe catalog.dart).
const Map<String, SubstanceProfile> ruleProfiles = {
  'gelatine': SubstanceProfile(
    key: 'gelatine',
    functionClass: 'gelling',
    possibleOrigins: [PossibleOrigin.pork, PossibleOrigin.animal, PossibleOrigin.fish],
    questions: {OriginQuestion.animalSpecies, OriginQuestion.slaughter},
    offTaxonomyId: 'en:gelatin',
  ),
  'rennet': SubstanceProfile(
    key: 'rennet',
    functionClass: 'enzyme',
    possibleOrigins: [PossibleOrigin.animal, PossibleOrigin.microbial, PossibleOrigin.plant],
    questions: {OriginQuestion.animalSource, OriginQuestion.animalSpecies, OriginQuestion.slaughter},
    offTaxonomyId: 'en:rennet',
  ),
  'cheese': SubstanceProfile(
    key: 'cheese',
    functionClass: 'food',
    possibleOrigins: [PossibleOrigin.dairy, PossibleOrigin.animal, PossibleOrigin.microbial],
    questions: {OriginQuestion.animalSource, OriginQuestion.animalSpecies, OriginQuestion.slaughter},
    offTaxonomyId: 'en:cheese',
  ),
  'meat': SubstanceProfile(
    key: 'meat',
    functionClass: 'food',
    possibleOrigins: [PossibleOrigin.animal, PossibleOrigin.pork],
    questions: {OriginQuestion.animalSpecies, OriginQuestion.slaughter},
    offTaxonomyId: 'en:meat',
  ),
  'animal_fat': SubstanceProfile(
    key: 'animal_fat',
    functionClass: 'fat',
    possibleOrigins: [PossibleOrigin.animal, PossibleOrigin.pork],
    questions: {OriginQuestion.animalSpecies, OriginQuestion.slaughter},
    offTaxonomyId: 'en:animal-fat',
  ),
  'flavouring': SubstanceProfile(
    key: 'flavouring',
    functionClass: 'flavouring',
    possibleOrigins: [
      PossibleOrigin.plant,
      PossibleOrigin.animal,
      PossibleOrigin.dairy,
      PossibleOrigin.microbial,
      PossibleOrigin.synthetic,
      PossibleOrigin.alcoholSolvent,
    ],
    questions: {OriginQuestion.animalSource, OriginQuestion.alcohol},
    offTaxonomyId: 'en:flavouring',
  ),
  'e_number_animal_possible': SubstanceProfile(
    key: 'e_number_animal_possible',
    functionClass: 'additive',
    possibleOrigins: [PossibleOrigin.plant, PossibleOrigin.animal, PossibleOrigin.pork, PossibleOrigin.synthetic],
    questions: {OriginQuestion.animalSource, OriginQuestion.animalSpecies, OriginQuestion.slaughter},
  ),
  'bone_phosphate': SubstanceProfile(
    key: 'bone_phosphate',
    functionClass: 'additive',
    possibleOrigins: [PossibleOrigin.animal, PossibleOrigin.pork],
    questions: {OriginQuestion.animalSpecies, OriginQuestion.slaughter},
    offTaxonomyId: 'en:e542',
  ),
  'insect_derived': SubstanceProfile(
    key: 'insect_derived',
    functionClass: 'colour',
    possibleOrigins: [PossibleOrigin.insect],
    questions: {OriginQuestion.scholarlyDispute},
  ),
  'seafood_non_fish': SubstanceProfile(
    key: 'seafood_non_fish',
    functionClass: 'food',
    possibleOrigins: [PossibleOrigin.animal],
    questions: {OriginQuestion.scholarlyDispute},
  ),
  'wine_vinegar': SubstanceProfile(
    key: 'wine_vinegar',
    functionClass: 'food',
    possibleOrigins: [PossibleOrigin.plant],
    questions: {OriginQuestion.scholarlyDispute},
    offTaxonomyId: 'en:wine-vinegar',
  ),
  'alcohol_free_beverage': SubstanceProfile(
    key: 'alcohol_free_beverage',
    functionClass: 'food',
    possibleOrigins: [PossibleOrigin.plant],
    questions: {OriginQuestion.alcohol, OriginQuestion.scholarlyDispute},
  ),
};

/// Zusatzstoffe mit möglicher tierischer oder strittiger Herkunft.
class Additive {
  const Additive(this.number, this.de, this.en, this.functionClass,
      {this.wikidata});
  final String number; // z. B. "471", "472e"
  final String de;
  final String en;
  final String functionClass;
  final String? wikidata;

  String get code => 'E$number';
  String get offId => 'en:e${number.toLowerCase()}';
}

const List<Additive> additives = [
  Additive('120', 'Echtes Karmin / Cochenille', 'Carmine / cochineal', 'colour', wikidata: 'Q416860'),
  Additive('422', 'Glycerin', 'Glycerol', 'humectant'),
  Additive('428', 'Gelatine', 'Gelatine', 'gelling'),
  Additive('430', 'Polyoxyethylen(8)stearat', 'Polyoxyethylene (8) stearate', 'emulsifier'),
  Additive('431', 'Polyoxyethylen(40)stearat', 'Polyoxyethylene (40) stearate', 'emulsifier'),
  Additive('432', 'Polysorbat 20', 'Polysorbate 20', 'emulsifier'),
  Additive('433', 'Polysorbat 80', 'Polysorbate 80', 'emulsifier'),
  Additive('434', 'Polysorbat 40', 'Polysorbate 40', 'emulsifier'),
  Additive('435', 'Polysorbat 60', 'Polysorbate 60', 'emulsifier'),
  Additive('436', 'Polysorbat 65', 'Polysorbate 65', 'emulsifier'),
  Additive('441', 'Gelatine (alte Nummer)', 'Gelatine (former number)', 'gelling'),
  Additive('470a', 'Natrium-, Kalium- und Calciumsalze von Speisefettsäuren', 'Sodium, potassium and calcium salts of fatty acids', 'emulsifier'),
  Additive('470b', 'Magnesiumsalze von Speisefettsäuren', 'Magnesium salts of fatty acids', 'emulsifier'),
  Additive('471', 'Mono- und Diglyceride von Speisefettsäuren', 'Mono- and diglycerides of fatty acids', 'emulsifier', wikidata: 'Q416711'),
  Additive('472a', 'Essigsäureester von Mono- und Diglyceriden', 'Acetic acid esters of mono- and diglycerides', 'emulsifier'),
  Additive('472b', 'Milchsäureester von Mono- und Diglyceriden', 'Lactic acid esters of mono- and diglycerides', 'emulsifier'),
  Additive('472c', 'Citronensäureester von Mono- und Diglyceriden', 'Citric acid esters of mono- and diglycerides', 'emulsifier'),
  Additive('472d', 'Weinsäureester von Mono- und Diglyceriden', 'Tartaric acid esters of mono- and diglycerides', 'emulsifier'),
  Additive('472e', 'Mono- und Diacetylweinsäureester von Mono- und Diglyceriden', 'Mono- and diacetyl tartaric acid esters of mono- and diglycerides', 'emulsifier'),
  Additive('472f', 'Gemischte Wein- und Essigsäureester von Mono- und Diglyceriden', 'Mixed acetic and tartaric acid esters of mono- and diglycerides', 'emulsifier'),
  Additive('473', 'Zuckerester von Speisefettsäuren', 'Sucrose esters of fatty acids', 'emulsifier'),
  Additive('474', 'Zuckerglyceride', 'Sucroglycerides', 'emulsifier'),
  Additive('475', 'Polyglycerinester von Speisefettsäuren', 'Polyglycerol esters of fatty acids', 'emulsifier'),
  Additive('477', 'Propylenglycolester von Speisefettsäuren', 'Propane-1,2-diol esters of fatty acids', 'emulsifier'),
  Additive('478', 'Lactylierte Fettsäureester', 'Lactylated fatty acid esters', 'emulsifier'),
  Additive('481', 'Natriumstearoyl-2-lactylat', 'Sodium stearoyl-2-lactylate', 'emulsifier'),
  Additive('482', 'Calciumstearoyl-2-lactylat', 'Calcium stearoyl-2-lactylate', 'emulsifier'),
  Additive('483', 'Stearyltartrat', 'Stearyl tartrate', 'emulsifier'),
  Additive('491', 'Sorbitanmonostearat', 'Sorbitan monostearate', 'emulsifier'),
  Additive('492', 'Sorbitantristearat', 'Sorbitan tristearate', 'emulsifier'),
  Additive('493', 'Sorbitanmonolaurat', 'Sorbitan monolaurate', 'emulsifier'),
  Additive('494', 'Sorbitanmonooleat', 'Sorbitan monooleate', 'emulsifier'),
  Additive('495', 'Sorbitanmonopalmitat', 'Sorbitan monopalmitate', 'emulsifier'),
  Additive('542', 'Knochenphosphat', 'Bone phosphate', 'additive'),
  Additive('570', 'Fettsäuren (z. B. Stearinsäure)', 'Fatty acids (e.g. stearic acid)', 'additive'),
  Additive('572', 'Magnesiumsalze der Speisefettsäuren (Magnesiumstearat)', 'Magnesium salts of fatty acids (magnesium stearate)', 'additive'),
  Additive('627', 'Dinatriumguanylat', 'Disodium guanylate', 'flavourEnhancer'),
  Additive('631', 'Dinatriuminosinat', 'Disodium inosinate', 'flavourEnhancer'),
  Additive('635', "Dinatrium-5'-ribonukleotid", "Disodium 5'-ribonucleotides", 'flavourEnhancer'),
  Additive('904', 'Schellack', 'Shellac', 'glazing'),
  Additive('920', 'L-Cystein', 'L-cysteine', 'flourTreatment'),
  Additive('921', 'L-Cystin', 'L-cystine', 'flourTreatment'),
];

final Map<String, Additive> additivesByNumber = {
  for (final a in additives) a.number: a,
};

final _eRegex = RegExp(r'(?<![\p{L}\p{N}])e\s?-?(\d{3,4}[a-f]?)(?![\p{N}])',
    caseSensitive: false, unicode: true);

/// Findet die erste bekannte E-Nummer in einem Text.
Additive? findAdditive(String text) {
  for (final m in _eRegex.allMatches(text)) {
    final a = additivesByNumber[m.group(1)!.toLowerCase()];
    if (a != null) return a;
  }
  return null;
}

/// Ordnet Klartextnamen einer E-Nummer zu (für Fälle wie "Mono- und
/// Diglyceride von Speisefettsäuren" ohne Nummer).
final List<(RegExp, String)> additiveNamePatterns = [
  (RegExp(r'mono\p{L}*[- ]*(?:und|and|et|ve|y|e)?\s*di\p{L}*glycerid', caseSensitive: false, unicode: true), '471'),
  (RegExp(r'diacetylweins|diacetyl\s*tartaric', caseSensitive: false, unicode: true), '472e'),
  (RegExp(r'citronensäureester|citric\s+acid\s+esters', caseSensitive: false, unicode: true), '472c'),
  (RegExp(r'milchsäureester|lactic\s+acid\s+esters', caseSensitive: false, unicode: true), '472b'),
  (RegExp(r'polysorbat\p{L}*\s*80', caseSensitive: false, unicode: true), '433'),
  (RegExp(r'stearoyl\p{L}*lactylat', caseSensitive: false, unicode: true), '481'),
  (RegExp(r'magnesiumstearat|magnesium\s+stearate', caseSensitive: false, unicode: true), '572'),
  (RegExp(r'stearinsäure|stearic\s+acid', caseSensitive: false, unicode: true), '570'),
  (RegExp(r'glycerin|glycerol|glycérine|gliserin', caseSensitive: false, unicode: true), '422'),
  (RegExp(r'l-?cystein|l-?cysteine', caseSensitive: false, unicode: true), '920'),
  (RegExp(r'karmin|carmine?|cochenille|cochineal', caseSensitive: false, unicode: true), '120'),
  (RegExp(r'schellack|shellac|gomme[- ]laque', caseSensitive: false, unicode: true), '904'),
  (RegExp(r'inosinat|inosinate', caseSensitive: false, unicode: true), '631'),
  (RegExp(r'guanylat|guanylate', caseSensitive: false, unicode: true), '627'),
  (RegExp(r'knochenphosphat|bone\s+phosphate', caseSensitive: false, unicode: true), '542'),
];

Additive? identifyAdditive(String text) {
  final byNumber = findAdditive(text);
  if (byNumber != null) return byNumber;
  for (final (re, number) in additiveNamePatterns) {
    if (re.hasMatch(text)) return additivesByNumber[number];
  }
  return null;
}
