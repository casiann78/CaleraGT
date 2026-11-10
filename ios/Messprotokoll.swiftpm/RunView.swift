import SwiftUI

/// Rückfragen, bevor ein Schritt ausgeführt wird
enum ConfirmKind: String, Identifiable {
    case restWithoutTemp, sportWithoutRest, t0, finishWithoutTemp, delete
    var id: String { rawValue }

    var title: String {
        switch self {
        case .restWithoutTemp: return "Raumtemperatur Start fehlt"
        case .sportWithoutRest: return "Ruhe-Gefühl fehlt"
        case .t0: return "Zeitpunkt 0 bestätigen?"
        case .finishWithoutTemp: return "Raumtemperatur Ende fehlt"
        case .delete: return "Durchlauf löschen?"
        }
    }

    var message: String {
        switch self {
        case .restWithoutTemp: return "Trotzdem mit der Ruhemessung beginnen?"
        case .sportWithoutRest: return "Das Gefühl in Ruhe wurde noch nicht bewertet. Trotzdem mit Sport beginnen?"
        case .t0: return "Die 20-Minuten-Erholung beginnt jetzt. Du wirst bei 0, 5, 10, 15 und 20 Minuten erinnert, auch bei gesperrtem Handy. Stummschalter und Fokus/Nicht stören ausschalten, damit du den Ton hörst."
        case .finishWithoutTemp: return "Trotzdem abschließen?"
        case .delete: return "Der Durchlauf wird endgültig entfernt. Fehlerhafte Messungen besser als Ausreißer markieren statt löschen."
        }
    }

    var button: String {
        switch self {
        case .restWithoutTemp: return "Trotzdem starten"
        case .sportWithoutRest: return "Sport starten"
        case .t0: return "Ja, Erholung startet jetzt"
        case .finishWithoutTemp: return "Abschließen"
        case .delete: return "Endgültig löschen"
        }
    }
}

/// Der große Knopf unten: immer genau der nächste Schritt
struct PrimaryAction {
    let title: String
    let icon: String
    let perform: () -> Void
}

enum RunTab: String, CaseIterable, Identifiable {
    case procedure = "Ablauf"
    case details = "Kopfdaten"
    case notes = "Notizen"
    var id: String { rawValue }
}

struct RunView: View {
    @EnvironmentObject var store: Store
    let runId: String
    @State private var tab: RunTab = .procedure
    @State private var confirm: ConfirmKind?
    @State private var showAbort = false
    @State private var abortReason = ""

    var body: some View {
        if let run = store.run(runId) {
            content(run)
        } else {
            Text("Durchlauf nicht gefunden.").foregroundStyle(.secondary)
        }
    }

    // MARK: Aufbau

