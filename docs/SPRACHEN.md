# Sprachen: Oberfläche, Zutaten-Erkennung und Texterkennung

Stand: 11. Oktober 2026, Regelversion `2026.10-3`, Branch `feature/weltweite-suche`.

## Grundsatz: drei getrennte Fähigkeiten

| Fähigkeit | Was sie bedeutet | Wo im Code |
|---|---|---|
| **Benutzeroberfläche** | In welcher Sprache die App ihre Texte anzeigt. Ändert **nie** das Prüfergebnis. | `assets/i18n/*.json`, `lib/core/i18n/strings.dart` (`appLanguages`) |
| **Zutaten-Erkennung** | In welcher Sprache eine Zutatenliste nach den Wortlisten geprüft wird. Hängt von der Sprache der **Zutatenliste** ab, nicht von der App-Sprache. | `lib/domain/rules/catalog.dart` (`supportedRuleLanguages`, `greenRuleLanguages`, `ingredientSupportFor`) |
| **Texterkennung (OCR)** | Ob ein Foto der Zutatenliste gelesen werden kann. Nur **lateinische Schrift**. Ein Foto führt nie zu Grün. | `lib/features/ocr/ocr_screen.dart`, `lib/domain/script.dart` |

Eine übersetzte Oberfläche heißt also **nicht**, dass Zutatenlisten in dieser Sprache geprüft werden.
In der Sprachauswahl steht unter jeder Sprache beides getrennt.

## Übersicht

Stufen der Zutaten-Erkennung:
- **vollständig**: Wortlisten gepflegt und getestet, Grün ist möglich.
- **eingeschränkt**: Wortlisten vorhanden, HARAM und UNKLAR werden erkannt, aber **kein Grün** (ab Regelversion 2026.10-3).
- **nein**: keine Wortlisten. Möglich ist höchstens HARAM oder UNKLAR über die strukturierte Zutatenanalyse von Open Food Facts, sonst NICHT VERIFIZIERT. **Nie Grün.**

| Sprache | Prio. | Benutzeroberfläche | Zutaten-Erkennung | Texterkennung (Foto) | Bekannte Einschränkungen |
|---|---|---|---|---|---|
| Arabisch (ar) | 1 | Entwurf, RTL | nein | nein (arabische Schrift) | Keine arabischen Wortlisten. Open Food Facts kennt „Schwein“, „Schmalz“ und „Alkohol“ auf Arabisch nicht (siehe Messung). |
| Englisch (en) | 1 | vollständig | vollständig | ja | Pepperoni/Chorizo/Mortadella ohne Unterzutaten → nie Grün; prosciutto, pancetta noch nicht erfasst, siehe unten. |
| Deutsch (de) | 1 | vollständig | vollständig | ja | Wie Englisch, siehe unten. |
| Französisch (fr) | 1 | Entwurf | eingeschränkt | ja | Lücken, u. a. „jambon“, „collagène“, „suif“, „mono- et diglycérides“, siehe unten. |
| Türkisch (tr) | 1 | Entwurf | eingeschränkt | ja | Lücken, u. a. „kan“ (Blut), „kolajen“, „digliserit“, „et“ (Fleisch); „bira mayası“ (Bierhefe) wird als HARAM gewertet (offene Fachfrage). |
| Indonesisch (id) | 2 | Entwurf | nein | ja (Lateinschrift, aber keine Regeln) | Nur „babi“ ist als Begriff vorhanden und wirkt nur über die Datenbankanalyse. |
| Urdu (ur) | 2 | Entwurf, RTL | nein | nein (arabische Schrift) | Darstellung in Naskh statt Nastaliq, wenn das Gerät keine Nastaliq-Schrift hat. |
| Bengalisch (bn) | 2 | Entwurf | nein | nein (bengalische Schrift) | – |
| Hindi (hi) | 2 | Entwurf | nein | nein (Devanagari) | – |
| Malaiisch (ms) | 2 | Entwurf | nein | ja (Lateinschrift, aber keine Regeln) | Wie Indonesisch. |
| Persisch (fa) | 2 | Entwurf, RTL | nein | nein (arabische Schrift) | – |
| Hausa (ha) | 2 | Entwurf, **geringste Übersetzungssicherheit** | nein | ja (Lateinschrift, aber keine Regeln) | Flutter bringt keine Hausa-Standardtexte für Bedienelemente mit; dort erscheint Englisch (z. B. Tooltip „Back“). |
| Vereinfachtes Chinesisch (zh-Hans) | 3 | in Vorbereitung | nein | nein (Han-Schrift) | – |
| Suaheli, Somali, Albanisch, Bosnisch, Russisch, Kasachisch, Usbekisch, Aserbaidschanisch, Kurdisch | später | in Vorbereitung | nein | je nach Schrift | Somali und Kurdisch hätten ebenfalls keine Flutter-Standardtexte. |

