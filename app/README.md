# Messprotokoll-App

Eine einzelne HTML-Datei (`index.html`), mit der während eines Versuchs alle Protokolldaten eingetragen werden. Sie braucht keine Installation und keine Internetverbindung.

## Was die App macht

- **Kopfdaten** pro Durchlauf: Bedingung (Kalt/Angenehm/Warm), Durchlauf-Nr., Datum, Raumtemperatur Start/Ende, Luftfeuchte, Training, Kleidung, Ort, Name der Sensor-CSV
- **Ablauf mit Uhrzeiten**: Ruhemessung → Sport → **Zeitpunkt 0 bestätigen** → 20 Min. Erholung
- **Erinnerung nach Zeitpunkt 0**: bei 0, 5, 10, 15 und 20 Min. öffnet sich die Bewertung (−3 bis +3) mit immer derselben Frage. Ton und Vibration wiederholen sich alle 5 s, bis bewertet wurde. Verspätungen werden in Sekunden mitgespeichert.
- **Warnungen**: Raumtemperatur außerhalb des Zielbereichs oder außerhalb der Sicherheitsgrenze 8–30 °C
- **Abbrechen** (z. B. bei Schwindel) und **Ausreißer markieren** mit Begründung. Nichts wird stillschweigend gelöscht.
- **Fortschritt**: wie viele Durchläufe pro Bedingung fertig sind (Ziel: 3)
- **Export**:
  - `protokoll_durchlaeufe_<datum>.csv`: eine Zeile pro Durchlauf
  - `protokoll_gefuehlswerte_<datum>.csv`: eine Zeile pro Bewertung (gut für Korrelationen)
  - `protokoll_sicherung_<datum>.json`: komplette Sicherung, lässt sich wieder laden

CSV-Format: Komma als Trennzeichen, Punkt als Dezimalzeichen, Zeiten als `YYYY-MM-DD hh:mm:ss` (Uhrzeit des Handys).

## Benutzung

1. Auf dem Handy den Link zur App öffnen: https://claude.ai/artifact/8gHjqs699M9vtBFhQ2VKJZ
   (nur mit dem eigenen claude.ai-Konto sichtbar). Alternativ `index.html` direkt im Browser öffnen.
2. Vor dem ersten Versuch einmal **„🔔 Ton testen“** drücken und den Ton laut stellen.
3. Während der 20-Min.-Erholung **App geöffnet und Bildschirm an lassen**. Die App versucht, den Bildschirm automatisch wach zu halten. Wenn das Handy gesperrt ist, können Browser die Erinnerung verzögern.
4. Nach jedem Versuch die beiden CSV-Dateien exportieren und in `protokolle/` ins Repository legen.

## Wo die Daten gespeichert werden

- **Über den claude.ai-Link:** in der Datenbank des Artifacts (ein Eintrag pro Durchlauf unter `runs/`). Die Daten sind auf allen Geräten verfügbar, auf denen man mit demselben Konto angemeldet ist, und Claude kann sie für die Auswertung direkt lesen. Zusätzlich gibt es eine Kopie im Browser.
- **Lokal geöffnete `index.html`:** nur im Browser auf diesem Gerät (localStorage). Wenn Browserdaten gelöscht werden, sind sie weg.

In beiden Fällen nach jedem Versuch die CSV-Dateien exportieren und ins Repository legen.

## Wichtig

- Die Uhr des Handys und die Uhr des CALERA-Sensors können voneinander abweichen. Vor dem Versuch beide vergleichen und die Abweichung unter „Notizen“ eintragen, damit Zeitpunkt 0 später in den Sensordaten richtig gefunden wird.
- Vertippt? Nicht nachträglich ändern, sondern unter „Notizen“ vermerken.
