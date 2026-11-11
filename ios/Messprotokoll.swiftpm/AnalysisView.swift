import SwiftUI
import Charts

// MARK: - Berechnung

/// Mittelwert, Standardabweichung und n eines Zeitpunkts für eine Bedingung
struct MeanPoint: Identifiable {
    let condition: Condition
    let minute: Int
    let mean: Double
    let sd: Double
    let n: Int
    var id: String { condition.rawValue + "-\(minute)" }
}

/// Gültig sind nur abgeschlossene, nicht abgebrochene und nicht als Ausreißer markierte Durchläufe
func validRuns(_ runs: [Run], _ c: Condition) -> [Run] {
    runs.filter { $0.condition == c && $0.finished && !$0.aborted && !$0.outlier }
}

func meanValue(_ values: [Double]) -> Double {
    values.isEmpty ? 0 : values.reduce(0, +) / Double(values.count)
}

/// Stichproben-Standardabweichung (n − 1); bei weniger als 2 Werten 0
func standardDeviation(_ values: [Double]) -> Double {
    guard values.count > 1 else { return 0 }
    let m = meanValue(values)
    let squares = values.map { ($0 - m) * ($0 - m) }
    return (squares.reduce(0, +) / Double(values.count - 1)).squareRoot()
}

/// Kennwerte für einen Zeitpunkt ("rest" oder Minute)
func stats(_ runs: [Run], slot: String) -> (mean: Double, sd: Double, n: Int) {
    let values = runs.compactMap { $0.ratings[slot]?.value }.map { Double($0) }
    return (meanValue(values), standardDeviation(values), values.count)
}

func meanPoints(_ runs: [Run]) -> [MeanPoint] {
    var points: [MeanPoint] = []
    for c in Condition.allCases {
        let valid = validRuns(runs, c)
        for s in ratingSlots {
            let st = stats(valid, slot: String(s))
            if st.n > 0 {
                points.append(MeanPoint(condition: c, minute: s, mean: st.mean, sd: st.sd, n: st.n))
            }
        }
    }
    return points
}

// MARK: - Diagramm

/// Mittelwert (Linie) ± Standardabweichung (senkrechte Striche) pro Bedingung
struct MeanChart: View {
    let points: [MeanPoint]
    var height: CGFloat = 280

    var body: some View {
        Chart {
            ForEach(points) { p in
                RuleMark(x: .value("Minute", p.minute),
                         yStart: .value("Untergrenze", max(-3, p.mean - p.sd)),
                         yEnd: .value("Obergrenze", min(3, p.mean + p.sd)))
                    .foregroundStyle(by: .value("Bedingung", p.condition.label))
                    .lineStyle(StrokeStyle(lineWidth: 6, lineCap: .round))
                    .opacity(0.25)
                LineMark(x: .value("Minute", p.minute), y: .value("Gefühl", p.mean))
                    .foregroundStyle(by: .value("Bedingung", p.condition.label))
                    .lineStyle(StrokeStyle(lineWidth: 3))
                PointMark(x: .value("Minute", p.minute), y: .value("Gefühl", p.mean))
                    .foregroundStyle(by: .value("Bedingung", p.condition.label))
                    .symbolSize(70)
            }
        }
        .chartForegroundStyleScale([
            Condition.kalt.label: Condition.kalt.color,
            Condition.angenehm.label: Condition.angenehm.color,
            Condition.warm.label: Condition.warm.color,
        ])
        .chartXScale(domain: -1...21)
        .chartYScale(domain: -3...3)
        .chartXAxis {
            AxisMarks(values: [0, 5, 10, 15, 20])
        }
        .chartYAxis {
            AxisMarks(values: [-3, -2, -1, 0, 1, 2, 3])
        }
        .chartXAxisLabel("Minuten nach Zeitpunkt 0")
        .chartYAxisLabel("Gefühl")
        .chartLegend(position: .bottom)
        .frame(height: height)
    }
}

/// Diagramm mit Überschrift und n, für die Bilddatei
struct MeanChartPoster: View {
    let runs: [Run]