„Entwurf“ heißt: vollständig übersetzt, aber **nicht** von Muttersprachlern oder Fachleuten geprüft. Bei Zweifeln gilt die deutsche oder englische Fassung. Das sagt die App auch in der Sprachauswahl.

## Wann eine Zutatenliste Grün ergeben kann

Grün setzt unter anderem voraus (vollständige Liste in HALAL_REGELN.md, Abschnitt 3):
1. Mindestens eine Zutatenliste aus Open Food Facts liegt in einer Sprache mit **vollständiger** Zutaten-Erkennung vor (derzeit nur de, en).
2. Keine ausgewertete Liste steht überwiegend (mehr als 20 % der Buchstaben) in nicht-lateinischer Schrift.
3. Keine Sprachfehler-Warnung der Datenbank; höchstens die Hälfte der Zutaten ist unbekannt.

Nie Grün ergeben:
- Zutatenlisten nur in Sprachen ohne oder mit eingeschränkter Zutaten-Erkennung,
- Text in nicht unterstützter Schrift (auch wenn er in der Datenbank als Deutsch oder Englisch markiert ist),
- Fotos und Handeingaben,
- widersprüchliche Sprachfassungen. Nennt etwa die französische Fassung Schwein und die deutsche nicht, ergibt das NICHT VERIFIZIERT.

## Französisch und Türkisch: warum vorerst kein Grün

Bis Regelversion 2026.10-2 durften beide Sprachen Grün ergeben, obwohl es je nur einen einzigen Test gab.
Eine Stichprobe am 11.10.2026 hat Lücken gezeigt: Diese gängigen Bezeichnungen erkennt **keine** Regel:

| Französisch | Türkisch |
|---|---|
| jambon (Schinken) | kan (Blut) |
| collagène | kolajen |
| suif (Talg) | et / et suyu (Fleisch, Fleischbrühe) |
| mono- et diglycérides (d’acides gras) | mono ve digliseritler |
| glycérol | gliserol |
| stéarate (z. B. stéarate de magnésium) | – |

Zusätzlich wird türkisch „bira mayası“ (Bierhefe) als Bier und damit HARAM gewertet; auf Deutsch („Bierhefe“) passiert das nicht.
Ob Bierhefe so zu bewerten ist, ist eine **offene Fachfrage**, siehe unten.

Für jede Lücke braucht es Wortlisten-Ergänzungen. Das sind Regeländerungen, die nur nach Freigabe vorgenommen werden.
Bis dahin ergeben Listen nur auf Französisch oder Türkisch höchstens HARAM, UNKLAR oder NICHT VERIFIZIERT.
Die App zeigt dann „Sprache eingeschränkt unterstützt“.

**Freigabe-Kriterien für Grün in fr/tr** (Vorschlag):
1. Die Lücken oben sind geschlossen, mit je einem Test pro Begriff.
2. Für jede Regel (`ingredientRules`) gibt es mindestens einen Test mit der französischen bzw. türkischen Bezeichnung.
3. Es gibt Tests mit echten Open-Food-Facts-Produkten in der jeweiligen Sprache (Testdaten in `test/fixtures/off/`).
4. Türkisch ist auch in Großbuchstaben getestet (siehe nächster Abschnitt).
5. Erst dann wird `greenRuleLanguages` erweitert, mit neuer Regelversion.

### Türkische Großbuchstaben (behoben in 2026.10-3)

Unicode behandelt beim Vergleich ohne Groß-/Kleinschreibung „İ“ nicht wie „i“ und „I“ nicht wie „ı“.
Deshalb wurden „JELATİN“, „SIĞIR“ und „RAKI“ bisher **nicht** erkannt. Das ist mit derselben Regex-Technik (V8) nachgeprüft, die auch Dart verwendet.
Jetzt werden „İ“ und „ı“ vor dem Vergleich auf beiden Seiten zu „i“ vereinheitlicht (`turkicFold` in `catalog.dart`).
Das ändert keine Regel, nur die Schreibweise beim Vergleich. Angezeigt wird weiter der Wortlaut der Quelle.
Gegenprobe: Bei 103 Zutatentexten aus den bisherigen Tests ändert sich dadurch kein Ergebnis.

