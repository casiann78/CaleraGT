# CLAUDE.md – Jugend forscht 2027: Wärmefluss und Wärmeempfinden

Diese Datei erklärt Claude Code, worum es in diesem Repository geht und wie hier gearbeitet wird.

## Projekt

Jugend-forscht-Projekt (Bremen, 2027). Wir untersuchen mit dem greenTEG **CALERA Research** Sensor:

> Stimmt das gefühlte Warm/Kalt nach dem Sport mit dem gemessenen Wärmefluss überein?

Gemessen wird nach dem Sport in drei Umgebungen:

| Bedingung | Ziel-Temperatur |
|---|---|
| Kalt | ca. 10–12 °C |
| Angenehm | ca. 21–22 °C |
| Warm | ca. 25–28 °C (selbst erzeugt, tatsächlich erreichten Wert notieren) |

Pro Bedingung mindestens 3 Durchläufe, also mindestens 9 Messungen.

## Ablauf eines Versuchs

1. Ruhemessung vor dem Sport (10–15 Min.)
2. Sport (z. B. 30 Min., immer gleiche Intensität)
3. Sofort danach in den Messbereich, das ist **Zeitpunkt 0**
4. 20 Min. Erholung messen
5. Gefühlswert auf Skala −3 (sehr kalt) bis +3 (sehr heiß) bei: Ruhe, 0, 5, 10, 15, 20 Min.
   - Nur alle 5 Min. bewerten (nicht jede Minute), damit der Versuch nicht stört. Timer stellen.
   - Immer dieselbe Frage: „Wie warm oder kalt fühlt sich mein ganzer Körper gerade an?"
   - Erst bewerten, dann Kurve ansehen. Während des Versuchs nicht in die App schauen.
   - Pro Bedingung eine eigene Tabelle (Kalt, Angenehm, Warm) mit Kopfdaten: Datum, Durchlauf-Nr., Raumtemperatur Start/Ende, Luftfeuchte, Training, Kleidung.

## Warme Umgebung im Herbst/Winter

Warm wird selbst erzeugt: kleines Bad oder Zimmer mit Heizkörper/Heizlüfter (ca. 26–28 °C) oder geparktes Auto im Freien mit Heizung. Immer die **tatsächlich gemessene** Temperatur notieren. Wichtig ist, dass die drei Stufen deutlich verschieden sind (z. B. 11 °C, 21 °C, 26 °C). Keine Sauna, heiße Dusche oder Dampf.

## Repository-Struktur

```
app/            Messprotokoll-App (index.html) zum Eintragen während der Versuche
ios/            dieselbe App als iPhone-App (Messprotokoll.swiftpm, mit Xcode öffnen), Erinnerung auch bei gesperrtem Handy
data/
  raw/          Original-CSV-Dateien vom Sensor (NIE verändern)
  processed/    bereinigte und umgerechnete Daten
protokolle/     ausgefüllte Messprotokolle (CSV-Export der App: Gefühlswerte, Umgebung)
analyse/        Skripte und Notebooks
abbildungen/    erzeugte Diagramme
doku/           Projektbericht, Poster, Notizen
```

## Datenformat und Umrechnung

Die Sensor-CSV enthält Rohwerte. Diese müssen umgerechnet werden:

- **Wärmefluss [W/m²]** = `hf_a0 * 1.953125 / (S0 / 1000)`
  (`S0` = Sensitivität aus dem Header der Datei, in nV/(W/m²))
- **Hauttemperatur [°C]** = `(temp_a0 - Tni_off) / 1000`
  (`Tni_off` steht im Header; bei älteren Dateien siehe Herstellerdoku)
- Abtastrate 1 Hz, Kerntemperatur wird minütlich berechnet.
- Der Zeitstempel hat das Format `DD:MM:YYYY hh:mm:ss`.

Der Wärmefluss ist beim Research-Gerät nur nach Vereinbarung mit greenTEG freigeschaltet.

## Regeln für Claude

- **Rohdaten niemals überschreiben.** Alle Ergebnisse in `data/processed/` oder `abbildungen/` ablegen.
- Jede Umrechnung in einem Skript festhalten, damit sie nachvollziehbar und wiederholbar ist.
- Sprache: Code-Kommentare und Doku auf Deutsch, Variablennamen auf Englisch.
- Python bevorzugen (pandas, numpy, matplotlib, scipy). Keine neuen Pakete ohne Rückfrage.
- Diagramme: Achsen mit Einheiten beschriften, pro Diagramm eine Aussage, gleiche Farben für gleiche Bedingungen (Kalt = blau, Angenehm = grün, Warm = rot).
- Statistik einfach halten: Mittelwerte, Standardabweichung, Korrelation (Pearson/Spearman). Immer die Anzahl der Durchläufe (n) angeben.
- Nichts beschönigen. Ausreißer und fehlerhafte Messungen markieren und begründen, nicht stillschweigend löschen.
- Bei Unklarheiten zum Versuchsaufbau nachfragen, statt Annahmen zu treffen.

## Typische Aufgaben

- CSV einlesen, Wärmefluss und Hauttemperatur berechnen
- Zeitpunkt 0 markieren und Erholungsphase (0–20 Min.) ausschneiden
- Kurven der drei Bedingungen vergleichen
- Gefühlswerte mit Wärmefluss korrelieren (auch mit der Änderung des Wärmeflusses)
- Diagramme für Bericht und Poster erzeugen

## Befehle

```bash
# app/index.html im Browser öffnen: Protokoll während des Versuchs (siehe app/README.md)
python analyse/auswerten.py data/raw/<datei>.csv   # Rohdaten umrechnen
python analyse/vergleich.py                         # drei Bedingungen vergleichen
```

(Skripte werden im Projektverlauf angelegt. Diese Zeilen bei Änderungen anpassen.)

## Sicherheit

Versuche nur mit Absprache der Eltern oder des Betreuers. Raumtemperaturen nicht unter 8 °C und nicht über 30 °C. Keine Sauna oder kaltes Wasser direkt nach dem Sport. Bei Schwindel oder Frösteln sofort abbrechen.
