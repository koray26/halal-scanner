/// Versionierter Regelkatalog für die Zutatenprüfung.
///
/// WICHTIG: Diese Regeln sind eine technische Umsetzung vorsichtiger,
/// verbreiteter Bewertungsgrundsätze. Sie ersetzen keine religiöse
/// Fachprüfung. Siehe docs/HALAL_REGELN.md.
///
/// Grundsatz: Strittige oder ungeklärte Stoffe -> UNKLAR, nicht HARAM.
/// HARAM nur bei ausdrücklich genanntem verbotenem Bestandteil.
library;

const String rulesetVersion = '2026.10-1';

/// Sprachen, für die die Wortlisten gepflegt sind. Zutatenlisten in anderen
/// Sprachen werden nicht ausgewertet (-> NICHT VERIFIZIERT).
const Set<String> supportedRuleLanguages = {'de', 'en', 'fr', 'tr'};

enum RuleEffect {
  /// Ausdrücklich verbotener Bestandteil.
  haram,

  /// Herkunft/Herstellung ungeklärt oder Bewertung strittig.
  unclear,

  /// Nur Hinweis, beeinflusst das Ergebnis nicht.
  info,
}

/// Herkunftsangaben, die im Kontext einer Zutat gefunden werden können.
enum Qualifier { porcine, fish, plant, nonAnimalEnzyme, synthetic, halalStated }

class IngredientRule {
  const IngredientRule({
    required this.id,
    required this.effect,
    required this.patterns,
    this.exclusions = const [],
    this.resolvedBy = const {},
    this.escalateOnPork = false,
    this.suppressedBy = const {},
  });

  final String id;
  final RuleEffect effect;

  /// Regex-Kerne; werden mit Wortgrenzen kombiniert (siehe [word]).
  final List<String> patterns;

  /// Wenn eine dieser Regexes im Umfeld des Treffers passt, zählt er nicht.
  final List<String> exclusions;

  /// Herkunftsangaben, die die Unklarheit auflösen (z. B. "pflanzlich").
  final Set<Qualifier> resolvedBy;

  /// "vom Schwein" im Kontext macht aus UNKLAR ein belegtes HARAM.
  final bool escalateOnPork;

  /// Trifft eine dieser Regeln auf denselben Bestandteil zu, entfällt diese.
  final Set<String> suppressedBy;
}

/// Ganzwort-Treffer, Unicode-fähig (Umlaute, arabische Schrift).
String word(String core) =>
    r'(?<![\p{L}\p{N}])(?:' + core + r')(?![\p{L}\p{N}])';

const _l = r'\p{L}*';

final Map<Qualifier, List<String>> qualifierPatterns = {
  Qualifier.porcine: _porkCores,
  Qualifier.fish: [
    '${_l}fisch$_l',
    'fish',
    'poisson',
    'balık',
    'pescado',
    'pesce',
    'ikan',
  ],
  Qualifier.plant: [
    'pflanzlich$_l',
    'vegetabil$_l',
    'vegetables?',
    r'plant(?:[- ]based)?',
    'végétale?s?',
    'vegetal(?:es)?',
    'bitkisel',
    'vegan$_l',
    r'aus\s+(?:raps|sonnenblumen?|palm|soja|kokos|mais)$_l',
    r'from\s+(?:rapeseed|sunflower|palm|soy|soya|coconut|corn|maize)$_l',
    r'de\s+(?:colza|tournesol|palme|soja)',
  ],
  Qualifier.nonAnimalEnzyme: [
    'mikrobiell$_l',
    'microbial',
    'microbien$_l',
    'mikrobiyal',
    'vegetarisch$_l',
    'vegetarian',
    'végétarien$_l',
  ],
  Qualifier.synthetic: ['synthetisch$_l', 'synthetic', 'synthétique'],
  Qualifier.halalStated: ['halal', 'helal', 'حلال'],
};

const List<String> _porkCores = [
  '${_l}schwein$_l',
  'pork',
  'porcine?',
  'pigs?',
  'swine',
  'porc',
  'porcin(?:e|es)?',
  'domuz$_l',
  'cerdo',
  'porcino',
  'suino',
  'maiale',
  'varken$_l',
  'babi',
  'lard',
  'lardo',
  'saindoux',
  '${_l}خنزير$_l',
];

const _cheeseOrRennetResolvers = {
  Qualifier.nonAnimalEnzyme,
  Qualifier.plant,
  Qualifier.halalStated,
};

