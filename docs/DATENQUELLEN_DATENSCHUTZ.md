# Datenquellen, Lizenzen und Datenschutz

## Open Food Facts
- API: `https://world.openfoodfacts.org/api/v2/product/{barcode}.json?fields=…`
  (Dokumentation: https://openfoodfacts.github.io/openfoodfacts-server/api/)
- Lizenz: Datenbank **ODbL**, Inhalte **Database Contents License**, Bilder **CC BY-SA**.
  → Quellenangabe erfolgt in der App (Ergebnis → „Quellen und Begründung“, Einstellungen → „Datenquellen“).
- Nutzungsbedingungen: eigener User-Agent `HalalScanner/<Version> (<Kontakt>)`,
  max. **15 Produktabfragen pro Minute und IP** (die App begrenzt sich selbst).
- **Kontakt-E-Mail:** Derzeit Platzhalter. Zum Setzen in GitHub: Settings → Secrets and variables →
  Actions → *Variables* → `CONTACT_EMAIL` anlegen. Die nächsten Builds verwenden sie.
- Gespeichert wird je Produkt: Quelle, Abrufzeit, Datenstand (`last_modified_t`).
- Zusätzlich abgerufen: strukturierte Zutaten (`ingredients`), `ingredients_analysis_tags`, `labels_tags`,
  `categories_tags`, `allergens_tags`, `data_quality_warnings_tags`, `link`, `manufacturing_places`,
  `customer_service`, `unknown_ingredients_n`, `ingredients_n`.
- **Taxonomie-API** `GET /api/v2/taxonomy?tagtype=ingredients&tags=…&fields=name,vegan,vegetarian,wikidata,description`
  für allgemeine Stoffinformationen (höchstens 10 Abfragen pro Minute, Ergebnisse werden zwischengespeichert).
  Antwortformat am 11.10.2026 mit einer echten Abfrage geprüft (`test/fixtures/off/`).
- Open Food Facts ist **keine Zertifizierungsstelle**; die App stellt sie nicht so dar.
- Wikidata-Links (CC0) werden nur als Verweis angezeigt.
- Testdaten in `test/fixtures/off/` stammen aus Open Food Facts (ODbL).

## Weitere Komponenten (alle kostenlos)
| Paket | Zweck | Lizenz |
|---|---|---|
| mobile_scanner | Barcode-Scan (ML Kit / Apple Vision) | BSD-3-Clause |
| google_mlkit_text_recognition | Texterkennung auf dem Gerät | MIT (Plugin); ML Kit unter Google-Bedingungen |
| image_picker, url_launcher, shared_preferences, http | Kamera/Galerie, Links, lokaler Speicher, Netzwerk | BSD-3-Clause |

## Datenschutz (DSGVO-orientiert)
- Keine Konten, keine Werbung, keine Analyse-/Tracking-Werkzeuge, kein eigener Server.
- Übermittelt wird nur die **Barcode-Nummer** an Open Food Facts (dabei technisch die IP-Adresse).
- Produktbilder werden direkt von Open Food Facts geladen.
- Fotos der Zutatenliste werden **nur auf dem Gerät** ausgewertet und danach gelöscht.
- Verlauf/Favoriten/Einstellungen liegen **nur lokal**; löschbar in den Einstellungen oder durch Deinstallation.
- Nutzerhinweise („Weißt du mehr?“) liegen **nur lokal** und werden nur übertragen, wenn der Nutzer sie selbst
  kopiert oder per E-Mail versendet. Es gibt keinen Server.
- Herstelleranfragen werden im E-Mail-Programm des Nutzers vorbereitet; die App versendet nichts selbst.
- Berechtigungen: Kamera (Scannen/Fotografieren), Internet, optional Fotomediathek (iPhone, nur bei Auswahl aus Galerie).

Vor einer Store-Veröffentlichung wird eine öffentlich erreichbare Datenschutzerklärung mit
Verantwortlichem (Name, Anschrift, E-Mail) benötigt – diese Angaben kann nur der Betreiber machen.
