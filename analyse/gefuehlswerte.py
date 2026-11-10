"""
Auswertung der Gefühlswerte aus der Messprotokoll-App.

Liest den neuesten Export „protokoll_gefuehlswerte_<datum>.csv“ aus protokolle/
(jeder Export enthält alle Durchläufe) und erzeugt:

  abbildungen/gefuehlsverlauf_mittelwert.png   Mittelwert ± Standardabweichung pro Bedingung
  abbildungen/gefuehlsverlauf_einzeln.png      jeder Durchlauf einzeln, eine Spalte pro Bedingung
  data/processed/gefuehl_zusammenfassung.csv   Mittelwert, Standardabweichung und n pro Zeitpunkt
  data/processed/diagramm_mittelwerte.csv      dieselben Werte als Tabelle für Numbers/Excel

Abgebrochene, unvollständige und als Ausreißer markierte Durchläufe werden NICHT
gelöscht, sondern hier ausgeschlossen und in der Konsole mit Grund aufgelistet.

Aufruf (im Hauptordner des Repositorys):
    python analyse/gefuehlswerte.py
    python analyse/gefuehlswerte.py protokolle/protokoll_gefuehlswerte_2026-11-20.csv
"""

import sys
from pathlib import Path

import matplotlib

matplotlib.use("Agg")  # Diagramme nur als Datei speichern, kein Fenster
import matplotlib.pyplot as plt
import pandas as pd

ROOT = Path(__file__).resolve().parent.parent
PROTOCOL_DIR = ROOT / "protokolle"
FIGURE_DIR = ROOT / "abbildungen"
PROCESSED_DIR = ROOT / "data" / "processed"

# Gleiche Farben für gleiche Bedingungen in allen Diagrammen
CONDITIONS = {
    "kalt": {"label": "Kalt", "color": "#1f6fd1"},
    "angenehm": {"label": "Angenehm", "color": "#1f8f4e"},
    "warm": {"label": "Warm", "color": "#cf3a2f"},
}

# Der Ruhewert wird links vom Zeitpunkt 0 gezeichnet
REST_X = -5
X_TICKS = [REST_X, 0, 5, 10, 15, 20]
X_LABELS = ["Ruhe", "0", "5", "10", "15", "20"]

# Bewertungen, die mehr als so viele Sekunden zu spät kamen, werden gemeldet
LATE_LIMIT_S = 60


def find_newest_export() -> Path:
    """Neueste Datei protokoll_gefuehlswerte_*.csv (Datum steht im Dateinamen)."""
    files = sorted(PROTOCOL_DIR.glob("protokoll_gefuehlswerte_*.csv"))
    if not files:
        sys.exit(f"Keine Datei protokoll_gefuehlswerte_*.csv in {PROTOCOL_DIR} gefunden.")
    return files[-1]


def load_ratings(path: Path) -> pd.DataFrame:
    df = pd.read_csv(path, dtype={"minute": str})
    required = {"condition", "run_no", "minute", "feel", "status", "outlier"}
    missing = required - set(df.columns)
    if missing:
        sys.exit(f"In {path.name} fehlen Spalten: {', '.join(sorted(missing))}")
    df["x"] = df["minute"].map(lambda m: REST_X if m == "rest" else int(float(m)))
    df["run_label"] = df["condition"] + " Nr. " + df["run_no"].astype(str)
    return df


def split_valid(df: pd.DataFrame) -> pd.DataFrame:
    """Gültige Durchläufe zurückgeben, ausgeschlossene mit Grund ausgeben."""
    runs = df.groupby("run_label").agg(status=("status", "first"), outlier=("outlier", "max"))
    excluded = []
    for label, row in runs.iterrows():
        if row["status"] == "aborted":
            excluded.append((label, "abgebrochen"))
        elif row["status"] != "done":
            excluded.append((label, "nicht abgeschlossen"))
        elif row["outlier"] == 1:
            excluded.append((label, "als Ausreißer markiert"))
    if excluded:
        print("Ausgeschlossene Durchläufe (bleiben in den Rohdaten erhalten):")
        for label, reason in excluded:
            print(f"  - {label}: {reason}")
    excluded_labels = {label for label, _ in excluded}
    valid = df[~df["run_label"].isin(excluded_labels)].copy()

    skipped = valid[valid["feel"].isna()]
    if not skipped.empty:
        print("Nicht bewertete Zeitpunkte (fehlen in Mittelwerten):")
        for _, row in skipped.iterrows():
            print(f"  - {row['run_label']}, Minute {row['minute']}")

    if "delay_s" in valid.columns:
        late = valid[pd.to_numeric(valid["delay_s"], errors="coerce") > LATE_LIMIT_S]
        if not late.empty:
            print(f"Bewertungen mehr als {LATE_LIMIT_S} s zu spät (trotzdem verwendet):")
            for _, row in late.iterrows():
                print(f"  - {row['run_label']}, Minute {row['minute']}: {int(row['delay_s'])} s")
    return valid


def summarize(valid: pd.DataFrame) -> pd.DataFrame:
    rated = valid.dropna(subset=["feel"])
    summary = (
        rated.groupby(["condition", "minute", "x"])["feel"]
        .agg(mean="mean", std="std", n="count")
        .reset_index()
        .sort_values(["condition", "x"])
    )
    summary["mean"] = summary["mean"].round(2)
    summary["std"] = summary["std"].round(2)
    return summary


