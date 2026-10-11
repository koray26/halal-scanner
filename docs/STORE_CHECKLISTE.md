# Checkliste für eine spätere Store-Veröffentlichung

> Eine Veröffentlichung kostet Geld (Google Play: einmalig 25 $, Apple: 99 $/Jahr) und erfolgt
> **nur nach Ihrer ausdrücklichen Entscheidung** mit Ihren eigenen Entwicklerkonten.

| Punkt | Stand |
|---|---|
| App-Name | „Halal Scanner“ – vor Veröffentlichung auf Markenkonflikte prüfen |
| Paketkennung | Android `io.github.koray26.halal_scanner`, iOS `io.github.koray26.halalScanner` (vor Store-Start ggf. auf eigene Domain ändern – später nicht mehr änderbar) |
| App-Icon | vorhanden (`tool/make_icons.py`, `docs/icon.png`) |
| Startbildschirm | Standard (weiß); optional in Markenfarbe |
| Store-Screenshots | Vorlagen entstehen automatisch in CI (Branch `ci-logs-test/screens`); für den Store echte Gerätefotos verwenden |
| Beschreibung | Entwurf: siehe unten |
| Datenschutzerklärung | Inhalt in DATENQUELLEN_DATENSCHUTZ.md; öffentliche URL + Verantwortlicher fehlen |
| Berechtigungsbegründungen | Kamera, Fotomediathek – in Info.plist hinterlegt |
| Kontakt/Support | E-Mail fehlt (Variable `CONTACT_EMAIL`), GitHub-Issues vorhanden |
| Signierung Android | derzeit Debug-Schlüssel → für Play Store eigenen Upload-Schlüssel erzeugen und als GitHub-Secret hinterlegen |
| Signierung iOS | erfordert Apple Developer Program |
| Tests | über 80 automatische Tests + manuelle Checkliste (INSTALLATION.md) |
| Store-Richtlinien | vor Einreichung aktuelle Google-Play- und App-Store-Richtlinien prüfen (insb. Gesundheits-/Religions-Angaben, Datenschutz-Formulare „Data safety“ / „App Privacy“) |

## Entwurf Kurzbeschreibung
„Barcode scannen, Zutaten prüfen: transparente Halal-Einschätzung mit Begründung und Quellen.“

## Entwurf Beschreibung
Halal Scanner hilft beim Einkaufen: Barcode scannen, und die App prüft die Zutatenliste aus der
freien Datenbank Open Food Facts nach festen, nachvollziehbaren Regeln. Jedes Ergebnis zeigt,
was gefunden wurde, warum es relevant ist, welche Quelle es belegt und was unbekannt bleibt.
Fehlende Angaben werden nie als halal gewertet. Die App ersetzt keine Halal-Zertifizierung.

Nicht verwenden: erfundene Zertifizierungen, Bewertungen oder „100 % sicher“-Versprechen.
