/// Schrift-Erkennung für Zutatentexte (reines Dart, ohne Flutter).
///
/// Die Wortlisten der App und die Foto-Texterkennung arbeiten nur mit
/// lateinischer Schrift. Texte, die überwiegend in einer anderen Schrift
/// stehen (Arabisch, Urdu, Persisch, Bengalisch, Devanagari, Chinesisch,
/// Kyrillisch, Thai …), dürfen deshalb nie zu einem grünen Ergebnis führen.
library;

final _letter = RegExp(r'\p{L}', unicode: true);
final _latin = RegExp(r'\p{Script=Latin}', unicode: true);

/// Anteil der Buchstaben, die NICHT zur lateinischen Schrift gehören (0..1).
/// Ohne Buchstaben: 0.
double nonLatinShare(String text) {
  final letters = _letter.allMatches(text).length;
  if (letters == 0) return 0;
  final latin = _latin.allMatches(text).length;
  return (letters - latin) / letters;
}

/// Mehr als 20 % der Buchstaben sind nicht lateinisch.
bool hasUnsupportedScript(String text) => nonLatinShare(text) > 0.2;
