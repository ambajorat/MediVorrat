# MediVorrat – Projektprotokoll

Eigene iOS-App für Medikamentenvorrat und Rezeptanfragen. SwiftUI, iOS 26, XcodeGen (project.yml), Bundle-ID de.bajorat.medivorrat, Repo-Ort ~/github/MediVorrat.

---

## 05.10.2026 – Fix: App auf Englisch trotz deutschem iPhone; Wöchentlich nachgezogen (ZIP MediVorrat-Fix-Sprache.zip)

**Problem:** Auf dem iPhone mit Deutsch lief die App auf Englisch. Der Umschalter Täglich/Wöchentlich fehlte, weil das ZIP MediVorrat-Woechentlich.zip nicht eingespielt war (Repo-Stand „Version 1.1 (2)“ ohne weeklyDay).

**Ursache (Sprache):** Der Katalog hatte nur englische Einträge. Xcode hat für die Ausgangssprache Deutsch offenbar keine eigene Tabelle erzeugt; iOS hat Deutsch deshalb nicht als Sprache der App erkannt und ist auf CFBundleDevelopmentRegion = en zurückgefallen.

**Geändert**
- Localizable.xcstrings: jeder Eintrag zusätzlich mit ausdrücklicher deutscher Fassung (184 Einträge, Wert = deutscher Text)
- project.yml: CFBundleLocalizations [de, en] in der Info.plist
- Wöchentliche Einnahme aus dem vorigen Paket auf den Stand „Version 1.1 (2)“ übertragen (Models, Store, MedicationDetailView, MedicationRow, Katalog)

**Merke**
- Neue Texte im Katalog immer mit de- UND en-Eintrag anlegen
- Kontrolle nach dem Build: im .app-Paket müssen de.lproj und en.lproj liegen (Befehl im Chat)
- Sprache pro App prüfbar unter iOS-Einstellungen → Apps → MediVorrat → Sprache

**Offene Punkte**
- Einspielen, sauber neu bauen, auf dem iPhone Deutsch und Englisch prüfen; Wöchentlich testen
- Dann archivieren als 1.1 (2) (noch nicht hochgeladen) bzw. 1.1 (3), falls 1.1 (2) schon oben ist

---

## 05.10.2026 – Englische Fassung, Mail-Sprache, Region Deutschland (ZIP MediVorrat-Englisch.zip)

**Entscheidungen André:** Englisch für internationale Nutzer; Deutschland-Spezifisches (Gesundheitskarte, E-Rezept) nur bei Region Deutschland; Sprache der Rezept-Mail als eigene Einstellung; App + Store-Texte + Datenschutzseite englisch.

**Geändert**
- NEU Localizable.xcstrings: Ausgangssprache Deutsch (Schlüssel = deutscher Text), 177 englische Übersetzungen; Platzhalter %@ (Text) und %lld (Zahl), Positionsangaben wo nötig (Q%1$@ %2$@)
- NEU de.lproj/ und en.lproj/InfoPlist.strings: Kamera- und Health-Texte zweisprachig
- project.yml: CFBundleDevelopmentRegion en (dritte Sprachen fallen auf Englisch zurück), SWIFT_EMIT_LOC_STRINGS + LOCALIZATION_PREFERS_STRING_CATALOGS = YES (Xcode trägt fehlende Texte beim Build selbst in den Katalog ein)
- Models: AppRegion.isGermany (Locale.current.region == DE) und appLanguage; AppSettings.mailLanguage (nil = App-Sprache), mailLang, wantsERezept (nur DE); InsuranceCard.state und needsReading liefern außerhalb DE „aus“; StockStatus.label und quarterLabel lokalisiert („4. Quartal 2026“ / „Q4 2026“, Jahr als Text gegen Tausenderpunkt); Date.englishDate, numericDay
- Store: Rezept-Mail (Betreff, Klartext, HTML-Tabelle, E-Rezept- und Kartensatz) fest in DE und EN, gewählt über settings.mailLang; Demo-Modus mit englischen Personalien bei englischer App
- Notifications: Texte lokalisiert, Aufzählung über ListFormatter („A, B und C“ / „A, B, and C“)
- Views: alle String-Wege (Toast, Scanner-Kopf, Navigationstitel mit Medikamentname, Link-Zeilen, Ternär-Ausdrücke) auf String(localized:) bzw. if/else umgestellt, damit sie im Katalog landen; Karten-Abschnitt nutzt Gerätedatum statt festem deutschen Format
- SettingsView: Picker „Sprache der Rezept-Mail“ (Deutsch/English) im Praxis-Abschnitt; E-Rezept-Schalter und Gesundheitskarte nur bei Region DE
- AppInfo: Datenschutz-URL je App-Sprache (DE /medivorrat-datenschutz.html, EN /en/medivorrat-privacy.html); Store-Links ohne /de/
- PackCode: Stückzahl-Erkennung auch für tablets, capsules, caplets, softgels, pills, pcs, count
- Website (blaseunddarm-website): NEU en/medivorrat-privacy.html im EN-Layout; deutsche Seite Stand 5.10.2026, Kartendatum und Mail-Sprache in Abschnitt 3, hreflang + Sprachumschalter; sitemap.xml um beide Seiten ergänzt
- NEU MediVorrat-AppStore-Texte-EN.md: Name „MediVorrat – Refill Tracker“, Untertitel, Werbetext, Schlagwörter (96 Zeichen), Beschreibung, Neuerungen 1.1 (EN + DE aktualisiert)