    private var nText: String {
        Condition.allCases
            .map { "\($0.label) n = \(validRuns(runs, $0).count)" }
            .joined(separator: " · ")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Gefühltes Warm/Kalt nach dem Sport")
                .font(.title2.bold())
            Text("Mittelwert ± Standardabweichung · \(nText)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            MeanChart(points: meanPoints(runs), height: 380)
            Text("Gefühlswert: −3 sehr kalt … +3 sehr heiß. Nur abgeschlossene Durchläufe ohne Ausreißer.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Seite „Auswertung“

struct AnalysisView: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    @State private var shareItems: ShareItems?

    private var excluded: [Run] {
        store.runs.filter { $0.aborted || ($0.finished && $0.outlier) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    let points = meanPoints(store.runs)
                    if points.isEmpty {
                        BannerView(icon: "chart.xyaxis.line",
                                   text: "Noch keine abgeschlossenen Durchläufe. Das Diagramm erscheint, sobald der erste Durchlauf fertig ist.",
                                   color: Color.blue)
                    } else {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Gefühlsverlauf nach dem Sport").font(.headline)
                            Text("Mittelwert ± Standardabweichung").font(.caption).foregroundStyle(.secondary)
                            MeanChart(points: points)
                            Button {
                                shareChart()
                            } label: {
                                Label("Diagramm als Bild teilen", systemImage: "square.and.arrow.up")
                            }
                            .buttonStyle(.bordered)
                            Button {
                                shareItems = store.exportXlsxFile()
                            } label: {
                                Label("Excel-Datei mit Diagrammen teilen", systemImage: "tablecells")
                            }
                            .buttonStyle(.bordered)
                        }
                        .card()
                    }

                    SummaryTable(runs: store.runs)

                    if !excluded.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Nicht berücksichtigt").font(.headline)
                            ForEach(excluded) { r in
                                Text("\(r.condition.label) Nr. \(r.runNo): " + (r.aborted ? "abgebrochen" : "als Ausreißer markiert"))
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .card()
                    }
                }
                .padding()
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("Auswertung")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { dismiss() }
                }
            }
            .sheet(item: $shareItems) { items in
                ActivityView(items: items.urls)
            }
        }
    }

    private func shareChart() {
        let runs = store.runs
        Task { @MainActor in
            let name = "gefuehlsverlauf_alle_bedingungen_\(Fmt.day.string(from: Date())).png"
            if let url = renderPNG(MeanChartPoster(runs: runs), width: 1000, filename: name) {
                shareItems = ShareItems(urls: [url])
            }
        }
    }
}

/// Tabelle: Mittelwert ± SD pro Bedingung und Zeitpunkt, mit n
struct SummaryTable: View {
    let runs: [Run]
    private static let slots = ["rest", "0", "5", "10", "15", "20"]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Mittelwerte").font(.headline)
            HStack {
                Text("").frame(width: 62, alignment: .leading)
                ForEach(Condition.allCases) { c in
                    Text("\(c.label)\nn = \(validRuns(runs, c).count)")
                        .font(.caption.bold())
                        .foregroundStyle(c.color)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                }
            }
            ForEach(Self.slots, id: \.self) { slot in
                Divider()
                HStack {
                    Text(slot == "rest" ? "Ruhe" : "\(slot) Min.")
                        .font(.subheadline)
                        .frame(width: 62, alignment: .leading)
                    ForEach(Condition.allCases) { c in
                        Text(cellText(c, slot))
                            .font(.subheadline.monospacedDigit())
                            .frame(maxWidth: .infinity)
                    }
                }
            }
            Text("Werte: Mittelwert ± Standardabweichung. Nur abgeschlossene Durchläufe ohne Ausreißer.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .card()
    }

    private func cellText(_ c: Condition, _ slot: String) -> String {
        let st = stats(validRuns(runs, c), slot: slot)
        guard st.n > 0 else { return "–" }
        return String(format: "%+.1f ± %.1f", st.mean, st.sd)
    }
}
