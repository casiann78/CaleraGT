import SwiftUI
import Charts

// MARK: - Karten-Stil

struct CardBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color(uiColor: .secondarySystemGroupedBackground))
            )
    }
}

extension View {
    /// Abgerundete Karte auf grauem Hintergrund
    func card() -> some View {
        modifier(CardBackground())
    }
}

/// Karte mit farbigem Titel und Symbol
struct PhaseCard<Content: View>: View {
    let icon: String
    let title: String
    let color: Color
    let content: Content

    init(icon: String, title: String, color: Color, @ViewBuilder content: () -> Content) {
        self.icon = icon
        self.title = title
        self.color = color
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: icon)
                .font(.title3.bold())
                .foregroundStyle(color)
            content
        }
        .card()
    }
}

/// Hinweis-Leiste (z. B. Warnungen)
struct BannerView: View {
    let icon: String
    let text: String
    let color: Color

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(color)
            Text(text)
                .font(.subheadline)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(color.opacity(0.12))
        )
    }
}

/// Zeile einer Checkliste mit Haken
struct ChecklistRow: View {
    let done: Bool
    let text: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: done ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(done ? Color.green : Color.secondary)
            Text(text)
                .foregroundStyle(done ? Color.secondary : Color.primary)
        }
        .font(.subheadline)
    }
}

// MARK: - Ablauf

/// Ruhe → Sport → Erholung → Fertig
struct StepIndicator: View {
    let current: Int
    let color: Color
    private let steps = ["Ruhe", "Sport", "Erholung", "Fertig"]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(0..<steps.count, id: \.self) { i in
                VStack(spacing: 6) {
                    ZStack {
                        Circle()
                            .fill(i <= current ? color : Color.secondary.opacity(0.18))
                            .frame(width: 30, height: 30)
                        if i < current {
                            Image(systemName: "checkmark")
                                .font(.caption.bold())
                                .foregroundStyle(Color.white)
                        } else {
                            Text("\(i + 1)")
                                .font(.caption.bold())
                                .foregroundStyle(i == current ? Color.white : Color.secondary)
                        }
                    }
                    Text(steps[i])
                        .font(.caption2)
                        .foregroundStyle(i == current ? Color.primary : Color.secondary)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }
}

/// Große laufende Uhr (mm:ss)
struct BigClock: View {
    let since: Double?
    var caption: String = ""

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            VStack(spacing: 2) {
                Text(durationString(context.date.ms - (since ?? context.date.ms)))
                    .font(.system(size: 52, weight: .bold, design: .rounded).monospacedDigit())
                if !caption.isEmpty {
                    Text(caption)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
        }
    }
}

/// Ring für die 20-Minuten-Erholung mit Uhr und nächster Bewertung in der Mitte
struct RecoveryRing: View {
    let run: Run

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let elapsed = context.date.ms - (run.t0 ?? context.date.ms)
            let progress = min(1, max(0, elapsed / (20 * 60000)))
            ZStack {
                Circle()
                    .stroke(run.condition.color.opacity(0.15), lineWidth: 16)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(run.condition.color, style: StrokeStyle(lineWidth: 16, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                VStack(spacing: 4) {
                    Text(durationString(elapsed))
                        .font(.system(size: 46, weight: .bold, design: .rounded).monospacedDigit())
                    Text("seit Zeitpunkt 0")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(nextText(now: context.date))
                        .font(.subheadline.bold())
                        .multilineTextAlignment(.center)
                        .padding(.top, 4)
                }
                .padding(28)
            }
            .frame(width: 250, height: 250)
            .frame(maxWidth: .infinity)
        }
    }