const List<IngredientRule> ingredientRules = [
  // ---------------- HARAM: ausdrücklich genannte verbotene Bestandteile ----
  IngredientRule(
    id: 'pork',
    effect: RuleEffect.haram,
    patterns: _porkCores,
    exclusions: [r'meerschwein'],
  ),
  IngredientRule(
    id: 'blood',
    effect: RuleEffect.haram,
    patterns: [
      'blut',
      'blutplasma',
      '${_l}blutwurst',
      r'blood(?!\s*oranges?)(?:\s*plasma)?',
      r'sang(?!\s*de\s*dragon)',
      'boudin noir',
    ],
    exclusions: [r'blutorange'],
  ),
  IngredientRule(
    id: 'alcoholic_beverage',
    effect: RuleEffect.haram,
    patterns: [
      // Deutsch: Wörter mit "wein" (Rotwein, Weinsauce …), Ausnahmen unten
      '${_l}wein$_l',
      'weinbrand',
      '${_l}bier',
      '${_l}likör',
      '${_l}likoer',
      'rum',
      'whiske?y',
      'wodka',
      'vodka',
      'cognac',
      'kognak',
      'sekt',
      'champagner',
      'sherry',
      'marsala',
      'grappa',
      'kirschwasser',
      'obstbrand',
      'gin',
      // Englisch
      r'(?:red\s+|white\s+|cooking\s+|rice\s+|fortified\s+)?wines?',
      'beers?',
      'liqueurs?',
      'liquors?',
      'brandy',
      'champagne',
      'mirin',
      'sake',
      // Französisch / Türkisch / Spanisch / Italienisch
      'vins?',
      'bières?',
      'rhum',
      'eau[- ]de[- ]vie',
      'calvados',
      'şarap',
      'bira',
      'rakı',
      'vino',
      'cerveza',
      'birra',
      'licor',
      'liquore',
    ],
    exclusions: [
      r'schwein',
      r'malzbier',
      r'ingwerbier|ginger\s*beer|root\s*beer',
      r'weinstein|weinsäure|weinbeere|weintraube|weinblatt|weinblätter|weinraute|weinessig|weinrebe',
    ],
    suppressedBy: {'wine_vinegar', 'alcohol_free_beverage'},
  ),
  IngredientRule(
    id: 'alcohol_declared',
    effect: RuleEffect.haram,
    patterns: [
      '${_l}alkohol$_l',
      'ethanol',
      'äthanol',
      'alcohol(?:\\s+etílico)?',
      'alcool',
      'alkol',
      'etanol',
    ],
    exclusions: [
      r'zuckeralkohol|sugar\s*alcohols?|polyalkohol|polyol',
      r'cetyl|stearyl|cetearyl|benzyl|polyvinyl|isopropyl',
      r'alkoholfrei|alcohol[- ]free|non[- ]alcoholic|sans\s+alcool|alkolsüz|ohne\s+alkohol|entalkoholisiert',
    ],
    suppressedBy: {'alcohol_free_beverage'},
  ),

  // ---------------- UNKLAR: Herkunft oder Bewertung ungeklärt --------------
  IngredientRule(
    id: 'alcohol_free_beverage',
    effect: RuleEffect.unclear,
    patterns: [
      r'(?:alkoholfrei|entalkoholisiert)\p{L}*\s+\p{L}*(?:bier|wein)',
      r'(?:alcohol[- ]free|non[- ]alcoholic|de-?alcoholi[sz]ed)\s+(?:beer|wine)s?',
    ],
  ),
  IngredientRule(
    id: 'wine_vinegar',
    effect: RuleEffect.unclear,
    patterns: [
      '${_l}weinessig',
      r'essig\s+aus\s+wein',
      r'(?:red\s+|white\s+)?wine\s+vinegar',
      r'vinaigre\s+de\s+vin',
      r'şarap\s+sirkesi',
      r'aceto\s+(?:balsamico|di\s+vino)',
      'balsamico',
      'balsamic(?:\\s+vinegar)?',
      'balsamessig',
      r'vinagre\s+de\s+vino',
    ],
  ),
  IngredientRule(
    id: 'gelatine',
    effect: RuleEffect.unclear,
    patterns: [
      '${_l}gelatine?$_l',
      'gélatine',
      'jelatin$_l',
      'gelatina',
      r'e\s?-?441',
      '${_l}kollagen$_l',
      'collagen$_l',
    ],
    resolvedBy: {Qualifier.fish, Qualifier.halalStated},
    escalateOnPork: true,
  ),
  IngredientRule(
    id: 'rennet',
    effect: RuleEffect.unclear,
    patterns: [
      'lab',
      '${_l}lab-?ferment',
      'kälberlab',
      'rennet',
      'présure',
      r'peynir\s+mayası',
      'caglio',
      'cuajo',
      'enzyme?n?',
      'enzymes',
      'enzim(?:ler)?',
    ],
    resolvedBy: _cheeseOrRennetResolvers,
    escalateOnPork: true,
  ),
  IngredientRule(
    id: 'cheese',
    effect: RuleEffect.unclear,
    patterns: [
      '${_l}käse',
      '${_l}kaese',
      'cheeses?',
      'fromages?',
      'peynir$_l',
      'formaggio',
      'queso',
      'parmesan',
      'parmigiano',
      'mozzarella',
      'cheddar',
      'gouda',
      'emmentaler',
      'pecorino',
      'grana\\s+padano',
    ],
    resolvedBy: _cheeseOrRennetResolvers,
  ),
  IngredientRule(
    id: 'meat',
    effect: RuleEffect.unclear,
    patterns: [
      r'rind(?:fleisch|er\p{L}*|s\p{L}*)?',
      'kalb$_l',
      'lamm$_l',
      'hammel$_l',
      'schaf$_l',
      'ziege$_l',
      'puten?$_l',
      'truthahn$_l',
      'hähnchen$_l',
      'haehnchen$_l',
      'huhn',
      'hühnerfleisch',
      'hühnerbrühe',
      'geflügel$_l',
      'gefluegel$_l',
      'enten?$_l',
      'gans',
      'gänse$_l',
      '${_l}fleisch$_l',
      'knochen$_l',
      'schinken',
      '${_l}schinken',
      'speck',
      'salami',
      '${_l}wurst',
      'beef',
      'veal',
      'lamb',
      'mutton',
      'chicken',
      'turkey',
      'duck',
      'goose',
      'poultry',
      'meats?',
      r'meat\s+extract',
      'ham',
      'bacon',
      'bones?',
      'b(?:œ|oe)uf',
      'veau',
      'agneau',
      'mouton',
      'poulet',
      'dinde',
      'canard',
      'volaille',
      'viande',
      'sığır$_l',
      'dana',
      'kuzu',
      'tavuk',
      'hindi',
      'carne',
      'pollo',
      'pavo',
      'ternera',
      'manzo',
      'tacchino',
    ],
    exclusions: [
      r'frucht\p{L}*fleisch|kokos\p{L}*fleisch|fleischtomate',
      r'schafs?milch|ziegenmilch|schafs?käse|ziegenkäse|schafsjoghurt|ziegenjoghurt',
      r'hühnerei|huehnerei',
      r'chicken\s+eggs?',
      r'(?:from|in|made\s+in|origin:?)\s+turkey',
      r'entenei|gänseei',
      r'enteisen|entkernt|entsteint|entöl|entrahmt',
      r'jambon\s+de\s+dinde',
      r'veggie|vegan|vegetarisch|vegetarian|fleischfrei|meat[- ]free',
      r'blutwurst|schwein',
    ],
    resolvedBy: {Qualifier.halalStated},
    escalateOnPork: true,
  ),
  IngredientRule(
    id: 'animal_fat',
    effect: RuleEffect.unclear,
    patterns: [
      r'tierisch\p{L}*\s+fett\p{L}*',
      r'fett\p{L}*\s+tierisch\p{L}*',
      r'animal\s+fats?',
      r'graisses?\s+animales?',
      r'hayvansal\s+yağ',
      '${_l}talg',
      'tallow',
      'suet',
      '${_l}schmalz',
    ],
    exclusions: [r'butterschmalz', r'schweine?schmalz'],
    resolvedBy: {Qualifier.plant, Qualifier.halalStated},
    escalateOnPork: true,
  ),
  IngredientRule(
    id: 'flavouring',
    effect: RuleEffect.unclear,
    patterns: [
      '${_l}aroma',
      '${_l}aromen',
      '${_l}aromastoffe?',
      r'flavou?rings?',
      r'(?:natural\s+)?flavou?rs?',
      'arômes?',
      'aromes?',
      r'aroma\s+verici\p{L}*',
      r'vanill\p{L}*extrakt',
      r'vanill\p{L}*\s+extract',
      r'extrait\s+de\s+vanille',
    ],
    exclusions: [
      r'malzextrakt|hefeextrakt|kaffeeextrakt|teeextrakt|rooibosextrakt|'
          r'paprikaextrakt|rosmarinextrakt|karottenextrakt|süßholzextrakt',
      r'fleischextrakt|rindfleischextrakt',
    ],
    resolvedBy: {Qualifier.halalStated},
  ),
  IngredientRule(
    id: 'e_number_animal_possible',
    effect: RuleEffect.unclear,
    patterns: [
      r'e\s?-?(?:422|43[0-6]|470[ab]?|471|472[a-f]?|473|474|475|477|478|481|482|483|49[1-5]|570|572|627|631|635|920|921)(?![0-9])',
      r'mono\p{L}*[- ]?(?:und|and|et|ve|y|e)?\s*di\p{L}*glycerid\p{L}*',
      r'\p{L}*glycerid\p{L}*',
      r'glycerin\p{L}*',
      r'glycérine',
      r'glycerol',
      r'gliserin',
      r'stearinsäure|stearic\s+acid|acide\s+stéarique',
      r'\p{L}*stearat\p{L}*',
      r'\p{L}*stearate',
      r'polysorbat\p{L}*',
      r'l-?cystein\p{L}*',
      r'l-?cysteine',
      r'inosinat\p{L}*|guanylat\p{L}*|ribonukleotid\p{L}*',
    ],
    resolvedBy: {Qualifier.plant, Qualifier.synthetic, Qualifier.halalStated},
    escalateOnPork: true,
  ),
  IngredientRule(
    id: 'bone_phosphate',
    effect: RuleEffect.unclear,
    patterns: [r'e\s?-?542(?![0-9])', r'knochenphosphat', r'bone\s+phosphate'],
    escalateOnPork: true,
  ),
  IngredientRule(
    id: 'insect_derived',
    effect: RuleEffect.unclear,
    patterns: [
      r'e\s?-?120(?![0-9])',
      '${_l}karmin$_l',
      'carmin(?:e|ic\\s+acid)?',
      'cochenille',
      'cochineal',
      r'e\s?-?904(?![0-9])',
      'schellack',
      'shellac',
      r'gomme[- ]laque',
      '${_l}insekt$_l',
      'insects?',
      'mehlwurm$_l',
      'grillen$_l',
    ],
  ),
  IngredientRule(
    id: 'seafood_non_fish',
    effect: RuleEffect.unclear,
    patterns: [
      'garnele$_l',
      'shrimps?',
      'prawns?',
      'crevettes?',
      'karides',
      'krabben?$_l',
      'crabs?',
      'hummer$_l',
      'lobsters?',
      '${_l}muschel$_l',
      'mussels?',
      'auster$_l',
      'oysters?',
      'tintenfisch$_l',
      'squids?',
      'calamar$_l',
      'oktopus',
      'octopus',
    ],
    exclusions: [r'austernpilz|oyster\s+mushroom|austernseitling'],
  ),

  // ---------------- INFO: beeinflusst das Ergebnis nicht -------------------
  IngredientRule(
    id: 'whey',
    effect: RuleEffect.info,
    patterns: ['${_l}molke$_l', 'whey', 'lactosérum', r'peynir\s+altı\s+suyu'],
  ),
];