**Merke**
- Neue Texte in Views: Literale direkt in Text/Button/Label sind automatisch lokalisierbar; alles, was als String-Variable durchgereicht wird, braucht String(localized:)
- Mail-Texte stehen absichtlich nicht im Katalog (eigene Sprache unabhängig von der App)
- Region-Test: Simulator → Einstellungen → Allgemein → Sprache & Region; Region DE mit Sprache Englisch zeigt Karte/E-Rezept, Region UK nicht

**Offene Punkte**
- xcodegen-Version prüfen (String Catalogs ab 2.38), xcodegen generate, Build; im String-Katalog nach „New“/„Stale“ schauen und fehlende Übersetzungen melden
- Test auf Englisch (Simulator Sprache English, Region UK und Region Deutschland)
- Website deployen (Befehl im Chat), dann EN-Datenschutz-URL in App Store Connect
- App Store Connect: English (U.S.) + English (U.K.) hinzufügen; überlegen, Primärsprache auf Englisch zu stellen
- Englische Screenshots (Demo-Modus mit englischer App-Sprache)

---

## 05.10.2026 – Versionsnummer kam nicht im Archiv an (Info.plist)

**Ursache:** XcodeGen schreibt ohne ausdrückliche Angabe feste Werte CFBundleShortVersionString „1.0“ und CFBundleVersion „1“ in die Info.plist. Xcode zeigte unter General 1.1 / 1, das Archiv übernahm aber die festen Werte – deshalb waren auch alle früheren Archive 1.0 (1), obwohl Build 2 und 3 eingestellt waren.

**Geändert**
- project.yml → info.properties: CFBundleShortVersionString = $(MARKETING_VERSION), CFBundleVersion = $(CURRENT_PROJECT_VERSION); danach xcodegen generate, Commit + Push
- Versionsstand jetzt 1.1 (1)

**Merke**
- Nach xcodegen generate prüfen: grep -A1 CFBundleShortVersionString MediVorrat/Info.plist muss $(MARKETING_VERSION) zeigen
- Gleiches Muster in anderen XcodeGen-Projekten prüfen (BDM, Ascendor, figo, TurnyRemote)
- App Store Connect: Ist 1.0 noch nicht veröffentlicht, Versionsnummer auf der Versionsseite auf 1.1 ändern; sonst neue Version 1.1 per „+“ anlegen

**Offene Punkte**
- Neu archivieren, Organizer muss 1.1 (1) zeigen, hochladen
- Alte Archive 1.0 (1) vom 05.10. im Organizer löschen
- Gesundheitskarte auf dem Gerät testen
- App-Store-Einreichung (Texte, Screenshots, Datenschutz-URL) weiter offen

---

## 05.10.2026 – Version 1.1 (Build 1)

**Geändert**
- project.yml: MARKETING_VERSION 1.1, CURRENT_PROJECT_VERSION 1 (per sed im Terminal), danach xcodegen generate
- Gesundheitskarten-Paket war eingespielt und committet; Xcode zeigte den alten Stand → Xcode beenden, DerivedData löschen, neu öffnen

**Merke**
- Build-Nummer darf bei neuer Marketing-Version wieder bei 1 beginnen; innerhalb von 1.1 bei jedem Upload erhöhen
- Leeres git status + Treffer bei grep = Paket ist drin, dann liegt es nur an Xcode

**Offene Punkte**
- Build 1.1 (1) testen (Gesundheitskarte), archivieren und hochladen
- App-Store-Einreichung (Texte, Screenshots, Datenschutz-URL) weiter offen

---

## 05.10.2026 – Gesundheitskarte: Einlesen pro Quartal (ZIP MediVorrat-Karte.zip)

**Wunsch André:** Bei Dauermedikation muss die Krankenkassenkarte einmal im Quartal in der Praxis eingelesen werden. Datum erfassen, bei der Rezeptanfrage prüfen und Hinweis geben.

**Geändert**
- Models: AppSettings.cardCheck (Standard an) und cardReadDate; AppSettings dekodiert jetzt tolerant (decodeIfPresent für alle Felder, init in Extension, damit AppSettings() bleibt) – alte Dateien und iCloud-Stände laden weiter. NEU enum InsuranceCard: Kalenderquartale (Q1 Jan–Mär …), Zustände off / unknown / valid / endingSoon (< 7 Tage bis Quartalsende) / expired, quarterLabel („4. Quartal 2026“), needsReading(on:) für Erinnerungstage. Date.germanDate („02.10.2026“)
- Store: cardState, markCardRead(_:) (Standard heute, Tagesbeginn); Rezept-Mail (Klartext + HTML) enthält bei gültiger Karte „Meine Gesundheitskarte wurde in diesem Quartal am … bei Ihnen eingelesen.“; Demo-Modus: Karte vor 3 Tagen eingelesen
- PrescriptionView: Abschnitt „Gesundheitskarte“ ganz oben (wenn Prüfung an): Status (rot: im aktuellen Quartal nicht eingelesen, orange: noch nie erfasst bzw. Quartal endet bald, Petrol: gültig bis …), Datumswähler „Eingelesen am“ (nicht in der Zukunft), Knopf „Heute in der Praxis eingelesen“. Komponente CardCheckSection liegt in PrescriptionView.swift (keine neue Datei → kein xcodegen nötig)
- SettingsView: CardCheckSection mit Schalter „Quartalsweise an die Karte erinnern“ nach dem Praxis-Abschnitt (zum Ausschalten bei Privatversicherung)
- ContentView: Hinweisbalken „Rezept jetzt anfordern“ zeigt zusätzlich „Gesundheitskarte in diesem Quartal noch nicht eingelesen“
- Notifications: reschedule(items:settings:) statt (items:hour:); an Tagen mit Anfordern/Nachfassen/Vorrat-Ende Zusatzzeile „Gesundheitskarte im N. Quartal JJJJ noch nicht eingelesen“ – je Erinnerungstag geprüft, also auch richtig für Tage im nächsten Quartal

