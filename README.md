# Halal Scanner

Mobile App für **Android und iPhone** (Flutter), die Lebensmittel per Barcode oder Foto der Zutatenliste auf ihre Halal-Eignung prüft – mit transparenten, testbaren Regeln.

**Grundsatz:** Keine erfundenen Zutaten. Keine unbelegten Halal-Freigaben. Fehlende oder unsichere Daten führen nie zu „halal“.

Für jede kritische Zutat recherchiert die App automatisch (Stoffidentität/E-Nummer, strukturierte Produktdaten, Herkunftsangaben, Verpackungskennzeichnung, Open-Food-Facts-Taxonomie, Herstellerlink) und zeigt, was belegt ist, was offen bleibt und welche Information die Einstufung klären würde.

## Ergebnisse

| Status | Bedeutung |
|---|---|
| 🔴 **HARAM** | Ein verbotener Bestandteil ist ausdrücklich genannt (z. B. Schweinegelatine, Wein, Alkohol) – mit Fundstelle und Grund. |
| 🟠 **UNKLAR** | Herkunft trotz automatischer Recherche nicht belegt (z. B. Gelatine, Aroma, E471, Lab, Fleisch) oder unter Gelehrten strittig (z. B. Karmin, Weinessig). |
| ⚪ **NICHT VERIFIZIERT** (grau) | Produkt, vollständige Zutatenliste oder entscheidende Informationen fehlen, sind unvollständig, widersprüchlich, nur fotografiert oder von Hand eingegeben. |
| 🟢 **HALAL NACH VOLLSTÄNDIGER ZUTATENPRÜFUNG** | Nur wenn **alle zehn Freigabebedingungen** erfüllt sind (Checkliste in der App). **Keine Zertifizierung, keine Garantie.** |
| 🟢 **HALAL-ZERTIFIZIERT** | Nur mit verifiziertem, gültigem Zertifikat für genau dieses Produkt (derzeit keine kostenlose Quelle angebunden). |

## Download

Die neueste Testversion (APK für Android, unsignierte IPA für iPhone) liegt unter
**Releases → „Neueste Testversion“**. Installationsanleitung: [docs/INSTALLATION.md](docs/INSTALLATION.md).

## Dokumentation

- [Installation auf Android und iPhone](docs/INSTALLATION.md)
- [Halal-Prüfregeln](docs/HALAL_REGELN.md)
- [Architektur](docs/ARCHITEKTUR.md)
- [Datenquellen, Lizenzen, Datenschutz](docs/DATENQUELLEN_DATENSCHUTZ.md)
- [Veröffentlichungs-Checkliste (Stores)](docs/STORE_CHECKLISTE.md)
- [Status: was fertig ist, was nicht](docs/STATUS.md)

## Entwicklung

```bash
flutter pub get
flutter test
flutter run
```

Builds und Tests laufen automatisch über GitHub Actions (`.github/workflows/build.yml`), kostenlos für öffentliche Repositories.

## Daten

Produktdaten: [Open Food Facts](https://world.openfoodfacts.org) – Open Database License (ODbL), Bilder CC BY-SA.

## Hinweis

Diese App ersetzt keine Halal-Zertifizierung und keine religiöse Beratung. Die Regeln wurden noch nicht von einem Gelehrtengremium geprüft.
