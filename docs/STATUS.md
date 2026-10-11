# Projektstatus (Oktober 2026)

## ✅ Vollständig implementiert und automatisch getestet
- Halal-Regel-Engine mit Regeln A–E, Herkunftsangaben, Widerspruchserkennung, Regelversion
- Zutaten-Parser (Klammern, Spurenhinweise, Dezimalzahlen, Allergenmarkierungen)
- Barcode-Prüfung (EAN-8/13, UPC-A, UPC-E→UPC-A, GTIN-14)
- Open-Food-Facts-Adapter (gefunden, nicht gefunden, Netzwerk-/Server-/Datenfehler, Ratenbegrenzung)
- Lokaler Verlauf, Favoriten, Offline-Anzeige mit Hinweis auf Aktualität
- Übersetzungssystem, Sprachwechsel, RTL (Arabisch), Vollständigkeitsprüfung aller Sprachdateien
- Barrierefreiheit: Tap-Ziele, Beschriftungen, 200 % Schrift ohne Layoutfehler, Status nie nur Farbe
- Android-APK und iOS-Build werden automatisch gebaut

## 🟡 Implementiert, aber noch nicht auf echten Geräten getestet
- Kamera-Scanner (Taschenlampe, Berechtigungsdialog, Doppelscan-Schutz)
- Zutatenfoto mit Texterkennung (ML Kit)
- Links zu Open Food Facts / GitHub
- iPhone-Version insgesamt (nur unsigniert gebaut, nie gestartet)
→ Bitte mit der Checkliste in INSTALLATION.md testen.

## 🟠 Entwurf / eingeschränkt
- Arabisch und Türkisch: vollständig übersetzt, aber **nicht fachlich geprüft** (in der App als „Entwurf“ gekennzeichnet)
- 17 weitere Sprachen: vorbereitet, aber gesperrt („In Vorbereitung“)
- Prüfregeln: noch nicht von Gelehrten geprüft (offene Fragen in HALAL_REGELN.md)
- Texterkennung nur für lateinische Schrift

## ⬜ Noch nicht implementiert
- HALAL-ZERTIFIZIERT in der Praxis (keine kostenlose, verifizierbare Zertifikatsquelle; Logik vorhanden)
- Optionale Nutzerkonten/Synchronisierung, Server, Premium (bewusst weggelassen: 0-€-Budget)
- Einstellbare Rechtsschule
- Eigener Rahmen in der Kameraansicht beim Zutatenfoto (System-Kamera wird verwendet)

## 🔑 Externe Einrichtung nötig (optional, kostenlos)
- `CONTACT_EMAIL` als GitHub-Variable setzen (Open-Food-Facts-Bedingung)
- Fester Android-Signierschlüssel als GitHub-Secret, damit Updates ohne Deinstallieren möglich sind

## ⛔ Wegen Kosten nicht möglich (0-€-Budget)
- Google Play (25 $), App Store / TestFlight (99 $/Jahr), dauerhafte iPhone-Installation

## Technische Risiken
- Die ML-Kit-Plugins unterstützen noch kein Swift Package Manager; Flutter warnt, dass dies künftig ein Fehler wird.
  Vor einem Flutter-Update prüfen.
- Die Flutter-Version ist in der CI fest auf 3.47.7 gesetzt.
