import SwiftUI
import UniformTypeIdentifiers

// MARK: - Übersicht

struct HomeView: View {
    @EnvironmentObject var store: Store
    @State private var showSettings = false
    @State private var showAnalysis = false

    private var remindersNeedAttention: Bool {
        store.notificationStatusKnown && (store.notificationStatus != .authorized || !store.notificationHints.isEmpty)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if let error = store.saveError {
                    BannerView(icon: "exclamationmark.triangle.fill", text: error, color: Color.red)
                }
                if remindersNeedAttention {
                    Button {
                        showSettings = true
                    } label: {
                        BannerView(icon: "bell.slash.fill",
                                   text: "Erinnerungen kommen eventuell nicht an. Tippen zum Prüfen.",
                                   color: Color.orange)
                    }
                    .buttonStyle(.plain)
                }
                if let active = store.runs.first(where: { $0.isActive }) {
                    ActiveRunCard(run: active)
                }
                ProgressOverview()
                NewRunButtons()
                ForEach(Condition.allCases) { c in
                    ConditionRunList(condition: c)
                }
            }
            .padding()
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("Messprotokoll")
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    showAnalysis = true
                } label: {
                    Image(systemName: "chart.xyaxis.line")
                }
                .accessibilityLabel("Auswertung")
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showSettings = true
                } label: {
                    Image(systemName: "gearshape")
                }
                .accessibilityLabel("Einstellungen")
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
                .environmentObject(store)
        }
        .sheet(isPresented: $showAnalysis) {
            AnalysisView()
                .environmentObject(store)
        }
    }
}

/// Karte für den Durchlauf, der gerade läuft
struct ActiveRunCard: View {
    let run: Run

