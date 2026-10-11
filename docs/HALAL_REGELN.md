# Halal-Prüfregeln (Regelversion 2026.10-2)

> **Wichtig:** Diese Regeln sind eine technische Umsetzung vorsichtiger, verbreiteter
> Bewertungsgrundsätze. Sie wurden **noch nicht von einem Gelehrtengremium oder einer
> Halal-Zertifizierungsstelle geprüft**. Diese Datei ist so geschrieben, dass eine
> fachkundige Person sie ohne Programmierkenntnisse prüfen kann.
> Code: `lib/domain/rules/catalog.dart` (Wortlisten), `lib/domain/rules/halal_engine.dart` (Entscheidung).

## 1. Grundsätze

1. **Keine KI entscheidet.** Das Ergebnis entsteht aus festen Wortlisten und einer festen Reihenfolge.
   Gleiche Eingabe → gleiches Ergebnis. Jede Änderung erhöht die Regelversion.
2. **Fehlende Information ist nie „halal“.**
3. **HARAM nur bei ausdrücklicher Nennung** eines verbotenen Bestandteils – nie, weil Daten fehlen.
4. **Strittiges → UNKLAR** (nicht HARAM), mit Begründung im Bericht.
5. **Ein Barcode = ein Produkt.** Zutaten eines ähnlich benannten Produkts werden nie übernommen.
6. **Halal-Labels aus Open Food Facts sind keine Zertifikate** (werden angezeigt, aber nicht gewertet).

## 2. Entscheidungsreihenfolge (erste zutreffende Regel gilt)

| # | Bedingung | Ergebnis |
|---|---|---|
| 1 | Barcode nicht in der Datenbank / Datenbank liefert anderes Produkt | GRAU – NICHT VERIFIZIERT |
| 2 | Keine Zutatenliste und kein gültiges Zertifikat | GRAU – NICHT VERIFIZIERT |
| 3 | Widerspruch: Listen in verschiedenen Sprachen nennen unterschiedliche verbotene Stoffe, Zertifikat und Zutaten passen nicht zusammen, oder eine Kennzeichnung „vegan/vegetarisch“ widerspricht einer Zutat (z. B. Gelatine) | GRAU – NICHT VERIFIZIERT |
| 4 | Verbotener Bestandteil ausdrücklich genannt (Regel A) | ROT – HARAM |
| 5 | Verifiziertes, gültiges Zertifikat für genau diesen Barcode (Regel B) | HALAL-ZERTIFIZIERT |
| 6 | Mindestens eine Prüffrage trotz Recherche offen oder Stoff mit dokumentierter Meinungsverschiedenheit (Regel D) | ORANGE – UNKLAR |
| 7 | Nicht alle Freigabebedingungen (Abschnitt 3) erfüllt (Regel E) | GRAU – NICHT VERIFIZIERT |
| 8 | Sonst (Regel C) | GRÜN – HALAL NACH VOLLSTÄNDIGER ZUTATENPRÜFUNG – **keine** Zertifizierung, keine Garantie |

Zutatenlisten aus der Datenbank werden als Text nur in **Deutsch, Englisch, Französisch und Türkisch**
ausgewertet. Bei anderen Sprachen wertet die App die strukturierte Zutatenanalyse von Open Food Facts
aus (Kennungen wie `en:gelatin`), um HARAM/UNKLAR zu erkennen – ein grünes Ergebnis ist dann nie möglich.

## 3. Freigabebedingungen für GRÜN (alle müssen erfüllt sein)

1. Produkt eindeutig über den Barcode identifiziert (Barcode stimmt, Produktname vorhanden)
2. Zutatenliste vorhanden
3. Zutaten stammen aus der Produktdatenbank (nicht nur Foto oder Handeingabe)
4. Sprache und Schrift werden unterstützt (keine Sprachfehler-Warnung der Datenbank)
5. Liste vollständig (nicht als unvollständig markiert, nicht abgeschnitten, Klammern ausgeglichen, keine unsichere Texterkennung)
6. Daten plausibel (keine Warnung „80 % unbekannte Zutaten“, höchstens die Hälfte unbekannter Zutaten)
7. Keine widersprüchlichen Angaben
8. Kein verbotener Bestandteil
9. Herkunft aller kritischen Zutaten produktbezogen belegt (keine offene Prüffrage)
10. Kein Stoff mit dokumentierter Meinungsverschiedenheit

Ein automatischer Test (`test/research_test.dart`, Fall 15) prüft, dass jedes grüne Ergebnis alle zehn Bedingungen erfüllt.

## 4. Automatische Recherche je kritischer Zutat

Für jede Zutat, die eine Regel auslöst, führt die App folgende Schritte aus und zeigt sie an:

| Schritt | Quelle | Art des Belegs |
|---|---|---|
| Stoffidentität, E-Nummer, Stoffklasse | eingebautes Stoffwissen (EU-Verordnung 1333/2008) | allgemein |
| Strukturierte Zutatendaten | Open Food Facts, Feld `ingredients` (mit Unterzutaten) | allgemein (Vegan-Einstufung stammt aus der allgemeinen Taxonomie) |
| Herkunftsangaben in der Zutatenliste | Text des Produkts, z. B. „pflanzlich“, „mikrobiell“, „Fisch“, „halal“, „ohne Alkohol“ | **produktbezogen** |
| Verpackungskennzeichnung | Open Food Facts `labels_tags`: `en:vegan`, `en:vegetarian` | **produktbezogen** (von Nutzern erfasst) |
| Allgemeine Stoffdaten | Open-Food-Facts-Taxonomie `/api/v2/taxonomy` (online) | allgemein |
| Herstellerinformation | Open Food Facts `link` | nur Hinweis – keine automatische Auswertung |

**Prüffragen** je Stoff: tierischer Ursprung? · Tierart (Schwein ausgeschlossen)? · Schlachtung? · Alkohol als Löse-/Trägerstoff? · dokumentierte Meinungsverschiedenheit.

**Nur produktbezogene Belege beantworten Prüffragen.** Allgemeine Stoffdaten, die Vegan-Einstufung der
Datenbank und Nutzerhinweise beantworten nie eine Prüffrage. Halal-Labels aus der Datenbank sind keine Belege.

| Beleg | beantwortet |
|---|---|
| „pflanzlich“, „synthetisch“, „mikrobiell“ an der Zutat | tierischer Ursprung: nein (Tierart/Schlachtung entfallen) |
| „Fisch“ an der Zutat | Tierart: kein Schwein; Schlachtung entfällt |
| „halal“ an der Zutat (Herstellerangabe) | Tierart, Schlachtung, Alkohol |
| „ohne Alkohol / alkoholfrei“ an der Zutat | Alkohol: nein |
| Kennzeichnung „vegan“ | tierischer Ursprung: nein (nicht Alkohol!) |
| Kennzeichnung „vegetarisch“ | Bestandteile aus Schlachttieren: nein (für Lab, Käse, tierisches Fett, E-Nummern, Aroma); bei Gelatine, Fleisch und Knochenphosphat gilt eine solche Kennzeichnung als **Widerspruch** → NICHT VERIFIZIERT |

Beispiel **Aroma**: offen sind „tierischer Ursprung“ und „Alkohol“. Eine Vegan-Kennzeichnung klärt nur den
ersten Punkt – das Ergebnis bleibt UNKLAR, bis auch „ohne Alkohol“ belegt ist.

Ist eine Online-Quelle nicht erreichbar, steht im Bericht „Quelle nicht erreichbar – nicht geprüft“; die App
behauptet keine erfolgreiche Recherche.

## 5. Wortlisten

### HARAM (ausdrücklich genannt)
| Regel | Beispiele erkannter Wörter | Ausnahmen (kein Treffer) |
|---|---|---|
| Schwein | Schwein…, Schweinefleisch, Schweinegelatine, pork, porcine, pig, porc, domuz, cerdo, lard, saindoux, خنزير | Meerschwein |
| Blut | Blut, Blutplasma, Blutwurst, blood, sang | Blutorange, blood orange |
| Alkoholisches Getränk | Wein, Rotwein, Weinsauce, Bier, Likör, Rum, Whisky, Wodka, Cognac, Sekt, wine, beer, brandy, vin, bière, şarap, bira, rakı | Malzbier, Ingwerbier, Weinsäure, Weinstein, Weintrauben, Weinbeeren, Weinblätter, Weinessig (→ eigene Regel) |
| Alkohol deklariert | Alkohol, Ethanol, alcohol, alcool, alkol | Zuckeralkohole, Cetyl-/Benzylalkohol, alkoholfrei |
| Eskalation | Gelatine, Fett, Fleisch, Enzyme, E-Nummern **mit Angabe „Schwein“** im selben Bestandteil | – |