## Lücken in Deutsch und Englisch (Grün möglich)

Die Stichprobe hat für die beiden Sprachen mit Grün eine Lücke gezeigt: italienische und spanische Wurstnamen wurden **nicht** erkannt, nämlich „pepperoni“, „chorizo“, „prosciutto“, „pancetta“ und „Mortadella“. Erkannt werden dagegen „Salami“, „Schinken“, „ham“, „bacon“ und „Speck“.

**Umgesetzt (Entscheidung vom 11.10.2026):** Steht „Pepperoni“, „Chorizo“ oder „Mortadella“ (auch „Mortadelle“) **ohne eigene Unterzutaten** in der Liste, gilt die Zutatenliste als nicht vollständig. Das Ergebnis ist NICHT VERIFIZIERT, außer ein anderer Bestandteil belegt HARAM oder UNKLAR, denn diese haben Vorrang.
- Mit Unterzutaten („Pepperoni (Schweinefleisch, Salz)“) werden diese normal geprüft.
- Der Name allein ergibt kein HARAM oder UNKLAR.
- „Peperoni“ (ein p, das Gemüse) ist nicht betroffen.
- Code: `compositeProductNames` in `catalog.dart`, Grund `compositeUnspecified`.

**Noch offen:** „prosciutto“ und „pancetta“ werden weiterhin nicht erkannt. Sie sollen später nach demselben Verfahren aufgenommen werden; dafür braucht es eine Freigabe.

## Was Open Food Facts liefert

**Produktnamen:** Die App liest alle Sprachfassungen (`product_name_languages`, `product_name_xx`) und zeigt bevorzugt den Namen in App-Sprache.

**Zutatenlisten:** Die App liest die Hauptliste (`ingredients_text` mit der Hauptsprache `lang`) sowie `ingredients_text_de/en/fr/tr/ar`.
Listen in anderen Sprachen kommen nur über die Hauptliste an.

**Strukturierte Zutatenanalyse:** Open Food Facts ordnet Zutaten über ein Wörterbuch (Taxonomie) Kennungen wie `en:gelatin` zu. Nur Begriffe aus diesem Wörterbuch werden erkannt.
Messung am 11.10.2026: Wörterbuch `taxonomies/food/ingredients.txt` und `taxonomies/additives.txt` von github.com/openfoodfacts/openfoodfacts-server, Stand `8852423`.
✓ = Begriff ist in dieser Sprache im Wörterbuch eingetragen.

| Begriff | de | en | fr | tr | ar | id | ms | ur | bn | hi | fa | ha | zh |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Schwein (pork) | ✓ | ✓ | ✓ | ✓ | · | · | · | · | · | · | · | · | ✓ |
| Schmalz (lard) | ✓ | ✓ | ✓ | · | · | · | · | · | · | · | · | · | ✓ |
| Schweinegelatine | ✓ | ✓ | ✓ | · | · | · | · | · | · | · | · | · | · |
| Gelatine (inkl. E428) | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | · | ✓ | ✓ | ✓ | · | ✓ |
| Alkohol | ✓ | ✓ | ✓ | ✓ | · | · | · | · | · | · | · | · | · |
| Ethanol | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | · | ✓ |
| Wein | ✓ | ✓ | ✓ | ✓ | ✓ | · | ✓ | ✓ | ✓ | ✓ | ✓ | · | ✓ |
| Weinessig | ✓ | ✓ | ✓ | · | · | · | · | · | · | · | · | · | · |
| Lab (rennet) | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | · | · | · | · | · | ✓ |
| Aroma (flavouring) | ✓ | ✓ | ✓ | · | · | · | · | · | · | · | · | · | ✓ |
| Mono- und Diglyceride | ✓ | ✓ | ✓ | · | ✓ | · | · | · | · | · | · | · | · |

**Folge:** Gerade in den großen muslimisch geprägten Märkten (ar, id, ms, ur, bn, hi, fa, ha) erkennt Open Food Facts selbst „Schwein“ und „Alkohol“ nicht. Die Datenbankanalyse ist dort also lückenhaft.
E-Nummern (z. B. E441, E471, E120) erkennt die App sprachunabhängig, wenn sie im Text stehen.