**Merke**
- Kartendatum liegt in den Einstellungen und läuft damit über iCloud auf alle Geräte
- Neue Felder in AppSettings immer in CodingKeys und im init(from:) der Extension nachziehen

**Offene Punkte**
- Build in Xcode, Fehlermeldungen zurückgeben (Code ungetestet kompiliert)
- Test: Datum auf letztes Quartal setzen → roter Hinweis in Rezeptanfrage und auf der Startseite; „Heute eingelesen“ → grün, Satz in der Mail
- Build-Nummer erhöhen, falls Build 3 schon hochgeladen ist; App-Store-Einreichung (Texte, Screenshots, Datenschutz-URL) weiter offen

---

## 01.10.2026 – Build-Fehler „Store has no member isDemo“ behoben

**Ursache:** Das Erinnerungen-ZIP enthielt nur drei Dateien; die neue ContentView fragt store.isDemo ab, der lokale Store.swift stammte aber noch von vor dem Demo-Modus (Komplett-ZIP mit Demo war nie eingespielt).

**Lösung:** Gesamtstand MediVorrat-Komplett.zip eingespielt (Demo-Modus, Erinnerungen, App-Store-ID 6817087723, Build 3, NSHealthUpdateUsageDescription), xcodegen generate, Commit + Push. Projektprotokoll liegt ab jetzt auch im Repo (MEDIVORRAT.md).

**Merke**
- Vor Teil-ZIPs prüfen, ob das vorige Paket eingespielt wurde – sonst immer die Komplett-ZIP liefern
- Xcode-Hinweis „Update to recommended settings“ ignorieren (xcodegen überschreibt die Projektdatei)

**Offene Punkte**
- Erinnerungen testen (Mitteilungen erlauben, Medikament morgen fällig, App geschlossen lassen)
- Build-Nummer auf 4, falls Build 3 schon hochgeladen ist; dann archivieren und hochladen
- In App Store Connect: Texte, Screenshots (appstore-medivorrat.zip), Datenschutz-URL eintragen, einreichen
- Datenschutzseite deployen, falls noch nicht geschehen

---

## 01.10.2026 – Erinnerungen ohne App-Öffnen (ZIP MediVorrat-Erinnerungen.zip)

**Wunsch André:** Erinnern, auch wenn die App nicht geöffnet wird – der Bestand nimmt täglich ab, angesehen wird er selten.

**Geändert**
- Notifications.swift neu: plant bei jedem Öffnen/Speichern den kompletten Erinnerungskalender im Voraus (Verbrauch nach Plan ist vorhersehbar). Pro Medikament: Anfordern-Tag „Rezept anfordern“, danach alle 3 Tage Nachfassen bis 3 Tage vor Ende, 3 Tage vor Ende „Vorrat geht zu Ende“; angefragte Medikamente 3 Tage vor Ende „Packung schon da?“. Pro Tag EINE Mitteilung mit allen fälligen Medikamenten (dringendste Art gewinnt), Kennung mv_day_<Tag>, max. 60 geplant (iOS-Grenze 64), alte order_-Kennungen werden mit aufgeräumt. Vergangene Termine rutschen auf den nächsten planbaren Tag (heute, wenn die Erinnerungsstunde noch kommt, sonst morgen). App-Symbol-Badge = Anzahl jetzt fälliger Rezepte, in der Mitteilung = fällige des Tages
- ContentView: fragt beim ersten angelegten Medikament automatisch nach der Mitteilungs-Erlaubnis (nicht im Demo-Modus)
- SettingsView: echter Mitteilungs-Status (nicht gefragt → „Mitteilungen erlauben“; abgelehnt → Sprung in die iOS-Mitteilungseinstellungen + roter Hinweis; erlaubt → „Erlaubt“). Vorher stand „Mitteilungen erlauben“ immer da. Fußtext erklärt die Erinnerungsfolge

**Merke**
- Markieren als angefragt bzw. Einbuchen plant sofort neu → Nachfass-Erinnerungen verschwinden
- Mit Apple Health: Planung nutzt Stück pro Tag; übersprungene Dosen verschieben den Termin erst beim nächsten Öffnen

**Offene Punkte**
- Test: Mitteilungen erlauben, Vorlauf so setzen, dass ein Medikament morgen fällig wird, App schließen, Mitteilung abwarten
- Build-Nummer erhöhen, falls Build 3 schon hochgeladen ist

---

## 28.09.2026 – App-Store-Screenshots (ZIP appstore-medivorrat.zip)

**Entscheidung André:** Kein Demo-Modus, echte Medikamente in den Screenshots; alles, was nicht drauf darf, wird weggeschnitten.

**Erstellt**
- Fünf Store-Bilder im BDM-Stil: Leinen #F6F3EC, Punktepaar Orange/Flieder, Headline Newsreader (opsz 72, wght 215, 102 px, Grundlinien 314/438, #1D2726), Subline Atkinson 45 px (Grundlinie 552, #5C6B69), Screen 956 px breit ab y 650, Radius 80, weicher Schatten
- Reihenfolge: 01 „Wie lange reicht dein Vorrat?“ (Startseite) · 02 „Rezept anfragen mit einem Tipp“ · 03 „Packung scannen, fertig.“ · 04 „Rechtzeitig ans Rezept denken“ (Liste) · 05 „Mit Apple Health oder ohne“ (Einstellungen)
- Zuschnitte: Statusleiste mit Dynamic Island (BDM-Live-Aktivität, Fußball-App) bei allen weg; Sheet-Hintergrund („eliquis“-Schatten) weg; Liste ab obgemsa (halbe Eliquis-Karte weg); Einstellungen ab erster Karte (unscharfes „Planung“ weg); Startseite unten nach dem Rezept-Knopf
- Größen: 69zoll/ 1290×2796 und 65zoll/ 1284×2778
- Quellen: IMG_5488–5492 (iPhone, 1206×2622), Skript make.py

