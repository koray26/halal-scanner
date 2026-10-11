# App installieren und testen

Diese Anleitung ist für Menschen ohne Programmierkenntnisse geschrieben.
Alle beschriebenen Wege sind **kostenlos**.

---

## A) Android-Handy (einfach, dauerhaft)

### 1. APK herunterladen
1. Öffnen Sie **auf dem Android-Handy** den Browser (z. B. Chrome).
2. Gehen Sie zu: **https://github.com/koray26/halal-scanner/releases**
3. Tippen Sie bei **„Neueste Testversion“** unter „Assets“ auf **`HalalScanner.apk`**.
4. Falls eine Warnung kommt („Datei kann schädlich sein“): **„Trotzdem herunterladen“**.
   Die Warnung erscheint bei jeder App, die nicht aus dem Play Store kommt.

### 2. Installieren
1. Tippen Sie auf die heruntergeladene Datei (Benachrichtigung oder Ordner „Downloads“).
2. Android fragt: *„Aus dieser Quelle installieren?“* → **Einstellungen** →
   Schalter **„Aus dieser Quelle zulassen“** einschalten → zurück.
3. **Installieren** tippen.
4. Falls *Google Play Protect* warnt („Unbekannte App“): **„Weitere Details“ → „Trotzdem installieren“**.
5. App öffnen, Sprache wählen, beim ersten Scan **Kamerazugriff erlauben**.

### 3. Aktualisieren
Jede neue Testversion wird zurzeit mit einem neuen Test-Schlüssel signiert.
Deshalb vor dem Installieren einer neuen Version: **alte App deinstallieren**
(lange auf das App-Symbol drücken → „Deinstallieren“). Der Verlauf geht dabei verloren.
*(Das lässt sich später mit einem festen Schlüssel ändern – siehe STATUS.md.)*

---

## B) iPhone (kostenlos, aber mit Einschränkungen)

### Was Apple erlaubt – ehrlich erklärt
| Weg | Kosten | Haltbarkeit |
|---|---|---|
| App Store / TestFlight | 99 $ pro Jahr (Apple Developer Program) | dauerhaft |
| **Kostenlose Apple-ID + Signier-Werkzeug** | **0 €** | **7 Tage**, danach neu signieren |
| Kostenlose Apple-ID + Mac mit Xcode | 0 € (Mac nötig) | 7 Tage |

Mit kostenloser Apple-ID gilt außerdem: höchstens **3 selbst installierte Apps** gleichzeitig.

### Weg 1: Windows-PC + Sideloadly (ohne Mac)
> Sideloadly ist ein kostenloses Programm eines Drittanbieters (nicht von Apple, nicht von uns).
> Sie geben darin Ihre Apple-ID ein; sie wird zum Signieren an Apple übermittelt.
> Wenn Sie das nicht möchten, legen Sie dafür eine **zweite, kostenlose Apple-ID** an.

1. Auf dem PC **iTunes** und **iCloud** installieren – die Versionen **direkt von apple.com**
   (nicht aus dem Microsoft Store), weil Sideloadly die Apple-Treiber braucht.
2. **Sideloadly** von der offiziellen Seite `sideloadly.io` herunterladen und installieren.
3. Auf dem PC unter **https://github.com/koray26/halal-scanner/releases** die Datei
   **`HalalScanner-unsigniert.ipa`** herunterladen.
4. iPhone per **USB-Kabel** anschließen, entsperren, „Diesem Computer vertrauen“ bestätigen.
5. Sideloadly öffnen → die `.ipa`-Datei in das Fenster ziehen → Apple-ID eingeben → **Start**.
   Ggf. den Bestätigungscode eingeben, den Apple auf Ihre Geräte schickt.
6. Auf dem iPhone:
   - **Einstellungen → Allgemein → VPN und Geräteverwaltung** → Ihre Apple-ID antippen → **Vertrauen**.
   - Ab iOS 16: **Einstellungen → Datenschutz & Sicherheit → Entwicklermodus** einschalten,
     iPhone neu starten, Entwicklermodus bestätigen.
7. App öffnen. **Nach 7 Tagen** startet sie nicht mehr → Schritte 4–5 wiederholen
   (Ihre Daten in der App bleiben dabei normalerweise erhalten).

### Weg 2: Mac mit Xcode (falls Sie einen Mac leihen können)
1. Xcode aus dem Mac App Store installieren, Flutter installieren (flutter.dev).
2. `git clone https://github.com/koray26/halal-scanner` → `cd halal-scanner` → `flutter pub get`
3. `open ios/Runner.xcworkspace` → Runner → *Signing & Capabilities* → Team: Ihre Apple-ID,
   Bundle Identifier eindeutig machen (z. B. `io.github.IHRNAME.halalScanner`).
4. iPhone anschließen, oben auswählen, ▶ drücken. Danach wie oben „Vertrauen“ und Entwicklermodus.

---

## C) Was Sie testen sollten (Checkliste)

Bitte notieren Sie, was nicht funktioniert, und schicken Sie es mir (oder als „Issue“ auf GitHub).

- [ ] Sprache beim ersten Start wählen; später in Einstellungen wechseln (auch Arabisch → Text von rechts nach links).
- [ ] **Produkt scannen**: Barcode in den Rahmen halten → Ergebnis erscheint automatisch.
- [ ] Taschenlampe ein/aus, Scanner schließen.
- [ ] Barcode **manuell eingeben** (z. B. eine falsche Zahl → verständliche Fehlermeldung).
- [ ] Ergebnis: Status mit Farbe, Symbol **und** Text; „Zutaten anzeigen“; „Quellen und Begründung“.
- [ ] Produkt, das es nicht in der Datenbank gibt → NICHT VERIFIZIERT + Angebot zum Fotografieren.
- [ ] **Zutaten fotografieren**: Foto → Text prüfen/korrigieren → Haken setzen → „Zutaten prüfen“.
- [ ] Favorit setzen (Stern), Verlauf ansehen, Eintrag löschen (nach links wischen).
- [ ] **Flugmodus**: früher gescanntes Produkt erneut scannen → gespeichertes Ergebnis mit Warnhinweis.
- [ ] Dunkelmodus, große Schrift (Telefon-Einstellungen), Bildschirmleser (TalkBack / VoiceOver).

**Wichtig:** Vergleichen Sie Ergebnisse stichprobenartig mit der Verpackung. Die App ist eine Testversion
und ersetzt keine Halal-Zertifizierung.
