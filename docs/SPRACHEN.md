# Sprachen: Oberfläche, Zutaten-Erkennung und Texterkennung

Stand: 11. Oktober 2026, Regelversion `2026.10-4`, Branch `feature/weltweite-suche`.

## Grundsatz: drei getrennte Fähigkeiten

| Fähigkeit | Was sie bedeutet | Wo im Code |
|---|---|---|
| **Benutzeroberfläche** | In welcher Sprache die App ihre Texte anzeigt. Ändert **nie** das Prüfergebnis. | `assets/i18n/*.json`, `lib/core/i18n/strings.dart` (`appLanguages`) |
| **Zutaten-Erkennung** | In welcher Sprache eine Zutatenliste nach den Wortlisten geprüft wird. Hängt von der Sprache der **Zutatenliste** ab, nicht von der App-Sprache. | `lib/domain/rules/catalog.dart` (`supportedRuleLanguages`, `greenRuleLanguages`, `detectOnlyLanguages`, `ingredientSupportFor`), `lib/domain/rules/off_terms.g.dart` |
| **Texterkennung (OCR)** | Ob ein Foto der Zutatenliste gelesen werden kann. Nur **lateinische Schrift**. Ein Foto führt nie zu Grün. | `lib/features/ocr/ocr_screen.dart`, `lib/domain/script.dart` |

Eine übersetzte Oberfläche heißt also **nicht**, dass Zutatenlisten in dieser Sprache geprüft werden.
In der Sprachauswahl steht unter jeder Sprache beides getrennt.

## Übersicht

Stufen der Zutaten-Erkennung:
- **vollständig**: Wortlisten gepflegt und getestet, Grün ist möglich.
- **eingeschränkt**: Wortlisten vorhanden, HARAM und UNKLAR werden erkannt, aber **kein Grün** (ab Regelversion 2026.10-3).
- **Grund-Erkennung** (ab 2026.10-4): keine getesteten Wortlisten. Die Liste wird trotzdem mit **denselben Regeln** geprüft – mit allen sprachunabhängigen Begriffen (E-Nummern, international gebräuchliche Wörter wie „gelatin“, „babi“, „خنزير“) und den Begriffen, die aus dem Open-Food-Facts-Wörterbuch abgeleitet sind. HARAM und UNKLAR sind möglich, sonst NICHT VERIFIZIERT. **Nie Grün.**
- **nein**: weder Wortlisten noch Grund-Erkennung (derzeit Chinesisch). Möglich ist höchstens HARAM oder UNKLAR über die strukturierte Zutatenanalyse von Open Food Facts, sonst NICHT VERIFIZIERT. **Nie Grün.**

| Sprache | Prio. | Benutzeroberfläche | Zutaten-Erkennung | Texterkennung (Foto) | Bekannte Einschränkungen |
|---|---|---|---|---|---|
| Arabisch (ar) | 1 | Entwurf, RTL | Grund-Erkennung (43 Begriffe) | nein (arabische Schrift) | Keine getesteten Wortlisten. „خنزير“ (Schwein) ist sprachübergreifend erfasst; „Schmalz“ und „Alkohol“ fehlen auch im Open-Food-Facts-Wörterbuch. |
| Englisch (en) | 1 | vollständig | vollständig | ja | Pepperoni/Chorizo/Mortadella ohne Unterzutaten → nie Grün; prosciutto, pancetta noch nicht erfasst, siehe unten. |
| Deutsch (de) | 1 | vollständig | vollständig | ja | Wie Englisch, siehe unten. |
| Französisch (fr) | 1 | Entwurf | eingeschränkt | ja | Lücken, u. a. „jambon“, „collagène“, „suif“, „mono- et diglycérides“, siehe unten. |
| Türkisch (tr) | 1 | Entwurf | eingeschränkt | ja | Lücken, u. a. „kan“ (Blut), „kolajen“, „digliserit“, „et“ (Fleisch); „bira mayası“ (Bierhefe) wird als HARAM gewertet (offene Fachfrage). |
| Indonesisch (id) | 2 | Entwurf | Grund-Erkennung (22 Begriffe) | ja (Lateinschrift, aber keine Regeln) | „babi“ (Schwein) wird erkannt; kein Begriff für Wein („anggur“ heißt auch Traube und ist deshalb bewusst nicht enthalten). |
| Urdu (ur) | 2 | Entwurf, RTL | Grund-Erkennung (12 Begriffe) | nein (arabische Schrift) | Kein Begriff für Schwein und Gelatine; Darstellung in Naskh statt Nastaliq, wenn das Gerät keine Nastaliq-Schrift hat. |
| Bengalisch (bn) | 2 | Entwurf | Grund-Erkennung (16 Begriffe) | nein (bengalische Schrift) | – |
| Hindi (hi) | 2 | Entwurf | Grund-Erkennung (18 Begriffe) | nein (Devanagari) | – |
| Malaiisch (ms) | 2 | Entwurf | Grund-Erkennung (15 Begriffe) | ja (Lateinschrift, aber keine Regeln) | „babi“ wird erkannt; Wein nur als „wain“. |
| Persisch (fa) | 2 | Entwurf, RTL | Grund-Erkennung (43 Begriffe) | nein (arabische Schrift) | – |
| Hausa (ha) | 2 | Entwurf, **geringste Übersetzungssicherheit** | Grund-Erkennung (0 eigene Begriffe, nur sprachunabhängige) | ja (Lateinschrift, aber keine Regeln) | Flutter bringt keine Hausa-Standardtexte für Bedienelemente mit; dort erscheint Englisch (z. B. Tooltip „Back“). |
| Vereinfachtes Chinesisch (zh-Hans) | 3 | in Vorbereitung | nein | nein (Han-Schrift) | – |
| Suaheli, Somali, Albanisch, Bosnisch, Russisch, Kasachisch, Usbekisch, Aserbaidschanisch, Kurdisch | später | in Vorbereitung | nein | je nach Schrift | Somali und Kurdisch hätten ebenfalls keine Flutter-Standardtexte. |

