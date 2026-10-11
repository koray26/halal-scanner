# Halal-Prüfregeln (Regelversion 2026.10-1)

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
| 1 | Barcode nicht in der Datenbank / Datenbank liefert anderes Produkt | NICHT VERIFIZIERT |
| 2 | Keine Zutatenliste und kein gültiges Zertifikat | NICHT VERIFIZIERT |
| 3 | Zutatenlisten in verschiedenen Sprachen nennen unterschiedliche verbotene Stoffe | NICHT VERIFIZIERT (Widerspruch) |
| 4 | Verbotener Bestandteil ausdrücklich genannt (Regel A) | HARAM (bei gleichzeitigem Zertifikat: Widerspruch → NICHT VERIFIZIERT) |
| 5 | Verifiziertes, gültiges Zertifikat für genau diesen Barcode (Regel B) | HALAL-ZERTIFIZIERT |
| 6 | Mindestens ein ungeklärter/strittiger Bestandteil (Regel D) | UNKLAR |
| 7 | Liste unvollständig/abgeschnitten, nur Foto, von Hand eingegeben, Produktname fehlt (Regel E) | NICHT VERIFIZIERT |
| 8 | Sonst (Regel C) | HALAL NACH ZUTATENPRÜFUNG – ausdrücklich **keine** Zertifizierung |

Zutatenlisten aus der Datenbank werden nur in **Deutsch, Englisch, Französisch und Türkisch**
ausgewertet. Liegt eine Liste nur in einer anderen Sprache vor → NICHT VERIFIZIERT.

## 3. Wortlisten

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
| Gelatine/Kollagen | Gelatine, Rindergelatine, E441, collagen | „Fisch“, „halal“ im selben Bestandteil |
| Lab/Enzyme | Lab, Kälberlab, rennet, Enzyme, peynir mayası | „mikrobiell“, „pflanzlich“, „vegetarisch“, „halal“ |
| Käse | Käse, Parmesan, cheese, fromage, peynir | wie Lab |
| Fleisch (Schlachtung/Tierart offen) | Rind…, Hähnchen, Pute, Lamm, Fleisch…, Schinken, Speck, Salami, Wurst, chicken, beef, meat, tavuk, dana | „halal“ im selben Bestandteil (Herstellerangabe) |
| Tierisches Fett | tierisches Fett, Talg, Schmalz, tallow, suet | „pflanzlich“, „halal“ (Ausnahme: Butterschmalz) |
| Aroma | Aroma, Aromen, Raucharoma, flavouring, arôme, Vanilleextrakt | „halal“ |
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

## 4. Gültigkeitsbereich von Herkunftsangaben
Eine Angabe wie „pflanzlich“ gilt für:
- den Bestandteil selbst („E471 pflanzlich“),
- alle Unterbestandteile eines Überbegriffs („pflanzliche Emulgatoren (E471, E472e)“),
- den Bestandteil, wenn sie als einziger Klammerinhalt folgt („Gelatine (Schwein)“).

Sie gilt **nicht** für Geschwister: „Füllung (Rindergelatine, pflanzliches Fett)“ → Gelatine bleibt UNKLAR.

## 5. Bekannte Grenzen
- Geprüft wird nur, was in der Zutatenliste steht: keine Prüfung von Schlachtung, Anlagen,
  Kreuzkontamination oder nicht deklarierten Hilfsstoffen.
- Unterschiedliche Rechtsschulen/Standards (z. B. zu Alkohol in Kleinstmengen, Meeresfrüchten,
  Insekten, Istihāla) sind nicht einzeln einstellbar; strittige Punkte werden als UNKLAR markiert.
- Wortlisten können unvollständig sein. Jeder Fehlalarm oder übersehene Stoff sollte als Testfall
  in `test/halal_engine_test.dart` aufgenommen und die Regelversion erhöht werden.
- Es gibt derzeit **keine kostenlose, verifizierbare Zertifikatsquelle**. Die Datenstruktur
  (`Certification`) und die Prüfung (Barcode, Gültigkeit, verifiziert) sind vorhanden und getestet.

## 6. Offene Fachfragen für die Prüfung durch Gelehrte
1. Soll ausdrücklich genannter Alkohol (z. B. „Alkohol 2 %“ in Pralinen) als HARAM oder UNKLAR gelten?
2. Soll Fleisch mit Herstellerangabe „halal“ in der Zutatenliste als geklärt gelten?
3. Sollen Meeresfrüchte je nach gewählter Rechtsschule unterschiedlich bewertet werden (Einstellung)?
4. Ist die Einstufung von Weinessig/Balsamico als UNKLAR angemessen?
5. Soll Molke/Käse mit unbekanntem Lab strenger bewertet werden?