**Offene Punkte**
- Mail-Fenster-Screenshot fehlt noch (optional als 6. Bild)
- Store-Bilder in App Store Connect hochladen, Texte übernehmen, einreichen

---

## 28.09.2026 – Demo-Modus für App-Store-Screenshots (ZIP MediVorrat-Komplett.zip)

**Geändert**
- Store: Startargument -demoData lädt Beispieldaten (Ramipril 5 mg jetzt fällig, Metformin 1000 mg bald, Simvastatin 20 mg angefragt, Pantoprazol 40 mg und L-Thyroxin 75 µg reichen; Max Mustermann, geb. 12.03.1968, Hausarztpraxis am Markt, praxis@example.de; zwei bekannte Packungen bei Ramipril). Im Demo-Modus kein Speichern, kein iCloud, keine Erinnerungen – echte Daten bleiben unberührt

**Screenshot-Plan (6,9 Zoll, Simulator iPhone Pro Max, Dunkelmodus, Statusleiste per simctl 9:41)**
1. Startseite mit Übersicht – 2. Medikament-Detail – 3. Rezept anfragen – 4. Mail-Fenster mit Tabelle – 5. Packung scannen (echtes Gerät, Demo-Packung) – 6. Einstellungen Health/iCloud/Info
- Danach Komposition im BDM-Store-Stil (Leinen #F6F3EC, Newsreader-Headline, Atkinson-Subline), KEINE nachgezeichneten Statusleisten

**Merke**
- Nie eigene echte Medikamente in Store-Screenshots

---

## 28.09.2026 – Upload-Fehler 90683: NSHealthUpdateUsageDescription

**Ursache:** Mit dem HealthKit-Entitlement verlangt Apple beim Upload beide Health-Texte in der Info.plist – auch wenn die App nichts in Health schreibt.

**Geändert**
- project.yml: NSHealthUpdateUsageDescription („MediVorrat schreibt nichts in Apple Health …“) ergänzt, Build 3

**Merke**
- HealthKit-Entitlement ⇒ immer NSHealthShareUsageDescription UND NSHealthUpdateUsageDescription

---

## 28.09.2026 – App Store Connect angelegt, App-Store-ID eingetragen

**Stand**
- Name „MediVorrat“ in App Store Connect vergeben (Xcode-Upload scheiterte an der automatischen Eintragsanlage) → Store-Name „MediVorrat – Rezept & Bestand“, Homescreen-Name bleibt „MediVorrat“; Untertitel „Medikamente im Blick behalten“, Schlagwort „Bestand“ → „Blister“
- App-Store-Apple-ID: 6817087723 (AppInfo.appStoreID) → „App bewerten“ und „App empfehlen“ jetzt sichtbar; Bewertungslink https://apps.apple.com/app/id6817087723?action=write-review
- project.yml: CURRENT_PROJECT_VERSION 2

**Merke**
- Build-Nummer bei jedem Upload erhöhen (CURRENT_PROJECT_VERSION in project.yml, danach xcodegen generate)

**Offene Punkte**
- Datenschutzseite deployen und URL in App Store Connect eintragen
- Texte aus MediVorrat-AppStore-Texte.md übernehmen, Screenshots
- Scan-, iCloud- und Health-Test auf echten Geräten

---

## 28.09.2026 – Mindestversion iOS 17, Apple Health ab iOS 26 (ZIP MediVorrat-Komplett.zip)

**Entscheidung:** Deployment-Target iOS 17 (wie BDM). Nur die Health-Medications-API braucht iOS 26; auf iOS 17–18 läuft alles außer Health.

**Geändert**
- project.yml: deploymentTarget iOS 17.0
- HealthSync: isAvailable = Health vorhanden UND #available(iOS 26); requestAccess wirft unter iOS 26 HealthNeedsIOS26; medications/takenDoses liefern unter iOS 26 leere Listen; alle HealthKit-26-Typen in @available(iOS 26, *)-Hilfsfunktionen (annotatedMedications, takenDoses26)
- ContentView: Startbildschirm ohne Health (iOS < 26): „Medikament anlegen“ + „Packung scannen“, Text zum Einnahmeplan
- SettingsView: Abschnitt Apple Health nur, wenn verfügbar oder noch eingeschaltet; Ausschalten bleibt immer möglich
- Übrige APIs geprüft: alles ≤ iOS 17 (@Observable, ContentUnavailableView, onChange mit zwei Parametern, .rect-Formen, MainActor.assumeIsolated, DataScanner, MessageUI, KVS)

**Merke**
- Neue HealthKit-Aufrufe immer in @available(iOS 26, *) kapseln und über HealthSync.isAvailable gaten
- App-Store-Beschreibung anpassen: „Voraussetzung: iOS 17. Apple Health ab iOS 26.“

**Offene Punkte**
- Test auf einem Gerät/Simulator mit iOS 17 oder 18 (Health-Teile unsichtbar, Scan + Mail + iCloud funktionieren)
- Datenschutzseite deployen, App Store Connect anlegen, appStoreID setzen, Screenshots
- Erster Build; Scan-, iCloud- und Health-Test auf echten Geräten

---

## 28.09.2026 – App-Store-Vorbereitung: Health raus aus iCloud, Datenschutzerklärung, Texte (ZIP MediVorrat-Komplett.zip)

**Geändert**
- Store: cloudSnapshot() entfernt vor dem Upload alles aus Apple Health (healthName, consumedSinceStock, healthConnected) – App-Store-Richtlinie 5.1.3. Upload nur bei Änderung des Cloud-Inhalts (reine Health-Änderungen lösen keinen Upload aus, lastCloudContent). applyRemote behält die lokalen Health-Werte je Medikament; wurde auf dem anderen Gerät neu gezählt (stockDate anders), wird der Health-Verbrauch auf 0 gesetzt und per refresh() neu gelesen. Einschalten des Syncs lädt erzwungen hoch
- SettingsView: iCloud-Fußtext „Daten aus Apple Health werden nicht in iCloud gespeichert“; Info-Abschnitt + Link „Datenschutzerklärung“
- AppInfo: privacyURL https://blaseunddarm.de/medivorrat-datenschutz.html
- NEU Website: medivorrat-datenschutz.html im Layout der BDM-Datenschutzseite (14 Abschnitte: Verantwortlicher, Überblick, Daten, Apple Health nur lesen/nur Gerät, Kamera ohne Bildspeicherung, iCloud ohne Health, Rezeptanfrage, Mitteilungen, Links/Bewertungen, Diagnosedaten, Löschung, kein Medizinprodukt, Rechte, Änderungen); Fußzeile verlinkt BDM-Datenschutz statt EN
- NEU MediVorrat-AppStore-Texte.md: Name, Untertitel, Werbetext, Schlagwörter (98 Zeichen), Beschreibung (+ optionaler persönlicher Absatz), Kategorien Medizin / Gesundheit und Fitness, 4+, keine Datenerfassung, Review-Notiz EN

**Merke**
- Nie Werte aus HealthKit in den iCloud-Payload – neue Health-Felder in cloudSnapshot() mit ausnullen
- Auf zwei Geräten mit unterschiedlichem Health-Schalter kann der angezeigte Bestand leicht abweichen (Gerät ohne Health rechnet nach Plan)

**Offene Punkte**
- Website-Seite deployen (Befehl im Chat), dann URL in App Store Connect eintragen
- App in App Store Connect anlegen, appStoreID in AppInfo.swift setzen
- Screenshots (BDM-Rezept, ohne nachgezeichnete Statusleiste)
- Erster Build; Scan-, iCloud- und Health-Test auf echten Geräten

---

## 28.09.2026 – Formatierte Rezept-Mail (ZIP MediVorrat-Mail.zip)

**Rückmeldung André:** Die E-Mail kam unformatiert an.

**Ursache:** Der Weg über mailto: kann nur Klartext übergeben.

**Geändert**
- NEU Views/MailComposer.swift: MFMailComposeViewController als Sheet, HTML-Mail (isHTML), Empfänger = Praxis-Mail (leer erlaubt)
- Store: prescriptionSubject („Bitte um Folgerezept – Name (geb. …)“), prescriptionHTML (Anrede „Liebes Praxisteam“, Tabelle Medikament fett + Stärke / Packung / Einnahme „N Stück täglich“, E-Rezept-Satz, Gruß mit Name und Geburtsdatum; Inline-CSS, Kopfzeile im Leinenton #f4f1ec, HTML-Escaping); Klartext überarbeitet (• statt –, Einnahme je Zeile, Anrede ohne Grammatik-Holperer)
- PrescriptionView: „Als E-Mail an die Praxis“ öffnet das Mail-Fenster; nach „Senden“ werden die Medikamente automatisch als angefragt markiert und die Ansicht schließt. Ohne eingerichtetes Apple Mail Ersatzweg mailto: mit sauberer Kodierung (&=+?# kodiert, CRLF-Zeilenumbrüche, Betreff aus prescriptionSubject). „Senden über …“ nutzt denselben Betreff

**Offene Punkte**
- Test: Mail an sich selbst schicken, Darstellung in Apple Mail/Gmail/Outlook prüfen
- Erster Build steht aus; Scan-Test, iCloud-Test mit zwei Geräten, On-Device-Test Health
- App Store Connect anlegen, ID eintragen; Datenschutzerklärung (inkl. iCloud)

---

## 28.09.2026 – Scan legt neue Medikamente an, Eingaben mit Fertig/Übernehmen (ZIP MediVorrat-Eingaben.zip)

**Rückmeldung André:** Unbekannte PZN ließ sich nur bestehenden Medikamenten zuordnen; in der Medikamenten-Eingabe fehlte an manchen Stellen ein „OK“.

**Geändert**
- PackScanView: Auswahlmenü hat „Neues Medikament anlegen …“ (fester Tag-UUID). Dann Felder Name, Stärke (optional), Stück pro Tag; Namensvorschläge als antippbare Chips aus der Texterkennung (Zeilen mit Buchstaben, 3–40 Zeichen, ohne Mengenangaben, max. 6). „Anlegen und einbuchen“ bzw. „Nur anlegen, Bestand nicht ändern“; neues Medikament startet mit der Packung als Bestand. Vorauswahl: festes Medikament › bisherige Zuordnung › Medikament ohne bekannte Packung › neu anlegen. Panel scrollt, Höhe je Phase
- Ursache „OK fehlt“: Ziffernblöcke haben keine Return-Taste, und TextField(value:format:) übernimmt erst beim Verlassen des Felds – dadurch blieb „Übernehmen“ nach dem Tippen deaktiviert. Jetzt überall Text-Felder mit eigener Umwandlung (Komma erlaubt)
- MedicationDetailView: gemeinsamer FocusState für Zählen, Name, Stärke, Packungsgröße; Tastaturleiste zeigt beim Zählen „Übernehmen“, sonst „Fertig“; Packungsgröße als Text mit Rückweg von außen (Scan); Name/Stärke mit Return = Fertig
- PackScanView: Tastaturleiste „Fertig“ für alle Felder, Return springt Name → Stärke → Stückzahl
- SettingsView: Return-Taste als „Fertig“ bei allen Textfeldern

**Merke**
- Keine TextField(value:format:) mit Ziffernblock, wenn ein Knopf direkt danach den Wert braucht – immer Text + eigene Umwandlung

**Offene Punkte**
- Erster Build steht aus; Scan-Test mit echten Packungen (auch Namensvorschläge), iCloud-Test mit zwei Geräten, On-Device-Test Health
- App Store Connect anlegen, ID eintragen; Datenschutzerklärung (inkl. iCloud)

---

## 27.09.2026 – iCloud-Sync des Bestands (ZIP MediVorrat-iCloud.zip)

**Entscheidung:** Automatischer Abgleich über NSUbiquitousKeyValueStore (iCloud-Key-Value-Speicher) statt Backup-Datei wie in BDM – kein Container im Developer-Portal nötig, Daten klein (< 1 MB). Opt-in per Schalter, Schalter selbst pro Gerät (UserDefaults mv_icloud_sync).

**Geändert**
- project.yml: Entitlement com.apple.developer.ubiquity-kvstore-identifier = $(TeamIdentifierPrefix)$(CFBundleIdentifier)
- NEU CloudSync.swift: ein Schlüssel mv_snapshot_v1 mit dem kompletten Stand als JSON, Beobachter auf didChangeExternallyNotification, push/remoteData
- Store: Snapshot + modifiedAt (decodeIfPresent); save() vergleicht den Inhalt (JSON mit sortedKeys, ohne Zeitstempel) mit dem letzten Stand und schreibt/lädt nur bei echter Änderung hoch (modifiedAt = jetzt). applyRemote übernimmt nur neuere Stände (letzte Änderung gewinnt), behält settings.healthConnected lokal. setCloudSync: erst neueren Cloud-Stand holen, dann eigenen hochladen. Abgleich beim Start, bei App-Aktivierung (refresh) und bei Fremdänderung
- SettingsView: Abschnitt „iCloud“ (Schalter, Hinweis ohne iCloud-Konto, „Zuletzt abgeglichen“) vor Info; Datenschutz-Fußzeile angepasst

**Merke**
- Falls Xcode beim Signieren meckert: Signing & Capabilities → iCloud → „Key-value storage“ anhaken
- Konflikt bei gleichzeitigen Offline-Änderungen auf zwei Geräten: der später gespeicherte Stand gewinnt komplett

**Offene Punkte**
- Test mit zwei Geräten (iPhone + iPad) inkl. Einschalten auf dem zweiten Gerät
- App Store Connect: MediVorrat anlegen, ID eintragen; Datenschutzerklärung (Webseite) muss iCloud erwähnen
- Erster Build steht aus; Scan-Test mit echten Packungen, On-Device-Test Health, Widget

---

## 27.09.2026 – Info-Abschnitt und Bewertung (ZIP MediVorrat-Info.zip)

**Geändert**
- NEU AppInfo.swift: Version (Marketing + Build), Links ploetzlich-querschnitt.de, blaseunddarm.de, BDM im App Store (id6792282103); appStoreID für MediVorrat = nil, solange die App nicht in App Store Connect angelegt ist → „App bewerten“ (Direktlink ?action=write-review, wie BDM) und „App empfehlen“ (ShareLink) sind bis dahin ausgeblendet
- NEU ReviewManager.swift nach BDM-Muster: ReviewGate mit Schwellen 3/12/30 Glücksmomenten, frühestens alle 60 Tage, max. 3 pro Jahr, Keys mv_review_*; ReviewRequester-Modifier an der ContentView, Anfrage 2 s verzögert
- Store: happyMoments (UserDefaults mv_happy_moments), +1 bei Packung eingebucht (Scan und „Packung erhalten“) und Rezept als angefragt markiert
- SettingsView: Abschnitt „Info“ (Version, App bewerten, App empfehlen, ploetzlich-querschnitt.de „Mein Blog“) und „Auch von mir“ (Blase & Darm Manager im App Store, blaseunddarm.de), Fußzeile „Alle Daten bleiben auf diesem Gerät … © André M. Bajorat“, Zeilen im BDM-Stil mit Pfeil nach rechts oben

**Merke**
- Nach dem Anlegen in App Store Connect: appStoreID in AppInfo.swift setzen (sed-Befehl im Chat)

**Offene Punkte**
- App Store Connect: MediVorrat anlegen, ID eintragen; Datenschutzerklärung (Webseite) fehlt noch
- Erster Build steht aus – Fehlermeldungen aus Xcode zurückgeben
- Scan-Test mit echten Packungen, On-Device-Test Health, Widget, iCloud-Sicherung

---

## 27.09.2026 – Scan auch im Medikament (ZIP MediVorrat-ScanMedikament.zip)

**Geändert**
- MedicationDetailView: Knopf „Packung scannen“ im Abschnitt Bestand öffnet den Scanner fest für dieses Medikament; NEU Abschnitt „Bekannte Packungen“ (PZN/Code + Stückzahl, per Wischen entfernen), nur wenn Zuordnungen existieren
- PackScanView: optionaler Parameter medicationID (explizites init). Mit festem Medikament: neue Packungen sind vorausgewählt, Titel „Packung: Name“; gehört eine gescannte Packung bisher zu einem anderen Medikament, gibt es „Stattdessen <Name> zuordnen“. Stückzahl-Vorbelegung nur aus dem Katalog, wenn die Zuordnung zum gewählten Medikament passt
- NEU überall in der Zuordnung: „Nur zuordnen, Bestand nicht ändern“ – z. B. für die angebrochene Packung, die schon im gezählten Bestand steckt
- Store: assignPack (Katalog ohne Buchung), removePack(key:), packs(for:) → [KnownPack]; KnownPack in PackCode.swift

**Offene Punkte**
- GitHub-Repo anlegen/pushen (Befehle im Chat; privat vs. öffentlich offen)
- Erster Build steht aus – Fehlermeldungen aus Xcode zurückgeben
- Scan-Test mit echten Packungen, On-Device-Test Health, Widget, iCloud-Sicherung

---

## 27.09.2026 – Packung scannen und einbuchen (ZIP MediVorrat-Scan.zip)

**Entscheidung:** Scan dient dem Einbuchen neuer Packungen, nicht dem Zählen. Verfallsdatum bewusst NICHT ausgewertet.

**Geändert**
- project.yml: NSCameraUsageDescription
- NEU PackCode.swift: Parser für securPharm-DataMatrix im IFA-Format (9N = PPN „11“+PZN8+Prüfziffern, S = Seriennummer) und im GS1-Format (AI 01 NTIN „04150“+PZN8, 21 Seriennr., 710 PZN, 10/17 übersprungen), PZN-Strichcode Code 39 („-12345678“, PZN7 → „0“+PZN7), sonst Rohcode als Schlüssel. Stückzahl-Vorschlag per Regex aus erkanntem Text („100 Filmtabletten“, „98 St.“). PackEntry (medicationID, packSize)
- Store: packCatalog [Schlüssel → PackEntry] (eine Sorte kann mehrere PZN haben, wichtig wegen Rabattverträgen/Generika-Wechsel), bookedPacks (PZN|Seriennr., max. 500) gegen Doppelbuchung; Snapshot mit tolerantem Decoding (decodeIfPresent); bookPack = aktuell (abgerundet) + Packung, Zählzeit jetzt, „angefragt“ zurück, packSize am Medikament setzen falls leer; delete räumt Katalog-Einträge mit ab
- NEU Views/PackScanView.swift: VisionKit DataScannerViewController (Brücke nach BDM-ScannerView-Muster, DataMatrix/Code39/Code128/EAN13 + Text), Phasen scannen → bekannt (Einbuchen +N, Anders zuordnen) / schon eingebucht (Weiter scannen, Trotzdem einbuchen) / neu (Medikament wählen, Stückzahl mit Texterkennungs-Vorschlag, Zuordnen und einbuchen). DataMatrix mit Seriennr. wird gegenüber PZN-Strichcode bevorzugt. Nach dem Einbuchen Toast und weiterscannen (mehrere Packungen einer Lieferung nacheinander)
- ContentView: Knopf „Packung scannen“ (barcode.viewfinder) oben rechts, sobald Medikamente angelegt sind

**Merke**
- PZN-Stammdaten (Name, Stückzahl) sind lizenzpflichtig (IFA) → App lernt Zuordnung beim ersten Scan
- Reine PZN-Strichcodes haben keine Seriennummer: gleiche Sorte erneut einbuchen geht erst, wenn der Code einmal aus dem Bild war

**Offene Punkte**
- Erster Build steht aus – Fehlermeldungen aus Xcode zurückgeben
- Scan-Test mit echten Packungen (IFA- und GS1-DataMatrix, PZN-Strichcode), Stückzahl-Vorschlag prüfen
- On-Device-Test Health, Widget, iCloud-Sicherung

---

## 27.09.2026 – Apple Health als Schalter statt zwei Fassungen (ZIP MediVorrat-HealthSchalter.zip)

**Entscheidung:** Eine App, Apple Health per Schalter in den Einstellungen an oder aus. Die Zwei-Target-Lösung (MediVorratLite) ist zurückgebaut.

**Geändert**
- project.yml wieder mit einem Target (iOS 26, HealthKit-Entitlement); Lite/ und Features.swift gelöscht
- Models: Health-Verbrauch zählt nur, wenn settings.healthConnected an ist UND das Medikament verknüpft ist; sonst Einnahmeplan
- Store.setHealthEnabled(_:) schreibt vor dem Umschalten jeden Bestand mit der bisherigen Rechenart fest (Bestand = aktuell, Zählzeit = jetzt), damit nichts springt; Verknüpfungen bleiben beim Ausschalten erhalten
- SettingsView: Toggle „Apple Health nutzen“ (Einschalten fragt die Freigabe an), Abgleich und „Freigegebene Medikamente ändern“ nur bei an, Fußtext je Zustand
- ContentView: Leer-Zustand mit beiden Wegen („Mit Apple Health starten“ / „Ohne Health, manuell anlegen“); Menü „Aus Apple Health“ nur bei an
- MedicationRow: Herz nur bei aktivem Health; MedicationDetailView: Health-Abschnitt nur bei an
- HealthImportView schaltet über store.setHealthEnabled(true) ein

**Offene Punkte**
- Erster Build steht aus – Fehlermeldungen aus Xcode zurückgeben
- On-Device-Test: Import, Abgleich, Aus- und Einschalten mit Bestandsübernahme
- Widget, iCloud-Sicherung

---

## 27.09.2026 – Zwei Fassungen: mit und ohne Apple Health (ZIP MediVorrat-Varianten.zip)

**Geändert**
- project.yml: zwei Targets aus demselben Code. MediVorrat = mit Health (iOS 26, HealthKit-Entitlement, Flag HEALTH_SYNC, de.bajorat.medivorrat). NEU MediVorratLite = ohne Health (iOS 17, kein HealthKit, de.bajorat.medivorrat.lite, Anzeigename „MediVorrat Lite“). Deployment-Target jetzt pro Target statt global
- NEU Features.swift: Features.healthSync aus dem Compiler-Flag
- NEU Lite/HealthSyncStub.swift: gleiche Schnittstelle wie HealthSync.swift ohne HealthKit (isAvailable = false); Lite-Target schließt HealthSync.swift, Info.plist und Entitlements des Haupt-Targets aus. Lite/Info.plist wird von XcodeGen befüllt
- Store.syncHealth läuft nur mit Flag
- ContentView: in Lite nur „Hinzufügen“ statt Menü, eigener Leer-Zustand (Einnahmeplan + Bestand)
- SettingsView und MedicationDetailView: Health-Abschnitte nur in der Health-Fassung

**Merke**
- Neue Health-Aufrufe immer auch im Stub nachziehen, sonst baut Lite nicht
- Nach Änderungen an project.yml: xcodegen generate

**Offene Punkte**
- Erster Build beider Schemata steht aus – Fehlermeldungen aus Xcode zurückgeben
- On-Device-Test Health-Import und Abgleich
- Eigenes Icon oder Kennzeichnung für Lite (derzeit gleiches Icon)
- Widget, iCloud-Sicherung

---

## 27.09.2026 – Design im Stil von Blase & Darm (ZIP MediVorrat-Design.zip)

**Geändert**
- NEU AppColors.swift: Palette 1:1 aus BDM (accent Orange, pageBg Leinen/Fast-Schwarz, cardBg, subtleText, pillBg, pillBorder, pillActiveText) plus Statusfarben passend dazu: statusRed (jetzt fällig), accent (bald), statusOk Petrol (reicht), statusOrdered Flieder wie BDM-Darm (angefragt). Dazu LargeButtonStyle (wie BDM, mit Deaktiviert-Zustand), .card() und .pageForm()
- ContentView: ScrollView auf pageBg statt List, Kopf „MediVorrat“ in Serif 22 bold wie BDM, Übersichtskarte im Stil der BDM-„Heute“-Karte (jetzt fällig / bald / angefragt / reicht), orangefarbener Hinweisbalken bei fälligen Rezepten, Medikamente als Karten, „Rezept anfragen“ als großer orangefarbener Knopf
- MedicationRow: Karte mit 0,5-pt-Rahmen, Bestandszahl rounded bold in Statusfarbe, Status-Chips im BDM-Chipstil (Deckkraft 0,12, Radius 6)
- Detail, Rezept, Einstellungen, Import: Formularhintergrund pageBg, Akzent Orange; „Als angefragt markieren“ als großer Knopf
- AccentColor-Asset auf BDM-Orange, App-Icon neu im BDM-Stil (dunkler Verlauf, Kapsel orange/creme, orangefarbenes Häkchen-Badge, Creme-Kreis mit Vorratsbalken)

**Offene Punkte**
- Erster Build steht weiter aus – Fehlermeldungen aus Xcode zurückgeben
- On-Device-Test Health-Import und Abgleich
- Widget, iCloud-Sicherung

---

## 27.09.2026 – Version 1.0, Grundgerüst (ZIP MediVorrat.zip)

**Neu angelegt**
- project.yml mit HealthKit-Entitlement, Info.plist-Text für Health-Lesezugriff, App-Icon (Kapsel + Vorratsbalken), Akzentfarbe Apotheken-Grün
- Models.swift: Medication (Bestand, Zählzeitpunkt, Stück/Tag, Packungsgröße, Health-Verknüpfung, angefragt-Datum, pausiert), AppSettings, StockStatus, Calc.forecast
- Store.swift: JSON in Application Support (completeFileProtection), Sortierung nach Dringlichkeit, Health-Abgleich, Rezepttext
- HealthSync.swift: Medications API (iOS 26) – requestPerObjectReadAuthorization, HKUserAnnotatedMedicationQueryDescriptor, Dose-Events per HKSampleQueryDescriptor, Zuordnung über medicationConceptIdentifier, nur logStatus .taken
- Notifications.swift: eine Erinnerung pro Medikament am Anfordern-Tag (Uhrzeit einstellbar), bei Überfälligkeit täglich neu
- Views: Vorratsliste mit Reichweitenbalken und Anfordern-Strich, Detail (Zählen, Packung erhalten, angefragt, Health-Verknüpfung), Rezeptanfrage (Vorauswahl fällig/bald, Teilen, Mail an Praxis, als angefragt markieren), Einstellungen, Import aus Apple Health (Ø Stück/Tag aus 14 Tagen)

**Rechenlogik**
- Mit Health-Verknüpfung: abgezogen wird die Summe der als „genommen“ protokollierten Dosen seit der letzten Zählung
- Ohne Verknüpfung: Stück/Tag × angebrochene Kalendertage seit der Zählung
- Prognose immer über Stück/Tag; Anfordern-Tag = Reicht-bis minus Vorlauf (Standard 14 Tage)
- Beim Wechsel der Verknüpfung wird der aktuelle Stand als neue Zählung festgeschrieben

**Wichtige Lehre**
- Medikamente NIE über requestAuthorization(toShare:read:) anfragen – das wirft eine ObjC-Exception und die App stürzt ab. Nur Per-Object-Autorisierung; Dose-Events sind damit automatisch freigegeben

**Offene Punkte**
- Erster Build: Code ist ungetestet kompiliert (kein iOS-SDK in der Sandbox) – Fehlermeldungen aus Xcode zurückgeben
- On-Device-Test des Health-Imports und des Abgleichs
- Widget „nächstes fälliges Rezept“ (braucht App Group)
- iCloud-Sicherung des Bestands
- Einheit bei Health-Dosen prüfen (z. B. halbe Tabletten, Tropfen)