**Noch nicht gemessen:** Wie viele Produkte es je Sprache gibt. Open Food Facts erlaubt den Abruf der Sprachübersicht für automatische Werkzeuge nicht (robots.txt).
Die Messung kann kostenlos über den vorhandenen, manuell gestarteten Ablauf `off-probe.yml` auf GitHub erfolgen. Dafür ist ein Push nötig.

## Rechts-nach-links (Arabisch, Urdu, Persisch)

- Die Schreibrichtung kommt zentral aus der gewählten Sprache (`AppStrings.direction` → `Directionality` in `app.dart`).
- Barcodes, E-Nummern und Versionsnummern bleiben links-nach-rechts (`ltr()` mit Unicode-Isolaten).
- Abstände sind symmetrisch, und es gibt keine festen Links/Rechts-Positionen, die sich nicht spiegeln.
- Flutter bringt für ar, ur und fa die Standardtexte für Bedienelemente mit; die App meldet alle wählbaren Sprachen automatisch an.
- **Ziffern:** Barcodes können mit arabisch-indischen, persischen/Urdu-, Devanagari- und bengalischen Ziffern eingegeben werden; sie werden in 0–9 umgewandelt. Vorher wurden sie im Eingabefeld stillschweigend verworfen.
- **Einschränkungen:**
  - Die App enthält keine eigenen Schriftarten; dargestellt wird mit den Schriften des Geräts.
  - Zahlen werden in westlichen Ziffern angezeigt.
  - Mehrzahlformen gibt es nicht. Texte mit Zahlen sind deshalb so formuliert, dass sie ohne Mehrzahl auskommen (z. B. „Gespeichert: 3“).

## Tests

| Datei | Prüft |
|---|---|
| `test/i18n_test.dart` | Alle Texte in allen wählbaren Sprachen vorhanden, keine leeren Texte, gleiche Platzhalter; Verbotsliste „garantiert/100 % halal“ je Sprache; RTL genau für ar/ur/fa; RTL-Texte wirklich in arabischer Schrift; fünf Ergebnis-Bezeichnungen je Sprache verschieden; Prioritäten; Ersatz-Standardtexte nur für Hausa |
| `test/language_support_test.dart` | Zuordnung Sprache → Zutaten-Erkennung; de/en können Grün ergeben; fr/tr erkennen HARAM/UNKLAR, aber kein Grün; türkische Großbuchstaben; Priorität-2-Sprachen nie Grün; Datenbankanalyse; fremde Schriften; Ziffern anderer Schriften |
| `test/widget_test.dart` | Startbildschirm in ar/ur/fa rechts-nach-links, in id/ms/bn/hi/ha/fr links-nach-rechts ohne Fehler; Sprachauswahl zeigt Oberfläche und Zutatenprüfung getrennt |
| `test_screens/screens_test.dart` | Bildschirmfotos zusätzlich für ur, fa, id, ha (Sichtprüfung von Spiegelung und Überläufen) |

## Offene Fragen

**Fachlich (für eine islamische Fachperson; derzeit niemand bestätigt):**
1. Ist Bierhefe („bira mayası“, „Bierhefe“, „brewer’s yeast“) als alkoholisches Getränk zu werten (heute: nur Türkisch → HARAM) oder unbedenklich?
2. Erledigt für Pepperoni, Chorizo und Mortadella (ohne Unterzutaten → NICHT VERIFIZIERT). Offen: prosciutto, pancetta.
3. Welche arabischen, indonesischen, malaiischen, Urdu-, Bengali-, Hindi-, persischen und Hausa-Bezeichnungen sollen in die Wortlisten? Sie müssen von Muttersprachlern geprüft sein; die App erfindet keine Zutatenübersetzungen.
4. Sollen die Übersetzungen der fünf Ergebnis-Bezeichnungen und der Regel-Erklärungen von Fachleuten der jeweiligen Sprache geprüft werden, bevor die Sprachen den Status „vollständig“ bekommen?

**Technisch:**
- Messung der Produktzahlen je Sprache (braucht einen Push für den Ablauf `off-probe.yml`).
- Eigene Schriftarten (z. B. Noto Nastaliq Urdu, kostenlos unter OFL) würden die App größer machen; bisher nicht eingebaut.