    private func nextText(now: Date) -> String {
        guard let t0 = run.t0 else { return "" }
        guard let next = ratingSlots.first(where: { run.ratings[String($0)] == nil }) else {
            return "Alle Bewertungen erledigt"
        }
        let remaining = t0 + Double(next) * 60000 - now.ms
        return remaining > 0
            ? "Bewertung Min. \(next)\nin \(durationString(remaining))"
            : "Bewertung Min. \(next)\njetzt fällig!"
    }
}

/// Fünf Felder für 0, 5, 10, 15, 20 Min. in der Farbe des Gefühlswerts
struct SlotChips: View {
    let run: Run

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            HStack(spacing: 8) {
                ForEach(ratingSlots, id: \.self) { s in
                    SlotChip(minute: s,
                             rating: run.ratings[String(s)],
                             due: run.ratings[String(s)] == nil && context.date.ms - (run.t0 ?? 0) >= Double(s) * 60000)
                }
            }
        }
    }
}

struct SlotChip: View {
    let minute: Int
    let rating: Rating?
    let due: Bool

    var body: some View {
        VStack(spacing: 2) {
            Text("\(minute)′")
                .font(.caption2.bold())
            Text(rating == nil ? "·" : ratingText(rating))
                .font(.headline.monospacedDigit())
        }
        .foregroundStyle(rating?.value != nil ? Color.white : Color.primary)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(rating?.value != nil ? feelingColor(rating?.value) : Color.secondary.opacity(0.12))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(due ? Color.red : Color.clear, lineWidth: 2)
        )
    }
}

// MARK: - Gefühlswerte

/// Diagramm: Gefühl über die Minuten nach Zeitpunkt 0, gestrichelt der Ruhewert
struct FeelingChart: View {
    let run: Run

    private var restValues: [Int] {
        if let v = run.ratings["rest"]?.value { return [v] }
        return []
    }

    var body: some View {
        Chart {
            ForEach(restValues, id: \.self) { v in
                RuleMark(y: .value("Ruhe", v))
                    .foregroundStyle(Color.secondary)
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
            }
            ForEach(run.feelingPoints) { p in
                LineMark(x: .value("Minute", p.minute), y: .value("Gefühl", p.value))
                    .foregroundStyle(run.condition.color)
                    .interpolationMethod(.monotone)
                PointMark(x: .value("Minute", p.minute), y: .value("Gefühl", p.value))
                    .foregroundStyle(feelingColor(p.value))
                    .symbolSize(80)
            }
        }
        .chartXScale(domain: 0...20)
        .chartYScale(domain: -3...3)
        .chartXAxis {
            AxisMarks(values: [0, 5, 10, 15, 20])
        }
        .chartYAxis {
            AxisMarks(values: [-3, -2, -1, 0, 1, 2, 3])
        }
        .chartXAxisLabel("Minuten nach Zeitpunkt 0")
        .frame(height: 190)
    }
}

/// Karte mit Diagramm und Tabelle der Gefühlswerte
struct FeelingCard: View {
    let run: Run

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Gefühlsverlauf").font(.headline)
                Spacer()
                Text("−3 sehr kalt … +3 sehr heiß")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if run.feelingPoints.isEmpty {
                Text("Noch keine Werte nach Zeitpunkt 0.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                FeelingChart(run: run)
            }
            Divider()
            ForEach(["rest"] + ratingSlots.map { String($0) }, id: \.self) { key in
                RatingRow(key: key, rating: run.ratings[key])
            }
            Text("Vertippt? Nicht nachträglich ändern, sondern unter „Notizen“ vermerken.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .card()
    }
}

struct RatingRow: View {
    let key: String
    let rating: Rating?

    private var delayText: String {
        guard let d = rating?.delayS, d > 0 else { return "" }
        return "+\(d) s"
    }

    var body: some View {
        HStack(spacing: 10) {
            Text(key == "rest" ? "Ruhe" : "\(key) Min.")
                .frame(width: 64, alignment: .leading)
            Text(rating?.skipped == true ? "–" : ratingText(rating))
                .font(.subheadline.bold().monospacedDigit())
                .foregroundStyle(rating?.value != nil ? Color.white : Color.secondary)
                .frame(minWidth: 40)
                .padding(.vertical, 3)
                .background(Capsule().fill(feelingColor(rating?.value)))
            if rating?.skipped == true {
                Text("nicht bewertet").font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Text(delayText)
                .font(.caption)
                .foregroundStyle(Color.orange)
            Text(rating.map { timeString($0.time) } ?? "")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .font(.subheadline)
    }
}
