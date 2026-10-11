// Automatisch erzeugt von tool/fetch_pubchem.py – nicht von Hand ändern.
// Abruf: 2026-10-11. Quelle: PubChem (NCBI), https://pubchem.ncbi.nlm.nih.gov/
//
// Allgemeine Stoffidentität – KEIN Nachweis von Herkunft oder Vorkommen
// eines Stoffes in einem bestimmten Produkt.
// Ohne eindeutigen PubChem-Eintrag (Gemische o. Ä.): E428, E430, E431, E432, E433, E434, E435, E436, E441, E470a, E470b, E471, E472a, E472b, E472c, E472d, E472e, E472f, E473, E474, E475, E477, E478, E542, E570, E635, E904

class PubChemRecord {
  const PubChemRecord({required this.query, required this.cid, this.iupacName, this.formula, this.cas});

  /// Suchbegriff, mit dem der Eintrag gefunden wurde.
  final String query;
  final int cid;
  final String? iupacName;
  final String? formula;

  /// Erste CAS-Nummer aus den PubChem-Synonymen (von Einsendern gemeldet).
  final String? cas;

  String get url => 'https://pubchem.ncbi.nlm.nih.gov/compound/$cid';
}

const pubchemRetrievedAt = '2026-10-11';

/// Schlüssel: E-Nummer ohne „E“ (wie `Additive.number`).
const Map<String, PubChemRecord> pubchemByAdditive = {
  '120': PubChemRecord(query: 'Carmine', cid: 14749, iupacName: '3,5,6,8-tetrahydroxy-1-methyl-9,10-dioxo-7-[(2R,3R,4R,5S,6R)-3,4,5-trihydroxy-6-(hydroxymethyl)oxan-2-yl]anthracene-2-carboxylic acid', formula: 'C22H20O13', cas: '1390-65-4'),
  '422': PubChemRecord(query: 'Glycerol', cid: 753, iupacName: 'propane-1,2,3-triol', formula: 'C3H8O3', cas: '56-81-5'),
  '481': PubChemRecord(query: 'Sodium stearoyl-2-lactylate', cid: 23671849, iupacName: 'sodium 2-(2-octadecanoyloxypropanoyloxy)propanoate', formula: 'C24H43NaO6', cas: '25383-99-7'),
  '482': PubChemRecord(query: 'Calcium stearoyl-2-lactylate', cid: 22037, iupacName: 'calcium bis(2-(2-octadecanoyloxypropanoyloxy)propanoate)', formula: 'C48H86CaO12', cas: '5793-94-2'),
  '483': PubChemRecord(query: 'Stearyl tartrate', cid: 19989378, iupacName: '2,3-dihydroxy-4-octadecoxy-4-oxobutanoic acid', formula: 'C22H42O6', cas: null),
  '491': PubChemRecord(query: 'Sorbitan monostearate', cid: 16218600, iupacName: '[(2R)-2-[(2R,3R,4S)-3,4-dihydroxyoxolan-2-yl]-2-hydroxyethyl] octadecanoate', formula: 'C24H46O6', cas: '1338-41-6'),
  '492': PubChemRecord(query: 'Sorbitan tristearate', cid: 15181202, iupacName: '[(2R)-2-[(2R,3R,4S)-4-hydroxy-3-octadecanoyloxyoxolan-2-yl]-2-octadecanoyloxyethyl] octadecanoate', formula: 'C60H114O8', cas: '26658-19-5'),
  '493': PubChemRecord(query: 'Sorbitan monolaurate', cid: 11046239, iupacName: '[(2R)-2-[(2R,3R,4S)-3,4-dihydroxyoxolan-2-yl]-2-hydroxyethyl] dodecanoate', formula: 'C18H34O6', cas: '1338-39-2'),
  '494': PubChemRecord(query: 'Sorbitan monooleate', cid: 9920342, iupacName: '[(2R)-2-[(2R,3R,4S)-3,4-dihydroxyoxolan-2-yl]-2-hydroxyethyl] (Z)-octadec-9-enoate', formula: 'C24H44O6', cas: '1338-43-8'),
  '495': PubChemRecord(query: 'Sorbitan monopalmitate', cid: 16212480, iupacName: '[(2R)-2-[(2R,3R,4S)-3,4-dihydroxyoxolan-2-yl]-2-hydroxyethyl] hexadecanoate', formula: 'C22H42O6', cas: '26266-57-9'),
  '572': PubChemRecord(query: 'Magnesium stearate', cid: 11177, iupacName: 'magnesium bis(octadecanoate)', formula: 'C36H70MgO4', cas: '557-04-0'),
  '627': PubChemRecord(query: 'Disodium guanylate', cid: 135414246, iupacName: 'disodium;[(2R,3S,4R,5R)-5-(2-amino-6-oxo-1H-purin-9-yl)-3,4-dihydroxyoxolan-2-yl]methyl phosphate', formula: 'C10H12N5Na2O8P', cas: '5550-12-9'),
  '631': PubChemRecord(query: 'Disodium inosinate', cid: 135414245, iupacName: 'disodium;[(2R,3S,4R,5R)-3,4-dihydroxy-5-(6-oxo-1H-purin-9-yl)oxolan-2-yl]methyl phosphate', formula: 'C10H11N4Na2O8P', cas: '4691-65-0'),
  '920': PubChemRecord(query: 'L-cysteine', cid: 5862, iupacName: '(2R)-2-amino-3-sulfanylpropanoic acid', formula: 'C3H7NO2S', cas: '52-90-4'),
  '921': PubChemRecord(query: 'L-cystine', cid: 67678, iupacName: '(2R)-2-amino-3-[[(2R)-2-amino-2-carboxyethyl]disulfanyl]propanoic acid', formula: 'C6H12N2O4S2', cas: '56-89-3'),
};

/// Weitere Stoffe zur Unterscheidung von Ethanol und anderen Alkoholen.
const Map<String, PubChemRecord> pubchemSubstances = {
  'ethanol': PubChemRecord(query: 'Ethanol', cid: 702, iupacName: 'ethanol', formula: 'C2H6O', cas: '64-17-5'),
  'cetyl_alcohol': PubChemRecord(query: 'Cetyl alcohol', cid: 2682, iupacName: 'hexadecan-1-ol', formula: 'C16H34O', cas: '36653-82-4'),
  'stearyl_alcohol': PubChemRecord(query: 'Stearyl alcohol', cid: 8221, iupacName: 'octadecan-1-ol', formula: 'C18H38O', cas: '112-92-5'),
  'benzyl_alcohol': PubChemRecord(query: 'Benzyl alcohol', cid: 244, iupacName: 'phenylmethanol', formula: 'C7H8O', cas: '100-51-6'),
  'sorbitol': PubChemRecord(query: 'Sorbitol', cid: 5780, iupacName: '(2R,3R,4R,5S)-hexane-1,2,3,4,5,6-hexol', formula: 'C6H14O6', cas: '50-70-4'),
  'propylene_glycol': PubChemRecord(query: 'Propylene glycol', cid: 1030, iupacName: 'propane-1,2-diol', formula: 'C3H8O2', cas: '57-55-6'),
  'acetic_acid': PubChemRecord(query: 'Acetic acid', cid: 176, iupacName: 'acetic acid', formula: 'C2H4O2', cas: '64-19-7'),
};
