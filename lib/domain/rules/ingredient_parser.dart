/// Zerlegt eine Zutatenliste in eine Baumstruktur.
///
/// "Füllung (Rindergelatine, pflanzliches Fett), Zucker"
///   -> [Füllung -> [Rindergelatine, pflanzliches Fett], Zucker]
///
/// Der Parser erfindet nichts: Jeder Knoten enthält ausschließlich Text,
/// der in der Quelle steht.
library;

class IngredientNode {
  IngredientNode(this.head, {this.parent});

  /// Text dieses Bestandteils ohne Klammerinhalt.
  String head;
  final IngredientNode? parent;
  final List<IngredientNode> children = [];

  /// Originaltext inklusive Klammerinhalt (für die Anzeige als Beleg).
  String get fullText => children.isEmpty
      ? head.trim()
      : '${head.trim()} (${children.map((c) => c.fullText).join(', ')})';

  Iterable<IngredientNode> get descendantsAndSelf sync* {
    yield this;
    for (final c in children) {
      yield* c.descendantsAndSelf;
    }
  }

  /// Kontext für Herkunftsangaben (z. B. "pflanzlich", "Schwein"):
  /// eigener Text + Überbegriff (Eltern) + einziger Klammerinhalt.
  String get qualifierContext {
    final parts = <String>[head];
    if (parent != null) parts.add(parent!.head);
    if (children.length == 1) parts.add(children.first.fullText);
    return parts.join(' | ');
  }
}

class ParsedIngredients {
  ParsedIngredients(this.roots, this.tracesText, this.normalizedText);
  final List<IngredientNode> roots;

  /// Abschnitt "Kann Spuren von … enthalten" – wird separat ausgewiesen.
  final String? tracesText;
  final String normalizedText;

  Iterable<IngredientNode> get allNodes sync* {
    for (final r in roots) {
      yield* r.descendantsAndSelf;
    }
  }
}

class IngredientParser {
  IngredientParser._();

  static final _tracesStart = RegExp(
    r'(kann\s+spuren|enthält\s+möglicherweise|may\s+contain|may\s+also\s+contain|'
    r'traces?\s+of|peut\s+contenir|traces?\s+éventuelles|eser\s+miktarda|'
    r'puede\s+contener|può\s+contenere)',
    caseSensitive: false,
    unicode: true,
  );

  static final _prefix = RegExp(
    r'^\s*(zutaten|ingredients?|ingrédients?|içindekiler|ingredientes|'
    r'ingredienti|bahan|komposisi|المكونات|مكونات)\s*[:：]?\s*',
    caseSensitive: false,
    unicode: true,
  );

  static String normalize(String raw) {
    var t = raw
        .replaceAll('_', '') // Open Food Facts markiert Allergene mit _x_
        .replaceAll(RegExp(r'[\r\n\t]+'), ' ')
        .replaceAll(RegExp(r'[\[{]'), '(')
        .replaceAll(RegExp(r'[\]}]'), ')')
        .replaceAll('：', ':')
        .replaceAll('،', ',') // arabisches Komma
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    t = t.replaceFirst(_prefix, '');
    return t;
  }

  static ParsedIngredients parse(String raw) {
    var text = normalize(raw);
    String? traces;
    final m = _tracesStart.firstMatch(text);
    if (m != null) {
      traces = text.substring(m.start).trim();
      text = text.substring(0, m.start).trim();
    }
    // Abschließenden Punkt entfernen.
    text = text.replaceFirst(RegExp(r'[.\s]+$'), '');

    final roots = <IngredientNode>[];
    _parseInto(text, roots, null);
    return ParsedIngredients(roots, traces, text);
  }

  static void _parseInto(
      String text, List<IngredientNode> out, IngredientNode? parent) {
    var depth = 0;
    var buf = StringBuffer();
    var inner = StringBuffer();
    IngredientNode? current;
    final pendingInner = <String>[];

    void flush() {
      final head = buf.toString().trim();
      if (head.isEmpty && pendingInner.isEmpty) {
        buf = StringBuffer();
        return;
      }
      current = IngredientNode(head, parent: parent);
      for (final innerText in pendingInner) {
        _parseInto(innerText, current!.children, current);
      }
      out.add(current!);
      pendingInner.clear();
      buf = StringBuffer();
    }

    for (var i = 0; i < text.length; i++) {
      final ch = text[i];
      if (ch == '(') {
        if (depth > 0) inner.write(ch);
        depth++;
      } else if (ch == ')') {
        if (depth == 0) continue; // unbalancierte Klammer ignorieren
        depth--;
        if (depth == 0) {
          pendingInner.add(inner.toString());
          inner = StringBuffer();
        } else {
          inner.write(ch);
        }
      } else if (depth > 0) {
        inner.write(ch);
      } else if (ch == ',' || ch == ';' || (ch == '.' && _isSentenceDot(text, i))) {
        flush();
      } else {
        buf.write(ch);
      }
    }
    if (depth > 0 && inner.isNotEmpty) {
      // nicht geschlossene Klammer: Inhalt trotzdem auswerten
      pendingInner.add(inner.toString());
    }
    flush();
  }

  /// Ein Punkt trennt nur, wenn er nicht zwischen Ziffern steht (2.5 %).
  static bool _isSentenceDot(String t, int i) {
    final before = i > 0 ? t[i - 1] : ' ';
    final after = i + 1 < t.length ? t[i + 1] : ' ';
    final isDigit = RegExp(r'\d');
    return !(isDigit.hasMatch(before) && isDigit.hasMatch(after));
  }
}
