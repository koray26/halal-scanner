# Architektur

```
lib/
├─ main.dart, app.dart          Start, Thema, Sprache/RTL, Navigation (5 Tabs)
├─ config.dart                  App-Name, Version, User-Agent, Open-Food-Facts-Felder
├─ core/
│  ├─ i18n/strings.dart         Übersetzungssystem (assets/i18n/*.json), Sprachliste, RTL
│  ├─ theme/app_theme.dart      Designsystem: Farben, Abstände, Radien, Statusfarben/-symbole
│  └─ widgets/widgets.dart      Logo, Statusanzeige, Karten, Leerzustände
├─ domain/                      Reines Dart, ohne Flutter → vollständig testbar
│  ├─ barcode.dart              GTIN-Prüfziffer, UPC-E→UPC-A, Produktvergleich
│  ├─ models.dart               Produkt (inkl. strukturierter OFF-Zutaten), Zutatenliste, Quelle, Zertifikat
│  ├─ knowledge/substances.dart Stoffwissen: E-Nummern, Stoffklassen, mögliche Herkünfte, Prüffragen
│  ├─ knowledge/pubchem_data.dart PubChem-Stoffidentität (erzeugt von tool/fetch_pubchem.py)
│  ├─ research/research.dart    Recherche-Pipeline je Zutat (Schritte, Belege, Prüffragen)
│  └─ rules/
│     ├─ catalog.dart           Versionierte Wortlisten (siehe HALAL_REGELN.md)
│     ├─ ingredient_parser.dart Zerlegung der Zutatenliste in einen Baum
│     ├─ halal_engine.dart      Entscheidungslogik, Bericht-Daten
│     └─ dimensions.dart        Abgeleitete Sachaussagen: Schwein / Alkohol (ändert keine Regel)
├─ data/
│  ├─ open_food_facts.dart      Produkt-API (v2) + Taxonomie-API, Ratenbegrenzung, Fehlerbehandlung
│  ├─ off_search.dart           Produktsuche nach Name/Marke (Search-a-licious)
│  ├─ usda_fdc.dart             USDA FoodData Central (GTIN-Abgleich) + Zusammenführung
│  ├─ feedback_store.dart       Unbestätigte Nutzerhinweise (lokal) + Export
│  └─ history_store.dart        Verlauf/Favoriten/Einstellungen lokal (shared_preferences)
├─ state/app_state.dart         App-Zustand, Scan-/Foto-Ablauf, Offline-Rückfall
└─ features/                    Bildschirme: home, scanner, result, ocr, history, settings
```

## Datenfluss beim Scan
1. `ScannerScreen` (mobile_scanner, EAN-8/13, UPC-A/E) → Prüfziffer → Doppelscan-Schutz (3 s).
2. `AppState.lookup` → `OpenFoodFactsClient.fetch` → `ProductRecord` (mit Quelle + Abrufzeit).
   Kein Produkt oder keine Zutaten → (falls Schlüssel gesetzt) `UsdaFdcClient.fetchByGtin`,
   nur bei exakt gleicher GTIN → `mergeProductSources`. Jede Abfrage landet als `SourceCheck` im Scan.
3. `AppState.evaluateWithResearch`: erster Durchgang offline → für offene Zutaten Abfrage der
   Open-Food-Facts-Taxonomie → zweiter Durchgang mit `ResearchContext`.
4. `HalalEngine.evaluate` → für jede kritische Zutat `ResearchPipeline.investigate` → `Verdict`
   (Status, Untersuchungen je Zutat, Freigabebedingungen, Unbekanntes, Aussagekraft, Regelversion).
5. Ergebnis wird lokal gespeichert (Verlauf). Bei Netzwerkfehler: gespeichertes Ergebnis mit Warnhinweis.

## Foto-Ablauf
`image_picker` → Google ML Kit Texterkennung (offline, lateinische Schrift) → Foto sofort löschen →
Text anzeigen/korrigieren → `IngredientText(source: ocrPhoto | userEdited)` → Bewertung.
Foto/Nutzertext kann nie zu einer Halal-Freigabe führen (Regel E), wohl aber HARAM/UNKLAR anzeigen.

## Warum kein Backend?
Die App braucht keine geheimen Schlüssel (Open Food Facts ist offen) und keine Konten.
Ein Server würde Kosten, Wartung und Datenschutzpflichten verursachen, ohne die Prüfung zu verbessern.
Die Datenstrukturen (`SourceRef`, `Certification`, Regelversion) sind so angelegt, dass später ein
Backend (z. B. Supabase mit Row Level Security) für Nutzerkorrekturen, geprüfte Produkte und
Zertifikate ergänzt werden kann – siehe STATUS.md.

## Build & Tests
GitHub Actions (`.github/workflows/build.yml`): Analyse → 130 automatische Tests → Bildschirmfotos →
Android-APK (universal + arm64) → iOS-Build ohne Signatur → Veröffentlichung unter Releases.
Die Protokolle landen zusätzlich in den Branches `ci-logs-test`, `ci-logs-android`, `ci-logs-ios`.
