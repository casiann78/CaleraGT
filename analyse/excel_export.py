"""
Excel-Datei mit echten (bearbeitbaren) Diagrammen der Gefühlswerte.

Liest den neuesten Export „protokoll_gefuehlswerte_<datum>.csv“ aus protokolle/
und schreibt data/processed/gefuehlswerte_diagramme.xlsx mit zwei Blättern:

  Mittelwerte   Tabelle (Mittelwert, SD, n pro Bedingung) + Liniendiagramm
  Durchläufe    Tabelle (eine Spalte pro Durchlauf) + ein Liniendiagramm pro Bedingung

Die Diagramme sind keine Bilder: In Excel oder Numbers lassen sie sich anklicken
und ändern (Farben, Titel, Achsen), und sie passen sich an, wenn Werte in der
Tabelle geändert werden.

Berücksichtigt werden wie in gefuehlswerte.py nur abgeschlossene Durchläufe
ohne Ausreißer-Markierung; ausgeschlossene werden in der Konsole aufgelistet.

Aufruf (im Hauptordner des Repositorys):
    python analyse/excel_export.py
    python analyse/excel_export.py protokolle/protokoll_gefuehlswerte_2026-11-20.csv
"""

import sys
from pathlib import Path

from openpyxl import Workbook
from openpyxl.chart import LineChart, Reference
from openpyxl.styles import Font

from gefuehlswerte import (CONDITIONS, PROCESSED_DIR, ROOT, find_newest_export,
                           load_ratings, split_valid, summarize)

# Ruhe steht als letzte Zeile, damit die Diagramme nur die Zeilen 0–20 Min. verwenden
SLOT_ORDER = ["0", "5", "10", "15", "20", "rest"]
Y_TITLE = "Gefühlswert (−3 sehr kalt … +3 sehr heiß)"
X_TITLE = "Zeit nach dem Sport [min]"
REST_NOTE = "Die Diagramme zeigen 0–20 Min. nach dem Sport. Der Ruhewert steht nur in der Tabelle."


def slot_label(minute: str) -> str:
    return "Ruhe" if minute == "rest" else f"{minute} Min."


def make_chart(title: str) -> LineChart:
    chart = LineChart()
    chart.title = title
    chart.height = 9
    chart.width = 17
    chart.y_axis.title = Y_TITLE
    chart.x_axis.title = X_TITLE
    chart.y_axis.scaling.min = -3
    chart.y_axis.scaling.max = 3
    chart.y_axis.majorUnit = 1
    chart.x_axis.tickLblPos = "low"    # Beschriftung der x-Achse unten statt auf der Nulllinie
    chart.x_axis.delete = False        # Achsen anzeigen (sonst blendet openpyxl sie aus)
    chart.y_axis.delete = False
    chart.legend.position = "b"
    return chart


def style_series(series, color: str) -> None:
    """Linie und Punkte in der Farbe der Bedingung (ohne '#')."""
    rgb = color.lstrip("#").upper()
    series.graphicalProperties.line.solidFill = rgb
    series.graphicalProperties.line.width = 28000
    series.marker.symbol = "circle"
    series.marker.size = 7
    series.marker.graphicalProperties.solidFill = rgb
    series.marker.graphicalProperties.line.solidFill = rgb
    series.smooth = False


def set_widths(ws) -> None:
    """Spalten so breit, dass die Überschriften lesbar sind."""
    for cell in ws[1]:
        ws.column_dimensions[cell.column_letter].width = max(12, len(str(cell.value)) + 3)


def write_means_sheet(ws, summary, valid) -> None:
    labels = [cfg["label"] for cfg in CONDITIONS.values()]
    ws.append(["Zeitpunkt"] + labels + [f"{l} SD" for l in labels] + [f"{l} n" for l in labels])
    by_condition = {key: summary[summary["condition"] == key].set_index("minute") for key in CONDITIONS}
    for minute in SLOT_ORDER:
        row = [slot_label(minute)]
        for column in ("mean", "std", "n"):
            for key in CONDITIONS:
                value = by_condition[key][column].get(minute)
                if column == "n":
                    row.append(0 if value is None else int(value))
                else:
                    row.append(None if value is None or value != value else float(value))
        ws.append(row)
    for cell in ws[1]:
        cell.font = Font(bold=True)
    set_widths(ws)

    n_text = ", ".join(
        f"{cfg['label']} n = {valid[valid['condition'] == key]['run_label'].nunique()}"
        for key, cfg in CONDITIONS.items()
    )
    ws["A9"] = f"Anzahl gültiger Durchläufe: {n_text}"
    ws["A10"] = REST_NOTE

    # Zeile 1 = Überschriften, Zeilen 2–6 = 0 bis 20 Min., Zeile 7 = Ruhe (nicht im Diagramm)
    chart = make_chart("Gefühltes Warm/Kalt nach dem Sport (Mittelwerte)")
    chart.add_data(Reference(ws, min_col=2, max_col=4, min_row=1, max_row=6), titles_from_data=True)
    chart.set_categories(Reference(ws, min_col=1, min_row=2, max_row=6))
    for series, cfg in zip(chart.series, CONDITIONS.values()):
        style_series(series, cfg["color"])
    ws.add_chart(chart, "A12")


def write_runs_sheet(ws, valid) -> None:
    rated = valid.dropna(subset=["feel"])
    columns = []  # (Bedingung, Durchlauf-Bezeichnung)
    for key, cfg in CONDITIONS.items():
        runs = rated[rated["condition"] == key]
        for run_no in sorted(runs["run_no"].unique()):
            columns.append((key, run_no, f"{cfg['label']} Nr. {run_no}"))

    ws.append(["Zeitpunkt"] + [label for _, _, label in columns])
    for minute in SLOT_ORDER:
        row = [slot_label(minute)]
        for key, run_no, _ in columns:
            match = rated[(rated["condition"] == key) & (rated["run_no"] == run_no) & (rated["minute"] == minute)]
            row.append(None if match.empty else float(match["feel"].iloc[0]))
        ws.append(row)
    for cell in ws[1]:
        cell.font = Font(bold=True)
    set_widths(ws)
    ws["A9"] = REST_NOTE

    anchor_row = 11
    for key, cfg in CONDITIONS.items():
        cols = [i + 2 for i, (k, _, _) in enumerate(columns) if k == key]
        if not cols:
            continue
        chart = make_chart(f"{cfg['label']}: einzelne Durchläufe (n = {len(cols)})")
        chart.add_data(Reference(ws, min_col=cols[0], max_col=cols[-1], min_row=1, max_row=6),
                       titles_from_data=True)
        chart.set_categories(Reference(ws, min_col=1, min_row=2, max_row=6))
        for series in chart.series:
            style_series(series, cfg["color"])
        ws.add_chart(chart, f"A{anchor_row}")
        anchor_row += 20


def main() -> None:
    path = Path(sys.argv[1]) if len(sys.argv) > 1 else find_newest_export()
    print(f"Lese {path}")
    valid = split_valid(load_ratings(path))
    if valid.dropna(subset=["feel"]).empty:
        sys.exit("Keine gültigen Bewertungen vorhanden.")

    wb = Workbook()
    ws_means = wb.active
    ws_means.title = "Mittelwerte"
    write_means_sheet(ws_means, summarize(valid), valid)
    write_runs_sheet(wb.create_sheet("Durchläufe"), valid)

    PROCESSED_DIR.mkdir(parents=True, exist_ok=True)
    out = PROCESSED_DIR / "gefuehlswerte_diagramme.xlsx"
    wb.save(out)
    print(f"Excel-Datei mit Diagrammen gespeichert: {out.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