    var body: some View {
        NavigationLink(value: run.id) {
            HStack(spacing: 14) {
                Image(systemName: "timer")
                    .font(.title2)
                    .foregroundStyle(Color.white)
                    .frame(width: 48, height: 48)
                    .background(Circle().fill(run.condition.color))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Laufender Durchlauf")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(run.condition.label) · Nr. \(run.runNo)")
                        .font(.headline)
                    Text(run.phaseTitle)
                        .font(.subheadline)
                        .foregroundStyle(run.condition.color)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(.tertiary)
            }
            .card()
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(run.condition.color, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}

/// Drei Fortschrittsringe: wie viele Durchläufe pro Bedingung fertig sind
struct ProgressOverview: View {
    @EnvironmentObject var store: Store

    private var totalDone: Int {
        Condition.allCases.reduce(0) { $0 + min(store.completedCount($1), targetRuns) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Fortschritt").font(.headline)
                Spacer()
                Text("\(totalDone) von \(targetRuns * Condition.allCases.count) Messungen")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: 0) {
                ForEach(Condition.allCases) { c in
                    ProgressRing(condition: c, done: store.completedCount(c))
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .card()
    }
}

struct ProgressRing: View {
    let condition: Condition
    let done: Int

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .stroke(condition.color.opacity(0.15), lineWidth: 8)
                Circle()
                    .trim(from: 0, to: min(1, Double(done) / Double(targetRuns)))
                    .stroke(condition.color, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                if done >= targetRuns {
                    Image(systemName: "checkmark")
                        .font(.title3.bold())
                        .foregroundStyle(condition.color)
                } else {
                    Text("\(done)/\(targetRuns)")
                        .font(.headline.monospacedDigit())
                }
            }
            .frame(width: 70, height: 70)
            Text(condition.label)
                .font(.subheadline.bold())
            Text(condition.target)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

/// Drei große Knöpfe für einen neuen Durchlauf
struct NewRunButtons: View {
    @EnvironmentObject var store: Store

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Neuer Durchlauf").font(.headline)
            HStack(spacing: 10) {
                ForEach(Condition.allCases) { c in
                    Button {
                        store.newRun(c)
                    } label: {
                        VStack(spacing: 6) {
                            Image(systemName: c.icon)
                                .font(.title2)
                            Text(c.label)
                                .font(.subheadline.bold())
                            Text(c.target)
                                .font(.caption2)
                                .opacity(0.9)
                        }
                        .foregroundStyle(Color.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(c.color.gradient)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

/// Liste der Durchläufe einer Bedingung
struct ConditionRunList: View {
    @EnvironmentObject var store: Store
    let condition: Condition

    var body: some View {
        let list = store.runsFor(condition)
        if !list.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label(condition.label, systemImage: condition.icon)
                        .font(.headline)
                        .foregroundStyle(condition.color)
                    Spacer()
                    Text("\(store.completedCount(condition))/\(targetRuns) fertig")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                ForEach(list) { r in
                    NavigationLink(value: r.id) {
                        RunRow(run: r)
                    }
                    .buttonStyle(.plain)
                    if r.id != list.last?.id {
                        Divider()
                    }
                }
            }
            .card()
        }
    }
}

struct RunRow: View {
    let run: Run

    private var subtitle: String {
        var parts = [run.displayDate]
        if !run.roomTempStart.isEmpty { parts.append("\(run.roomTempStart) °C") }
        return parts.joined(separator: " · ")
    }

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text("Nr. \(run.runNo)").font(.headline)
                    StatusBadge(run: run)
                    if run.outlier {
                        Image(systemName: "flag.fill")
                            .font(.caption)
                            .foregroundStyle(Color.red)
                    }
                }
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            MiniFeelingStrip(run: run)
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .contentShape(Rectangle())
    }
}

/// Sechs kleine Balken: Ruhe, 0, 5, 10, 15, 20 Min. in der Farbe des Gefühls
struct MiniFeelingStrip: View {
    let run: Run

    var body: some View {
        HStack(spacing: 3) {
            ForEach(["rest"] + ratingSlots.map { String($0) }, id: \.self) { key in
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(feelingColor(run.ratings[key]?.value))
                    .frame(width: 9, height: 20)
            }
        }
        .accessibilityLabel("Gefühlswerte")
    }
}

struct StatusBadge: View {
    let run: Run

    var body: some View {
        switch run.phase {
        case .done:
            badge("fertig", Color.green)
        case .aborted:
            badge("abgebrochen", Color.red)
        case .setup:
            badge("angelegt", Color.gray)
        default:
            badge("läuft", Color.blue)
        }
    }

    private func badge(_ text: String, _ color: Color) -> some View {
        Text(text)
            .font(.caption2.bold())
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Capsule().fill(color.opacity(0.15)))
    }
}

// MARK: - Einstellungen

struct SettingsView: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    @State private var shareItems: ShareItems?
    @State private var showImporter = false
    @State private var importMessage: String?
    @State private var noXlsx = false

    var body: some View {
        NavigationStack {
            List {
                NotificationSection()

                Section {
                    Button {
                        shareItems = store.exportXlsxFile()
                        noXlsx = shareItems == nil
                    } label: {
                        Label("Excel-Datei mit Diagrammen teilen", systemImage: "chart.xyaxis.line")
                    }
                    if noXlsx {
                        Text("Noch keine Excel-Datei möglich: Es gibt keinen abgeschlossenen Durchlauf (abgebrochene und als Ausreißer markierte zählen nicht).")
                            .font(.footnote)
                            .foregroundStyle(Color.orange)
                    }
                    Button {
                        shareItems = store.exportFiles()
                    } label: {
                        Label("Alle Dateien teilen (CSV, Sicherung, Excel)", systemImage: "square.and.arrow.up")
                    }
                    Button {
                        showImporter = true
                    } label: {
                        Label("Sicherung (JSON) laden", systemImage: "square.and.arrow.down")
                    }
                } header: {
                    Text("Daten")
                } footer: {
                    Text("Nach jedem Versuch die CSV-Dateien teilen (z. B. per AirDrop an den Mac) und in protokolle/ im Repository ablegen.")
                }

                Section("Sicherheit") {
                    Label("Nur mit Absprache der Eltern oder des Betreuers.", systemImage: "person.2")
                    Label("Raumtemperatur nicht unter 8 °C und nicht über 30 °C.", systemImage: "thermometer")
                    Label("Keine Sauna, heiße Dusche oder kaltes Wasser direkt nach dem Sport.", systemImage: "drop")
                    Label("Bei Schwindel oder Frösteln sofort abbrechen.", systemImage: "exclamationmark.triangle")
                }
                .font(.subheadline)

                Section("Über") {
                    LabeledContent("Projekt", value: "Jugend forscht 2027")
                    LabeledContent("Sensor", value: "CALERA Research")
                    LabeledContent("Durchläufe gespeichert", value: "\(store.runs.count)")
                }
            }
            .navigationTitle("Einstellungen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { dismiss() }
                }
            }
            .sheet(item: $shareItems) { items in
                ActivityView(items: items.urls)
            }
            .fileImporter(isPresented: $showImporter, allowedContentTypes: [UTType.json]) { result in
                importMessage = store.importBackup(result)
            }
            .alert(importMessage ?? "", isPresented: Binding(get: { importMessage != nil },
                                                             set: { if !$0 { importMessage = nil } })) {
                Button("OK", role: .cancel) {}
            }
        }
    }
}

/// Zeigt, ob Erinnerungen ankommen können, und bietet eine Test-Erinnerung an
struct NotificationSection: View {
    @EnvironmentObject var store: Store
    @Environment(\.openURL) private var openURL
    @State private var testSent = false

    private var statusText: String {
        switch store.notificationStatus {
        case .authorized: return "erlaubt"
        case .denied: return "ausgeschaltet"
        case .notDetermined: return "noch nicht erlaubt"
        case .provisional: return "nur leise"
        case .ephemeral: return "eingeschränkt"
        @unknown default: return "unbekannt"
        }
    }

    private var isOK: Bool {
        store.notificationStatus == .authorized && store.notificationHints.isEmpty
    }

    var body: some View {
        Section {
            HStack {
                Label("Mitteilungen", systemImage: isOK ? "bell.fill" : "bell.slash.fill")
                Spacer()
                Text(statusText)
                    .bold()
                    .foregroundStyle(isOK ? Color.green : Color.red)
            }
            if store.notificationStatus == .denied {
                Text("Ohne Mitteilungen gibt es keine Erinnerung bei gesperrtem Handy.")
                    .font(.footnote)
                    .foregroundStyle(Color.red)
            }
            ForEach(store.notificationHints, id: \.self) { hint in
                Label(hint, systemImage: "exclamationmark.triangle.fill")
                    .font(.footnote)
                    .foregroundStyle(Color.orange)
            }
            if store.notificationStatus == .notDetermined {
                Button("Mitteilungen erlauben") { store.requestNotificationPermission() }
            }
            if !isOK && store.notificationStatus != .notDetermined {
                Button("Mitteilungs-Einstellungen öffnen") {
                    if let url = URL(string: UIApplication.openNotificationSettingsURLString) { openURL(url) }
                }
            }
            Button {
                store.sendTestNotification()
                testSent = true
            } label: {
                Label("Test-Erinnerung in 10 Sekunden", systemImage: "bell.badge")
            }
        } header: {
            Text("Erinnerungen")
        } footer: {
            Text(testSent
                 ? "Jetzt das iPhone sperren und 10 Sekunden warten. Es sollte eine Mitteilung mit Ton kommen."
                 : "Vor jedem Versuch: Stummschalter aus, Fokus/Nicht stören aus, Lautstärke hoch.")
        }
    }
}

/// Teilen-Menü von iOS (AirDrop, Dateien, Mail …)
struct ActivityView: UIViewControllerRepresentable {
    let items: [URL]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