def write_chart_table(summary: pd.DataFrame, out: Path) -> None:
    """Tabelle für ein Diagramm in Numbers/Excel (deutsches Format: Semikolon, Dezimalkomma).

    Zeilen: Ruhe, 0 … 20 Min. Spalten: Mittelwert je Bedingung, dann SD und n.
    """
    order = ["rest", "0", "5", "10", "15", "20"]
    table = pd.DataFrame({"Zeitpunkt": ["Ruhe" if m == "rest" else f"{m} Min." for m in order]})
    by_condition = {key: summary[summary["condition"] == key].set_index("minute") for key in CONDITIONS}
    for column, suffix in (("mean", ""), ("std", " SD"), ("n", " n")):
        for key, cfg in CONDITIONS.items():
            values = by_condition[key][column]
            table[cfg["label"] + suffix] = [values.get(m) for m in order]
    for cfg in CONDITIONS.values():
        table[cfg["label"] + " n"] = table[cfg["label"] + " n"].fillna(0).astype(int)
    table.to_csv(out, sep=";", decimal=",", index=False, encoding="utf-8-sig")


def style_axis(ax) -> None:
    ax.set_xticks(X_TICKS)
    ax.set_xticklabels(X_LABELS)
    ax.set_xlim(REST_X - 2, 22)
    ax.set_ylim(-3.4, 3.4)
    ax.set_yticks(range(-3, 4))
    ax.axhline(0, color="#999999", linewidth=0.8)
    ax.axvline((REST_X + 0) / 2, color="#cccccc", linewidth=0.8, linestyle=":")
    ax.grid(axis="y", color="#eeeeee")
    ax.set_xlabel("Zeit nach dem Sport [min]")


def plot_mean(summary: pd.DataFrame, valid: pd.DataFrame, out: Path) -> None:
    fig, ax = plt.subplots(figsize=(8, 5), dpi=150)
    for key, cfg in CONDITIONS.items():
        data = summary[summary["condition"] == key]
        if data.empty:
            continue
        n_runs = valid[valid["condition"] == key]["run_label"].nunique()
        # Ruhe (vor dem Sport) als eigener Punkt, Erholung (0–20 Min.) als Linie
        rest = data[data["x"] == REST_X]
        recovery = data[data["x"] >= 0]
        std = recovery["std"].fillna(0)
        ax.plot(recovery["x"], recovery["mean"], marker="o", color=cfg["color"], linewidth=2,
                label=f"{cfg['label']} (n = {n_runs})")
        ax.fill_between(recovery["x"], recovery["mean"] - std, recovery["mean"] + std,
                        color=cfg["color"], alpha=0.15, linewidth=0)
        ax.errorbar(rest["x"], rest["mean"], yerr=rest["std"].fillna(0), fmt="o",
                    color=cfg["color"], capsize=4)
    style_axis(ax)
    ax.set_ylabel("Gefühlswert (−3 sehr kalt … +3 sehr heiß)")
    ax.set_title("Gefühltes Warm/Kalt nach dem Sport\nMittelwert ± Standardabweichung")
    # Legende unter dem Diagramm, damit sie keine Werte bei +3 verdeckt
    ax.legend(loc="upper center", bbox_to_anchor=(0.5, -0.14), ncol=3, frameon=False)
    fig.tight_layout()
    fig.savefig(out)
    plt.close(fig)


def plot_single_runs(valid: pd.DataFrame, out: Path) -> None:
    fig, axes = plt.subplots(1, len(CONDITIONS), figsize=(12, 4.2), dpi=150, sharey=True)
    for ax, (key, cfg) in zip(axes, CONDITIONS.items()):
        data = valid[(valid["condition"] == key)].dropna(subset=["feel"])
        for label, run in data.groupby("run_label"):
            run = run.sort_values("x")
            recovery = run[run["x"] >= 0]
            rest = run[run["x"] == REST_X]
            ax.plot(recovery["x"], recovery["feel"], marker="o", color=cfg["color"], alpha=0.75, linewidth=1.5)
            ax.plot(rest["x"], rest["feel"], marker="o", linestyle="none", color=cfg["color"], alpha=0.75)
        style_axis(ax)
        ax.set_title(f"{cfg['label']} (n = {data['run_label'].nunique()})", color=cfg["color"])
    axes[0].set_ylabel("Gefühlswert (−3 … +3)")
    fig.suptitle("Gefühlswerte aller gültigen Durchläufe")
    fig.tight_layout()
    fig.savefig(out)
    plt.close(fig)


def main() -> None:
    path = Path(sys.argv[1]) if len(sys.argv) > 1 else find_newest_export()
    print(f"Lese {path}")
    df = load_ratings(path)
    valid = split_valid(df)
    if valid.dropna(subset=["feel"]).empty:
        sys.exit("Keine gültigen Bewertungen vorhanden.")

    FIGURE_DIR.mkdir(exist_ok=True)
    PROCESSED_DIR.mkdir(parents=True, exist_ok=True)

    summary = summarize(valid)
    summary_out = PROCESSED_DIR / "gefuehl_zusammenfassung.csv"
    summary.drop(columns="x").to_csv(summary_out, index=False)
    print(f"Tabelle gespeichert: {summary_out.relative_to(ROOT)}")

    chart_out = PROCESSED_DIR / "diagramm_mittelwerte.csv"
    write_chart_table(summary, chart_out)
    print(f"Tabelle für Numbers/Excel gespeichert: {chart_out.relative_to(ROOT)}")

    mean_out = FIGURE_DIR / "gefuehlsverlauf_mittelwert.png"
    plot_mean(summary, valid, mean_out)
    print(f"Diagramm gespeichert: {mean_out.relative_to(ROOT)}")

    single_out = FIGURE_DIR / "gefuehlsverlauf_einzeln.png"
    plot_single_runs(valid, single_out)
    print(f"Diagramm gespeichert: {single_out.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
