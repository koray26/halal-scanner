# Quellenübersicht (Stand: 11.10.2026)

Geprüft wurde jede Quelle auf: gelieferte Informationen, kostenlosen automatisierten
Zugang, Registrierung/Schlüssel, Lizenz, Limits. „Live geprüft“ heißt: echte Abfrage am
11.10.2026. Nicht live geprüfte Angaben stammen aus offizieller Dokumentation oder sind als
**ungeprüft** markiert.

**Statusangaben:**
✅ Integriert und erfolgreich getestet ·
🟦 Kostenlos verfügbar, aber noch nicht integriert ·
🔑 Zugang oder Genehmigung erforderlich ·
⛔ Keine geeignete kostenlose Schnittstelle gefunden

## A. Produkt- und Lebensmitteldatenbanken

| Quelle | Liefert | Kostenloser Zugang | Schlüssel | Lizenz | Limits | Status / Test |
|---|---|---|---|---|---|---|
| [Open Food Facts – Produkt-API v2](https://openfoodfacts.github.io/openfoodfacts-server/api/) | Name (alle Sprachen), Marke, Zutaten, strukturierte Zutaten, Labels, Bilder | ja | nein (eigener User-Agent) | ODbL / DbCL / Bilder CC BY-SA | 15 Produktabfragen/Min. | ✅ seit 0.1; live geprüft; Tests mit echten Antworten |
| [Open Food Facts – Taxonomie](https://openfoodfacts.github.io/openfoodfacts-server/api/) | allgemeine Stoffinfos (vegan/vegetarisch, Wikidata) | ja | nein | ODbL | App: 10/Min. | ✅ seit 0.2 |
| [Open Food Facts – Suche (Search-a-licious)](https://search.openfoodfacts.org/docs) | Suche nach Name/Marke/Hersteller | ja | nein | ODbL | App: 10 Suchen/Min. | ✅ neu; live geprüft (Antwort als Testdatei); Suche ist unscharf → nur Trefferliste, keine Zusammenführung |
| [USDA FoodData Central](https://fdc.nal.usda.gov/api-guide) – „Branded Foods“ | GTIN, Produktname, Marke, **Zutatenliste** (Herstellerangaben, US-Markt; Quelle GDSN oder Label Insight) | ja | **ja, kostenlos** ([api.data.gov](https://api.data.gov/signup/)) | Public Domain (CC0 1.0), Quellenangabe erbeten | 1.000/Std. je Schlüssel; DEMO_KEY nur 10/Std. (live gemessen) | ✅ neu; live geprüft mit DEMO_KEY (exakter GTIN-Treffer); Tests simuliert. **In der App nur aktiv mit einem persönlichen Schlüssel, den der Nutzer in den Einstellungen einträgt** (kein Schlüssel eingebaut) |
| [openFDA](https://open.fda.gov/) | Lebensmittel-Rückrufe (u. a. nicht deklarierte Stoffe), unerwünschte Ereignisse – **keine Zutatenlisten** | ja | optional | [openFDA-Lizenz](https://open.fda.gov/license/) (gemeinfrei) | ohne Schlüssel begrenzt | 🟦 live geprüft (`/food/enforcement`); für Zutaten-/Herkunftsprüfung nicht geeignet, später evtl. als Rückruf-Hinweis |
| [Verified by GS1](https://www.gs1.org/services/verified-by-gs1) | Produktidentität (Marke, Hersteller) – keine Zutaten | nur Webformular | – | [Nutzungsbedingungen](https://gs1.org/docs/verified-by-gs1/public-verified-by-gs1-tou.pdf): 30 Abfragen/24 h, nur interne Nutzung | API nur über GS1-Mitgliedsorganisationen | 🔑 nicht integrierbar ohne Mitgliedschaft |
| Hersteller-Websites | Zutaten, Spezifikationen | keine einheitliche Schnittstelle | – | je Hersteller | automatisches Auslesen ohne Erlaubnis unzulässig | ⛔ App zeigt den Herstellerlink und bereitet eine Anfrage-E-Mail vor |
| Weitere nationale Lebensmitteldatenbanken (Europa, Asien, Afrika, Südamerika, Ozeanien) | – | – | – | – | – | **noch nicht recherchiert** – nächster Schritt |

## B. Chemische und wissenschaftliche Datenbanken

| Quelle | Liefert | Kostenloser Zugang | Schlüssel | Lizenz | Limits | Status / Test |
|---|---|---|---|---|---|---|
| [PubChem PUG-REST](https://pubchem.ncbi.nlm.nih.gov/docs/pug-rest) | CID, IUPAC-Name, Summenformel, Synonyme, CAS | ja | nein | NCBI-Daten gemeinfrei; Einsenderdaten je Quelle | max. 5 Anfragen/s | ✅ neu: einmaliger Abruf per `tool/fetch_pubchem.py` (15 Zusatzstoffe, 7 Vergleichsstoffe wie Ethanol/Cetylalkohol), gespeichert mit Abrufdatum. Gemische (E471, Polysorbate, Gelatine …) bewusst **ohne** Eintrag |
| [NCBI E-utilities / PubMed](https://www.ncbi.nlm.nih.gov/books/NBK25501/) | Literatur (Abstracts; Volltexte nur bei PMC) | ja | optional | je Artikel | 3/s ohne Schlüssel | 🟦 live geprüft (Suche „porcine gelatin detection PCR“: 32 Treffer). Liefert allgemeine Studien, **keinen Nachweis für ein konkretes Produkt** |
| [EPA CompTox (CTX APIs)](https://www.epa.gov/comptox-tools/computational-toxicology-and-exposure-apis) | Stoffidentität, Toxikologie | ja | **ja, kostenlos per E-Mail** an ccte_api@epa.gov | – | – | 🔑 nicht integriert |
| [ECHA](https://echa.europa.eu/) | Stoffregistrierungen (REACH) | Webportal | – | ECHA-Bedingungen | – | **ungeprüft** – keine dokumentierte freie API gefunden |
| [EFSA OpenFoodTox](https://www.efsa.europa.eu/) | toxikologische Bewertungen | Download | nein | – | – | 🟦 nicht integriert (Toxikologie, nicht Herkunft) |
| [EU Food Additives Database](https://food.ec.europa.eu/food-safety/food-improvement-agents/additives/database_en) | zugelassene Zusatzstoffe, Verwendungsbedingungen | nur Webdatenbank | – | – | – | ⛔ keine API/Download gefunden; App nutzt die Verordnung (EG) 1333/2008 als eingebautes Wissen |
| JECFA / FAO / WHO | Spezifikationen von Zusatzstoffen | Webdatenbank | – | – | – | **ungeprüft** – keine API gefunden |

## C. Halal-Zertifizierungen

| Quelle | Öffentliche Suche | Schnittstelle | Status |
|---|---|---|---|
| [BPJPH Indonesien](https://bpjph.halal.go.id/) | Websuche nach Produkten | keine dokumentierte öffentliche API gefunden | ⛔ |
| JAKIM Malaysia (Halal-Portal / MyeHALAL) | Websuche | keine dokumentierte API gefunden; MyeHALAL 2.0 angekündigt (Mai 2026) | ⛔ |
| Thailand (CICOT, [halal.or.th](https://www.halal.or.th/)) | Websuche (Produkt-/Zertifikatsnummer) | keine API gefunden – **nicht im Detail geprüft** | ⛔ |
| [IFANCA](https://ifanca.org/) | – | **ungeprüft** | ⛔ |

Automatisches Auslesen dieser Websites wäre ohne Erlaubnis unzulässig. Die App ordnet deshalb
weiterhin **keine Zertifikate** automatisch zu („HALAL-ZERTIFIZIERT“ erscheint nie). Die
Datenstruktur (`Certification`: Barcode, Zertifizierer, Gültigkeit, verifiziert) und ihre Tests
bleiben vorhanden. Nächster Schritt: Zertifizierungsstellen nach offiziellen Datenzugängen fragen.

## D. Laborberichte und Analysen

Es wurde **keine kostenlose Datenbank mit Laborergebnissen zu einzelnen Produkten** gefunden.
Wissenschaftliche Literatur (z. B. DNA-/PCR-Nachweis von Schweinebestandteilen) ist über PubMed
auffindbar, belegt aber nichts über ein konkretes gescanntes Produkt. Die App behauptet nie eine
Laborprüfung.

## Wie die App Quellen verbindet

1. Open Food Facts (Barcode) – führende Quelle.
2. Nur wenn dort kein Produkt oder keine Zutatenliste: USDA FoodData Central, **nur bei exakt
   gleicher GTIN**. Die Zutatenliste wird als eigene Liste mit eigener Quelle angehängt.
3. Jede Abfrage wird protokolliert (gefunden / nicht gefunden / nicht erreichbar / nicht
   eingerichtet / nicht nötig) und unter „Quellen und Begründung“ angezeigt.
4. Ein grünes Ergebnis ist weiterhin nur mit Open-Food-Facts-Zutaten möglich (Freigabebedingung 3,
   unverändert). FDC-Daten können HARAM oder UNKLAR aufdecken, aber nie allein zu Grün führen.