„Entwurf“ heißt: vollständig übersetzt, aber **nicht** von Muttersprachlern oder Fachleuten geprüft. Bei Zweifeln gilt die deutsche oder englische Fassung. Das sagt die App auch in der Sprachauswahl.

## Gemeinsame Erkennung für alle Sprachen (ab Regelversion 2026.10-4)

**Ursache, warum Ergebnisse in anderen Produktsprachen fehlten** (Prüfung des Codes am 11.10.2026):
1. Die Bewertung hat Zutatenlisten nur ausgewertet, wenn sie auf Deutsch, Englisch, Französisch oder Türkisch vorlagen. Listen in allen anderen Sprachen wurden übersprungen – auch dann, wenn darin E-Nummern oder sprachübergreifende Begriffe wie „babi“ oder „خنزير“ standen, die die Regeln längst kennen.
2. Ersatzweise diente nur die strukturierte Zutatenanalyse von Open Food Facts. Deren Wörterbuch kennt gerade in diesen Sprachen „Schwein“ und „Alkohol“ oft nicht (siehe Messung unten).
3. Die App hat Zutatenlisten nur auf de, en, fr, tr und ar abgerufen; Listen auf id, ms, ur, bn, hi, fa und ha kamen nur an, wenn sie zufällig die Hauptliste waren.

**Lösung (zentral, ohne Sonderregeln je Sprache):**
- Jede Zutatenliste in einer Sprache mit Grund-Erkennung durchläuft **dieselbe Prüfung** wie Deutsch und Englisch. Die Regel-ID (z. B. `gelatine`, `pork`, `alcoholic_beverage`) ist die gemeinsame, sprachunabhängige Zutatenkennung; die Oberfläche zeigt den Namen dieser Kennung in der App-Sprache und daneben den Originalwortlaut.
- Zusätzliche Bezeichnungen je Sprache stammen aus dem Open-Food-Facts-Wörterbuch (`taxonomies/food/ingredients.txt`, `taxonomies/additives.txt`, Stand `8852423`, Lizenz ODbL). Das Werkzeug `tool/off_terms/extract_off_terms.mjs` erzeugt daraus `lib/domain/rules/off_terms.g.dart`:
  - Ein Begriff erbt die Regel, die die **bestehenden englischen Wortlisten** für den englischen Namen desselben Wörterbuch-Eintrags auslösen. Es entsteht also **keine neue Regel** und keine eigene Übersetzung.
  - Entfernt werden: mehrdeutige Begriffe (ein Wort, verschiedene Regeln), Einträge mit Herkunftsangabe, Begriffe unter 3 Zeichen oder mit Ziffern, Begriffe mit „Hefe“ (offene Bierhefe-Frage) sowie einzelne von Hand geprüfte Fehleinträge (z. B. arabisch „جودة“ = Qualität).