### UNKLAR (Herkunft offen oder Bewertung strittig)
| Regel | Beispiele | Wird geklärt durch |
|---|---|---|
| Gelatine/Kollagen | Gelatine, Rindergelatine, E441, E428, collagen | „Fisch“, „halal“ im selben Bestandteil |
| Lab/Enzyme | Lab, Kälberlab, rennet, Enzyme, peynir mayası | „mikrobiell“, „pflanzlich“, „vegetarisch“, „halal“ |
| Käse | Käse, Parmesan, cheese, fromage, peynir | wie Lab |
| Fleisch (Schlachtung/Tierart offen) | Rind…, Hähnchen, Pute, Lamm, Fleisch…, Schinken, Speck, Salami, Wurst, chicken, beef, meat, tavuk, dana | „halal“ im selben Bestandteil (Herstellerangabe) |
| Tierisches Fett | tierisches Fett, Talg, Schmalz, tallow, suet | „pflanzlich“, „halal“ (Ausnahme: Butterschmalz) |
| Aroma | Aroma, Aromen, Raucharoma, flavouring, arôme, Vanilleextrakt | tierisch: „pflanzlich“/Vegan-/Vegetarisch-Kennzeichnung; Alkohol: „ohne Alkohol“; beides: „halal“ |
| Zusatzstoffe mögl. tierischer Herkunft | E422, E430–436, E470a/b, E471, E472a–f, E473–E483, E491–495, E570, E572, E627, E631, E635, E920, E921, Mono-/Diglyceride, Glycerin, Stearate, Polysorbate, L-Cystein | „pflanzlich“, „synthetisch“, „halal“ |
| Knochenphosphat | E542 | – |
| Insekten (strittig) | E120/Karmin/Cochenille, E904/Schellack, Insekten | – |
| Meeresfrüchte (strittig, v. a. hanafitisch) | Garnelen, Muscheln, Tintenfisch, shrimp, karides | – (Austernpilz ist ausgenommen) |
| Weinessig (strittig: Umwandlung/istihāla) | Weinessig, Balsamico, wine vinegar, vinaigre de vin, şarap sirkesi | – |
| Alkoholfreies Bier/Wein | alkoholfreies Bier, non-alcoholic beer | – |

### Nur Hinweis (ändert das Ergebnis nicht)
| Regel | Beispiele |
|---|---|
| Molke | Molke, Süßmolkenpulver, whey |

### Zusatzstoff-Tags der Datenbank
Erkennt Open Food Facts einen der oben genannten E-Stoffe, der im Text nicht gefunden wurde
(z. B. weil die Liste in einer anderen Schreibweise vorliegt), wird er als UNKLAR ergänzt.

## 6. Gültigkeitsbereich von Herkunftsangaben
Eine Angabe wie „pflanzlich“ gilt für:
- den Bestandteil selbst („E471 pflanzlich“),
- alle Unterbestandteile eines Überbegriffs („pflanzliche Emulgatoren (E471, E472e)“),
- den Bestandteil, wenn sie als einziger Klammerinhalt folgt („Gelatine (Schwein)“).

Sie gilt **nicht** für Geschwister: „Füllung (Rindergelatine, pflanzliches Fett)“ → Gelatine bleibt UNKLAR.

## 7. Bekannte Grenzen
- Geprüft wird nur, was in der Zutatenliste steht: keine Prüfung von Schlachtung, Anlagen,
  Kreuzkontamination oder nicht deklarierten Hilfsstoffen.
- Unterschiedliche Rechtsschulen/Standards (z. B. zu Alkohol in Kleinstmengen, Meeresfrüchten,
  Insekten, Istihāla) sind nicht einzeln einstellbar; strittige Punkte werden als UNKLAR markiert.
- Wortlisten können unvollständig sein. Jeder Fehlalarm oder übersehene Stoff sollte als Testfall
  in `test/halal_engine_test.dart` aufgenommen und die Regelversion erhöht werden.
- Es gibt derzeit **keine kostenlose, verifizierbare Zertifikatsquelle**. Die Datenstruktur
  (`Certification`) und die Prüfung (Barcode, Gültigkeit, verifiziert) sind vorhanden und getestet.

## 8. Religiöse Prüfung

**Eine Prüfung durch islamische Fachpersonen hat bisher nicht stattgefunden.** Die App behauptet das
auch nirgends. Tatsachen (was ein Stoff ist, was in der Zutatenliste steht) und religiöse Bewertungen
(ob etwas erlaubt ist) sind getrennt: Tatsachen stehen im Stoffwissen und in den Belegen, Bewertungen in
den Begründungstexten der Regeln.

## 9. Offene Fachfragen für die Prüfung durch Gelehrte
1. Soll ausdrücklich genannter Alkohol (z. B. „Alkohol 2 %“ in Pralinen) als HARAM oder UNKLAR gelten?
2. Soll Fleisch mit Herstellerangabe „halal“ in der Zutatenliste als geklärt gelten?
3. Sollen Meeresfrüchte je nach gewählter Rechtsschule unterschiedlich bewertet werden (Einstellung)?
4. Ist die Einstufung von Weinessig/Balsamico als UNKLAR angemessen?
5. Soll Molke/Käse mit unbekanntem Lab strenger bewertet werden?
6. Reicht eine Vegan-Kennzeichnung als Beleg gegen tierische Herkunft (z. B. bei E471)?
7. Wie sind Aromen mit technisch bedingten Alkoholspuren zu bewerten (derzeit: UNKLAR)?
