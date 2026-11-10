# Messprotokoll als iPhone-App

Dieselbe Messprotokoll-App wie `app/index.html`, aber als echte iPhone-App. Der wichtigste Unterschied: Die Erinnerungen bei 5, 10, 15 und 20 Min. kommen als **Mitteilung, auch wenn das Handy gesperrt ist**. Wird nicht bewertet, kommt nach 1 und 2 Minuten noch einmal eine Erinnerung.

Die App braucht keinen App Store. Sie wird mit Xcode direkt vom Mac auf das eigene iPhone installiert.

## Was du brauchst

- Mac mit **Xcode** (kostenlos im Mac App Store, Version 15 oder neuer)
- iPhone mit iOS 16 oder neuer und USB-Kabel
- eine Apple-ID (die normale reicht, kein bezahltes Entwicklerkonto nötig)

## Installieren (einmalig)

1. Repository auf den Mac holen (oder als ZIP von GitHub laden und entpacken).
2. Im Finder den Ordner `ios/Messprotokoll.swiftpm` doppelklicken. Xcode öffnet das Projekt.
3. Xcode › Einstellungen › Accounts: mit der Apple-ID anmelden.
4. Links im Projekt auf „Messprotokoll“ klicken, dann den Reiter **Signing & Capabilities** öffnen und bei **Team** die eigene Apple-ID („Personal Team“) wählen.
   - Meldet Xcode, dass die Bundle-ID vergeben ist: in `Package.swift` bei `bundleIdentifier` z. B. `de.deinname.messprotokoll` eintragen.
5. iPhone per Kabel anschließen, entsperren und „Diesem Computer vertrauen“ bestätigen.
6. Auf dem iPhone **Entwicklermodus** einschalten: Einstellungen › Datenschutz & Sicherheit › Entwicklermodus (danach Neustart).
7. In Xcode oben das iPhone als Ziel auswählen und auf ▶ (Run) klicken.
8. Beim ersten Start auf dem iPhone: Einstellungen › Allgemein › VPN und Geräteverwaltung › Entwickler-App › „Vertrauen“.
9. App öffnen und **Mitteilungen erlauben**.

Mit einer kostenlosen Apple-ID läuft die App **7 Tage**. Danach einfach Schritt 7 wiederholen (iPhone anschließen, ▶ klicken). Die Daten bleiben dabei erhalten. Mit einem bezahlten Entwicklerkonto (99 $/Jahr) hält sie 1 Jahr.

## Aufbau der App

- **Übersicht:** Fortschritt pro Bedingung (Ziel 3 Durchläufe), Knöpfe für einen neuen Durchlauf, Liste aller Durchläufe mit farbigen Gefühlswerten.
- **Durchlauf:** Reiter „Ablauf“ (Schrittanzeige, Uhr, Erholungsring, Gefühlsverlauf als Diagramm), „Kopfdaten“ und „Notizen“. Unten steht immer der Knopf für den nächsten Schritt.
- **Einstellungen** (Zahnrad): Status der Mitteilungen, Test-Erinnerung, Export und Import, Sicherheitsregeln.

## Vor jedem Versuch

- In den Einstellungen „Test-Erinnerung in 10 Sekunden“ drücken und das iPhone sperren. Kommt die Mitteilung mit Ton, ist alles bereit.

- **Stummschalter aus** und **Fokus / Nicht stören aus**, sonst ist die Erinnerung lautlos (sie vibriert dann nur).
- Lautstärke hoch.
- Uhrzeit von iPhone und CALERA-Sensor vergleichen und die Abweichung unter „Notizen“ eintragen.

## Daten

- Gespeichert wird in der App auf dem iPhone (`protokoll.json`).
- Export: Zahnrad oben rechts › „CSV-Dateien und Sicherung teilen“, dann z. B. per AirDrop an den Mac und in `protokolle/` ablegen.
- Die JSON-Sicherung hat dasselbe Format wie in der Web-App. Daten aus der Web-App lassen sich mit „Sicherung (JSON) laden“ übernehmen.

## Hinweis

Die App wurde ohne Mac geschrieben und konnte deshalb noch nicht kompiliert werden. Zeigt Xcode beim ersten Öffnen einen Fehler, die Meldung an Claude weitergeben.