- Alle Sprachfassungen eines Produkts werden geprüft. Nennt eine Fassung mit Grund-Erkennung einen verbotenen Stoff, den die deutsche/englische Fassung nicht nennt, gilt das als Widerspruch (NICHT VERIFIZIERT). Fehlt dort ein Treffer, ist das **kein** Gegenbeleg (Wortschatz lückenhaft).
- Die App ruft Zutatenlisten in allen 12 wählbaren Sprachen ab und zeigt die Fassung in App-Sprache zuerst; die anderen Fassungen sind eingeklappt.

**Was das nicht leistet (ehrlich):**
- Die Grund-Erkennung ist **nicht vollständig** und nicht von Muttersprachlern geprüft. Sie liefert deshalb nie Grün.
- Bekannte Lücken (durch Tests festgehalten, `test/cross_language_test.dart`): Persisch, Urdu, Hindi und Bengalisch haben **kein allgemeines Wort für Schwein** („گوشت خوک“, „سور کا گوشت“, „सूअर का मांस“, „শূকরের মাংস“ werden nicht erkannt → NICHT VERIFIZIERT statt HARAM; erkannt werden nur „چربی خوک“ fa und „Schweineschwarte“ hi/bn); Urdu kennt auch Gelatine nicht; Indonesisch hat kein Wort für Wein; Hausa hat keine eigenen Begriffe.
- Persisch/Urdu/Hindi „شراب/शराब“ bedeutet dort Wein bzw. alkoholisches Getränk und wird so gewertet. Im Arabischen heißt „شراب“ auch Sirup; deshalb ist es für Arabisch **nicht** enthalten.

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

**Zutatenlisten:** Die App liest die Hauptliste (`ingredients_text` mit der Hauptsprache `lang`) sowie `ingredients_text_xx` für alle 12 wählbaren Sprachen (de, en, fr, tr, ar, id, ms, ur, bn, hi, fa, ha; seit 2026.10-4).

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
| `test/cross_language_test.dart` | Gleiche Zutat → gleiche Regel-ID und gleiches Ergebnis über bis zu 11 Sprachen (Gelatine, Schwein, Wein, Ethanol, E-Nummern); bekannte Lücken bleiben NICHT VERIFIZIERT; mehrdeutige Begriffe; mehrere Sprachfassungen (Widerspruch, Reihenfolge); fehlende, unvollständige, abgeschnittene und unerkannte Daten; ungeklärte Zutat mit Wortlaut und offenen Fragen |
| `test/widget_test.dart` | Kurze Ergebnisseite (Status, Zusammenfassung, wichtigste Zutat im ersten Bildschirm), eingeklappte Details öffnen/schließen, gleiche Bewertung bei anderer App-Sprache; Startbildschirm in ar/ur/fa rechts-nach-links, in id/ms/bn/hi/ha/fr links-nach-rechts ohne Fehler; Sprachauswahl zeigt Oberfläche und Zutatenprüfung getrennt |
| `test_screens/screens_test.dart` | Bildschirmfotos zusätzlich für ur, fa, id, ha (Sichtprüfung von Spiegelung und Überläufen) |

## Offene Fragen

**Fachlich (für eine islamische Fachperson; derzeit niemand bestätigt):**
1. Ist Bierhefe („bira mayası“, „Bierhefe“, „brewer’s yeast“) als alkoholisches Getränk zu werten (heute: nur Türkisch → HARAM) oder unbedenklich?
2. Erledigt für Pepperoni, Chorizo und Mortadella (ohne Unterzutaten → NICHT VERIFIZIERT). Offen: prosciutto, pancetta.
3. Welche arabischen, indonesischen, malaiischen, Urdu-, Bengali-, Hindi-, persischen und Hausa-Bezeichnungen sollen in getestete Wortlisten? Sie müssen von Muttersprachlern geprüft sein; die App erfindet keine Zutatenübersetzungen. Die Grund-Erkennung (Begriffe aus dem Open-Food-Facts-Wörterbuch) ist dafür nur ein Anfang.
5. Ein einzelner unbekannter Begriff in einer deutschen/englischen Liste verhindert Grün heute nicht; erst wenn laut Datenbank mehr als die Hälfte der Zutaten unbekannt ist. Soll das strenger werden? (Nicht geändert, da es die Bewertung betrifft.)
4. Sollen die Übersetzungen der fünf Ergebnis-Bezeichnungen und der Regel-Erklärungen von Fachleuten der jeweiligen Sprache geprüft werden, bevor die Sprachen den Status „vollständig“ bekommen?

**Technisch:**
- Messung der Produktzahlen je Sprache (braucht einen Push für den Ablauf `off-probe.yml`).
- Eigene Schriftarten (z. B. Noto Nastaliq Urdu, kostenlos unter OFL) würden die App größer machen; bisher nicht eingebaut.