    private func content(_ r: Run) -> some View {
        VStack(spacing: 0) {
            Picker("Ansicht", selection: $tab) {
                ForEach(RunTab.allCases) { t in
                    Text(t.rawValue).tag(t)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.vertical, 8)

            switch tab {
            case .procedure:
                procedure(r)
            case .details:
                detailsForm(r)
            case .notes:
                notesForm(r)
            }
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("\(r.condition.label) · Nr. \(r.runNo)")
        .navigationBarTitleDisplayMode(.inline)
        .alert(confirm?.title ?? "",
               isPresented: Binding(get: { confirm != nil }, set: { if !$0 { confirm = nil } }),
               presenting: confirm) { kind in
            Button(kind.button, role: kind == .delete ? ButtonRole.destructive : nil) { perform(kind) }
            Button("Zurück", role: .cancel) {}
        } message: { kind in
            Text(kind.message)
        }
        .background(
            // Eigene Ansicht für den Abbruch-Dialog, damit sich die beiden Dialoge nicht stören
            Color.clear.alert("Versuch abbrechen", isPresented: $showAbort) {
                TextField("Grund, z. B. Schwindel, Frösteln", text: $abortReason)
                Button("Abbrechen und speichern", role: .destructive) {
                    store.abort(runId, reason: abortReason)
                }
                Button("Weiter messen", role: .cancel) {}
            } message: {
                Text("Der Durchlauf bleibt gespeichert und wird als abgebrochen markiert.")
            }
        )
    }

    // MARK: Reiter „Ablauf“

    private func procedure(_ r: Run) -> some View {
        ScrollView {
            VStack(spacing: 16) {
                if r.phase == .aborted {
                    BannerView(icon: "xmark.octagon.fill",
                               text: "Abgebrochen um \(timeString(r.abortedAt))" + (r.abortReason.isEmpty ? "" : ": " + r.abortReason) + ". Der Durchlauf bleibt gespeichert und wird beim Export als „aborted“ markiert.",
                               color: Color.red)
                } else {
                    StepIndicator(current: r.stepIndex, color: r.condition.color)
                        .card()
                    phaseCard(r)
                }

                let w = warnings(for: r)
                if !w.isEmpty {
                    VStack(spacing: 8) {
                        ForEach(w, id: \.self) { warning in
                            BannerView(icon: warning.danger ? "exclamationmark.octagon.fill" : "exclamationmark.triangle.fill",
                                       text: warning.text,
                                       color: warning.danger ? Color.red : Color.orange)
                        }
                    }
                }

                if r.t0 != nil || r.ratings["rest"] != nil {
                    FeelingCard(run: r)
                }

                if r.isActive {
                    Button(role: .destructive) {
                        abortReason = ""
                        showAbort = true
                    } label: {
                        Label("Versuch abbrechen", systemImage: "xmark.octagon")
                    }
                    .padding(.top, 4)
                }
            }
            .padding()
        }
        .scrollDismissesKeyboard(.interactively)
        .safeAreaInset(edge: .bottom) {
            actionBar(r)
        }
    }

    @ViewBuilder
    private func phaseCard(_ r: Run) -> some View {
        let color = r.condition.color
        switch r.phase {
        case .setup:
            PhaseCard(icon: "checklist", title: "Vorbereitung", color: color) {
                Text("Sensor anlegen, Kopfdaten ausfüllen und dann 10–15 Minuten ruhig sitzen.")
                    .font(.subheadline)
                ChecklistRow(done: parseNumber(r.roomTempStart) != nil, text: "Raumtemperatur Start")
                ChecklistRow(done: parseNumber(r.humidity) != nil, text: "Luftfeuchte")
                ChecklistRow(done: !r.training.isEmpty, text: "Training")
                ChecklistRow(done: !r.clothing.isEmpty, text: "Kleidung")
                Button("Kopfdaten ausfüllen") { tab = .details }
                    .buttonStyle(.bordered)
            }

        case .rest:
            PhaseCard(icon: "figure.mind.and.body", title: "Ruhemessung", color: color) {
                BigClock(since: r.restStart, caption: "seit \(timeString(r.restStart)) · Ziel 10–15 Min.")
                restRatingRow(r)
            }

        case .afterRest:
            PhaseCard(icon: "figure.run", title: "Bereit für den Sport", color: color) {
                Text("Ruhemessung \(timeString(r.restStart))–\(timeString(r.restEnd))")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                restRatingRow(r)
                Text("Jetzt Sport machen, z. B. 30 Minuten, immer mit gleicher Intensität.")
                    .font(.subheadline)
            }

        case .sport:
            PhaseCard(icon: "figure.run", title: "Sport", color: color) {
                BigClock(since: r.sportStart, caption: "seit \(timeString(r.sportStart))")
                Text("Danach sofort in den Messbereich. Bei Schwindel oder Frösteln sofort abbrechen.")
                    .font(.subheadline)
            }

        case .ready:
            PhaseCard(icon: "thermometer", title: "Ab in den Messbereich", color: color) {
                Text("Geh sofort in den Messbereich und bestätige dort Zeitpunkt 0.")
                    .font(.subheadline)
                Label("Erinnerung bei 0, 5, 10, 15 und 20 Min., auch bei gesperrtem Handy", systemImage: "bell.badge")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

        case .recovery:
            PhaseCard(icon: "timer", title: "Erholung", color: color) {
                RecoveryRing(run: r)
                SlotChips(run: r)
                if r.allSlotsRated {
                    Text("Alle Werte erfasst. Jetzt die Raumtemperatur messen und eintragen.")
                        .font(.subheadline.bold())
                    LabeledContent("Raumtemperatur Ende") {
                        HStack(spacing: 4) {
                            TextField("°C", text: text(\.roomTempEnd))
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                            Text("°C").foregroundStyle(.secondary)
                        }
                    }
                } else {
                    Text("Erst bewerten, dann Kurve ansehen. Während des Versuchs nicht in die CALERA-App schauen.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    reminderStatus(r)
                }
            }

        case .done:
            PhaseCard(icon: "checkmark.seal.fill", title: "Abgeschlossen", color: Color.green) {
                Text("Zeitpunkt 0: \(dateTimeString(r.t0))")
                    .font(.subheadline)
                Text(r.sensorFile.isEmpty
                     ? "Sensor-CSV nach data/raw/ kopieren und den Dateinamen unter „Kopfdaten“ eintragen."
                     : "Sensor-Datei: \(r.sensorFile)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

        case .aborted:
            EmptyView()
        }
    }

    private func restRatingRow(_ r: Run) -> some View {
        HStack {
            Text("Gefühl in Ruhe")
            Spacer()
            if let v = r.ratings["rest"] {
                Text(ratingText(v))
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(Color.white)
                    .frame(minWidth: 40)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(feelingColor(v.value)))
            } else {
                Button("Jetzt bewerten") {
                    store.ratingPrompt = RatingPrompt(runId: runId, slot: "rest")
                }
                .buttonStyle(.bordered)
            }
        }
        .font(.subheadline)
    }

    @ViewBuilder
    private func reminderStatus(_ r: Run) -> some View {
        if store.notificationsDenied {
            BannerView(icon: "bell.slash.fill",
                       text: "Mitteilungen sind ausgeschaltet. Ohne sie kommt keine Erinnerung bei gesperrtem Handy.",
                       color: Color.red)
        } else {
            Label("Geplante Erinnerungen: \(store.pendingReminderCount)", systemImage: "bell")
                .font(.footnote)
                .foregroundStyle(store.pendingReminderCount > 0 ? Color.secondary : Color.orange)
        }
    }

    // MARK: Knopf für den nächsten Schritt

    @ViewBuilder
    private func actionBar(_ r: Run) -> some View {
        if let action = primaryAction(r) {
            Button {
                action.perform()
            } label: {
                Label(action.title, systemImage: action.icon)
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(r.condition.color)
            .padding(.horizontal)
            .padding(.vertical, 10)
            .background(.bar)
        }
    }

    private func primaryAction(_ r: Run) -> PrimaryAction? {
        switch r.phase {
        case .setup:
            return PrimaryAction(title: "Ruhemessung starten", icon: "play.fill") {
                if parseNumber(r.roomTempStart) == nil { confirm = .restWithoutTemp } else { store.startRest(runId) }
            }
        case .rest:
            return PrimaryAction(title: "Ruhemessung beenden", icon: "stop.fill") {
                store.endRest(runId)
            }
        case .afterRest:
            return PrimaryAction(title: "Sport starten", icon: "figure.run") {
                if r.ratings["rest"] == nil { confirm = .sportWithoutRest } else { store.startSport(runId) }
            }
        case .sport:
            return PrimaryAction(title: "Sport beendet", icon: "stop.fill") {
                store.endSport(runId)
            }
        case .ready:
            return PrimaryAction(title: "Zeitpunkt 0 bestätigen", icon: "flag.fill") {
                confirm = .t0
            }
        case .recovery:
            guard r.allSlotsRated else { return nil }
            return PrimaryAction(title: "Durchlauf abschließen", icon: "checkmark.circle.fill") {
                if parseNumber(r.roomTempEnd) == nil { confirm = .finishWithoutTemp } else { store.finish(runId) }
            }
        case .done, .aborted:
            return nil
        }
    }

    private func perform(_ kind: ConfirmKind) {
        switch kind {
        case .restWithoutTemp: store.startRest(runId)
        case .sportWithoutRest: store.startSport(runId)
        case .t0:
            store.requestNotificationPermission()
            store.confirmT0(runId)
        case .finishWithoutTemp: store.finish(runId)
        case .delete: store.delete(runId)
        }
    }

    // MARK: Reiter „Kopfdaten“

    private func detailsForm(_ r: Run) -> some View {
        Form {
            Section("Durchlauf") {
                Picker("Bedingung", selection: conditionBinding) {
                    ForEach(Condition.allCases) { c in
                        Label("\(c.label) (\(c.target))", systemImage: c.icon).tag(c)
                    }
                }
                LabeledContent("Durchlauf-Nr.") {
                    TextField("1", text: text(\.runNo))
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                }
                DatePicker("Datum", selection: dateBinding, displayedComponents: .date)
            }

            Section {
                numberField("Raumtemperatur Start", unit: "°C", \.roomTempStart)
                if r.phase != .recovery {
                    numberField("Raumtemperatur Ende", unit: "°C", \.roomTempEnd)
                }
                numberField("Luftfeuchte", unit: "%", \.humidity)
                labeled("Ort / wie wurde die Temperatur erzeugt?", "z. B. Bad mit Heizlüfter", \.location)
            } header: {
                Text("Umgebung")
            } footer: {
                Text("Ziel: \(r.condition.target). Immer die tatsächlich gemessene Temperatur eintragen.")
            }

            Section("Person") {
                labeled("Training (Art, Dauer, Intensität)", "z. B. 30 Min. Joggen, mittel", \.training)
                labeled("Kleidung", "z. B. T-Shirt, kurze Hose", \.clothing)
            }

            Section {
                labeled("Name der Sensor-CSV", "z. B. calera_2026-11-10.csv", \.sensorFile)
            } header: {
                Text("Sensor")
            } footer: {
                Text("Die Datei kommt unverändert nach data/raw/ im Repository.")
            }
        }
        .scrollDismissesKeyboard(.interactively)
    }

    // MARK: Reiter „Notizen“

    private func notesForm(_ r: Run) -> some View {
        Form {
            Section {
                TextField("Besonderheiten, Störungen, Uhrzeit-Abweichung Handy/Sensor …", text: text(\.notes), axis: .vertical)
                    .lineLimit(4...12)
            } header: {
                Text("Notizen")
            } footer: {
                Text("Vertippt bei einer Bewertung? Hier vermerken, nicht nachträglich ändern.")
            }

            Section {
                Toggle("Als Ausreißer markieren", isOn: outlierBinding)
                if r.outlier {
                    labeled("Begründung", "Warum ist die Messung auffällig?", \.outlierReason)
                }
            } header: {
                Text("Auffälligkeiten")
            } footer: {
                Text("Fehlerhafte Messungen markieren und begründen, nicht löschen.")
            }

            Section {
                Button("Durchlauf löschen", role: .destructive) { confirm = .delete }
            }
        }
        .scrollDismissesKeyboard(.interactively)
    }

    // MARK: Eingabefelder

    private func text(_ keyPath: WritableKeyPath<Run, String>) -> Binding<String> {
        Binding(
            get: { store.run(runId)?[keyPath: keyPath] ?? "" },
            set: { newValue in store.update(runId) { $0[keyPath: keyPath] = newValue } }
        )
    }

    private var outlierBinding: Binding<Bool> {
        Binding(
            get: { store.run(runId)?.outlier ?? false },
            set: { newValue in store.update(runId) { $0.outlier = newValue } }
        )
    }

    private var conditionBinding: Binding<Condition> {
        Binding(
            get: { store.run(runId)?.condition ?? .kalt },
            set: { newValue in store.update(runId) { $0.condition = newValue } }
        )
    }

    private var dateBinding: Binding<Date> {
        Binding(
            get: { Fmt.day.date(from: store.run(runId)?.date ?? "") ?? Date() },
            set: { newValue in store.update(runId) { $0.date = Fmt.day.string(from: newValue) } }
        )
    }

    private func numberField(_ label: String, unit: String, _ keyPath: WritableKeyPath<Run, String>) -> some View {
        LabeledContent(label) {
            HStack(spacing: 4) {
                TextField("–", text: text(keyPath))
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                Text(unit).foregroundStyle(.secondary)
            }
        }
    }

    private func labeled(_ label: String, _ placeholder: String, _ keyPath: WritableKeyPath<Run, String>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.caption).foregroundStyle(.secondary)
            TextField(placeholder, text: text(keyPath), axis: .vertical)
        }
    }
}