/// Zusatzstoff-Codes aus Open-Food-Facts-Tags ("en:e471"), die als
/// UNKLAR gewertet werden, falls sie im Text nicht bereits erkannt wurden.
const Map<String, String> additiveTagRules = {
  'en:e120': 'insect_derived',
  'en:e904': 'insect_derived',
  'en:e441': 'gelatine',
  'en:e542': 'bone_phosphate',
  'en:e422': 'e_number_animal_possible',
  'en:e430': 'e_number_animal_possible',
  'en:e431': 'e_number_animal_possible',
  'en:e432': 'e_number_animal_possible',
  'en:e433': 'e_number_animal_possible',
  'en:e434': 'e_number_animal_possible',
  'en:e435': 'e_number_animal_possible',
  'en:e436': 'e_number_animal_possible',
  'en:e470a': 'e_number_animal_possible',
  'en:e470b': 'e_number_animal_possible',
  'en:e471': 'e_number_animal_possible',
  'en:e472a': 'e_number_animal_possible',
  'en:e472b': 'e_number_animal_possible',
  'en:e472c': 'e_number_animal_possible',
  'en:e472d': 'e_number_animal_possible',
  'en:e472e': 'e_number_animal_possible',
  'en:e472f': 'e_number_animal_possible',
  'en:e473': 'e_number_animal_possible',
  'en:e474': 'e_number_animal_possible',
  'en:e475': 'e_number_animal_possible',
  'en:e477': 'e_number_animal_possible',
  'en:e481': 'e_number_animal_possible',
  'en:e482': 'e_number_animal_possible',
  'en:e483': 'e_number_animal_possible',
  'en:e491': 'e_number_animal_possible',
  'en:e492': 'e_number_animal_possible',
  'en:e493': 'e_number_animal_possible',
  'en:e494': 'e_number_animal_possible',
  'en:e495': 'e_number_animal_possible',
  'en:e570': 'e_number_animal_possible',
  'en:e572': 'e_number_animal_possible',
  'en:e627': 'e_number_animal_possible',
  'en:e631': 'e_number_animal_possible',
  'en:e635': 'e_number_animal_possible',
  'en:e920': 'e_number_animal_possible',
  'en:e921': 'e_number_animal_possible',
};
