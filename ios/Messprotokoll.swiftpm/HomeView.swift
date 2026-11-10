import SwiftUI
import UniformTypeIdentifiers

struct HomeView: View {
    @EnvironmentObject var store: Store
    @State private var shareItems: ShareItems?
    @State private var showImporter = false
    @State private var importMessage: String?

    var body: some View {
        List {
            if let error = store.saveError {
                Section {
                    Text(error).foregroundStyle(Color.red)
                }
            }
            if store.notificationsDenied {
                Section {
                    Text("Mitteilungen sind ausgeschaltet. Ohne Mitteilungen gibt es keine Erinnerung bei gesperrtem Handy. Einstellungen › Messprotokoll › Mitteilungen einschalten.")
                        .foregroundStyle(Color.red)
                }
            }
            if let active = store.runs.first(where: { $0.isActive }) {
                Section {
                    NavigationLink(value: active.id) {
                        Label("Laufender Durchlauf: \(active.condition.label) Nr. \(active.runNo)", systemImage: "timer")
                    }
                }
            }

            Section("Neuer Durchlauf") {
                HStack(spacing: 8) {
                    ForEach(Condition.allCases) { c in
                        Button {
                            store.newRun(c)
                        } label: {
                            VStack(spacing: 2) {
                                Text(c.label).bold()
                                Text(c.target).font(.caption)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(c.color)
                    }
                }
            }

            ForEach(Condition.allCases) { c in
                ConditionSection(condition: c)
            }

            Section("Daten exportieren") {
                Text("Nach jedem Versuch die CSV-Dateien teilen (z. B. per AirDrop an den Mac) und in protokolle/ im Repository ablegen.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Button("CSV-Dateien und Sicherung teilen") {
                    shareItems = store.exportFiles()
                }
                Button("Sicherung (JSON) laden") {
                    showImporter = true
                }
            }

            Section("Sicherheit") {
                Text("Versuche nur mit Absprache der Eltern oder des Betreuers. Raumtemperatur nicht unter 8 °C und nicht über 30 °C. Keine Sauna, heiße Dusche oder kaltes Wasser direkt nach dem Sport. Bei Schwindel oder Frösteln sofort abbrechen.")
                    .font(.footnote)
            }
        }
        .navigationTitle("Messprotokoll")
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

struct ConditionSection: View {
    @EnvironmentObject var store: Store
    let condition: Condition

    var body: some View {
        let list = store.runsFor(condition)
        Section {
            if list.isEmpty {
                Text("Noch keine Durchläufe.").foregroundStyle(.secondary)
            }
            ForEach(list) { r in
                NavigationLink(value: r.id) {
                    RunRow(run: r)
                }
            }
        } header: {
            HStack {
                Text("\(condition.label) (\(condition.target))")
                    .foregroundStyle(condition.color)
                Spacer()
                Text("\(store.completedCount(condition))/\(targetRuns) fertig")
            }
        }
    }
}

struct RunRow: View {
    let run: Run

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text("Nr. \(run.runNo)").bold()
                Text(run.date).foregroundStyle(.secondary)
                if !run.roomTempStart.isEmpty {
                    Text("\(run.roomTempStart) °C").foregroundStyle(.secondary)
                }
                Spacer()
                StatusBadge(run: run)
            }
            Text("Gefühl R|0|5|10|15|20: " + (["rest"] + ratingSlots.map { String($0) }).map { ratingText(run.ratings[$0]) }.joined(separator: " "))
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
            if run.outlier {
                Text("⚑ als Ausreißer markiert").font(.caption).foregroundStyle(Color.red)
            }
        }
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
            badge("angelegt", Color.secondary)
        default:
            badge("läuft", Color.blue)
        }
    }

    private func badge(_ text: String, _ color: Color) -> some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .overlay(Capsule().stroke(color))
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
