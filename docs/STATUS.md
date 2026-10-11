# Projektstatus (Version 0.2.0, Oktober 2026)

## ✅ Implementiert und automatisch getestet (130 Tests, GitHub Actions)
- Vier Ergebnisfarben: ROT HARAM · ORANGE UNKLAR · GRAU NICHT VERIFIZIERT · GRÜN HALAL NACH VOLLSTÄNDIGER ZUTATENPRÜFUNG (+ HALAL-ZERTIFIZIERT nur mit verifiziertem Zertifikat)
- Zehn ausdrückliche Freigabebedingungen für Grün, als Checkliste in der App sichtbar
- Automatische Recherche je kritischer Zutat (6 Schritte, siehe HALAL_REGELN.md), mit Prüffragen, Belegen, Quellenlinks, offenen Fragen und „Was würde klären?“
- Stoffwissen zu 42 Zusatzstoffen (E-Nummer ↔ Name, Stoffklasse) und 12 Stoffgruppen (mögliche Herkünfte, Prüffragen)
- Vollständiger Abruf strukturierter Open-Food-Facts-Daten (Unterzutaten, Labels, Kategorien, Allergene, Herstellerlink, Datenqualitäts-Warnungen)
- Open-Food-Facts-Taxonomie als Online-Quelle; bei Ausfall wird „nicht erreichbar – nicht geprüft“ angezeigt
- Nicht unterstützte Sprachen: HARAM/UNKLAR über die Datenbank-Zutatenanalyse erkennbar, nie Grün
- Nutzerhinweise („Weißt du mehr?“): lokal, unbestätigt, mit Barcode/Zutat/Quelle/Zeit; Export per Kopieren oder E-Mail; ändern nie das Ergebnis
- Vorbereitete Herstelleranfrage per E-Mail (Versand durch den Nutzer)
- Texterkennung: Worttrennungen werden zusammengefügt, nicht unterstützte Schrift wird erkannt und blockiert Grün
- Netzwerk: Zeitüberschreitung, leere Antwort, API-Limit, kaputte Daten, offline mit gespeichertem Ergebnis
- Tests mit echten Open-Food-Facts-Antworten (4 Produkte + Taxonomie, Abruf Oktober 2026)
- Test, dass keine Sprachdatei „100 % halal“, „garantiert halal“ o. Ä. enthält
- Android-APK und iOS-Build (unsigniert) werden automatisch gebaut

## 🟡 Implementiert, aber NICHT auf echten Geräten getestet
Es wurde **kein echtes Gerät** getestet – weder Android noch iPhone. Ungetestet sind insbesondere:
- Kamera-Scanner (Erkennung, Taschenlampe, Berechtigungsdialog)
- Foto der Zutatenliste und Texterkennung (ML Kit)
- Öffnen von Links, E-Mail-Programm (Herstelleranfrage, Hinweis-Export), Zwischenablage
- Echte Online-Recherche über das Handy-Netz (in CI nur mit Testdaten und einmaliger Formatprobe geprüft)
- iPhone-Version insgesamt (nur unsigniert gebaut)
→ Checkliste in INSTALLATION.md, Abschnitt C.

## 🟠 Grenzen (ehrlich)
- **Aromen bleiben fast immer UNKLAR**: Hersteller müssen Trägerstoffe wie Alkohol nicht angeben, und es gibt keine kostenlose Quelle dafür.
- **Keine automatische Herstellerabfrage**: Herstellerseiten haben keine offene Schnittstelle; die App zeigt den Link und bereitet eine E-Mail vor.
- **Keine Zertifikatsdatenbank**: HALAL-ZERTIFIZIERT erscheint derzeit nie.
- Vegan-/Vegetarisch-Kennzeichnungen stammen von Open-Food-Facts-Nutzern (Verpackungsangabe, nicht verifiziert).
- Arabisch und Türkisch: Entwurf, nicht fachlich geprüft. 17 Sprachen gesperrt.
- Texterkennung nur lateinische Schrift.
- Regeln nicht von islamischen Fachpersonen geprüft (offene Fragen in HALAL_REGELN.md, Abschnitt 9).

## ⬜ Nicht implementiert
- Zentrale Sammlung von Nutzerhinweisen (bräuchte einen Server → Kosten/Datenschutz); stattdessen lokal + freiwilliger Export
- Einstellbare Rechtsschule
- Konten, Synchronisierung, Premium

## ⛔ Kosten
Es wurden **keine kostenpflichtigen Dienste** aktiviert. Genutzt: GitHub Actions (kostenlos für öffentliche
Repositories), Open Food Facts (kostenlos), Google ML Kit auf dem Gerät (kostenlos).

## Technische Risiken
- ML-Kit-Plugins unterstützen noch kein Swift Package Manager (Flutter-Warnung beim iOS-Build).
- Flutter-Version in CI fest: 3.47.7.
- Jede Testversion wird mit einem neuen Test-Schlüssel signiert → vor Updates alte App deinstallieren.
