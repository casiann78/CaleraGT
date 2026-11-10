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
        case .t0: return "Die 20-Minuten-Erholung beginnt jetzt. Du wirst bei 0, 5, 10, 15 und 20 Minuten erinnert, auch bei gesperrtem Handy. Stummschalter aus und Fokus/Nicht stören aus, damit du den Ton hörst."
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

struct RunView: View {
    @EnvironmentObject var store: Store
    let runId: String
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
        Form {
            Section("Ablauf") {
                phaseContent(r)
            }

            Section("Kopfdaten") {
                Picker("Bedingung", selection: conditionBinding) {
                    ForEach(Condition.allCases) { c in
                        Text("\(c.label) (\(c.target))").tag(c)
                    }
                }
                labeled("Durchlauf-Nr.", "1", \.runNo, keyboard: .numberPad)
                DatePicker("Datum", selection: dateBinding, displayedComponents: .date)
                labeled("Raumtemperatur Start [°C]", "z. B. 11,5", \.roomTempStart, keyboard: .decimalPad)
                if r.phase != .recovery {
                    labeled("Raumtemperatur Ende [°C]", "z. B. 11,8", \.roomTempEnd, keyboard: .decimalPad)
                }
                Group {
                    labeled("Luftfeuchte [%]", "z. B. 45", \.humidity, keyboard: .decimalPad)
                    labeled("Training (Art, Dauer, Intensität)", "z. B. 30 Min. Joggen, mittel", \.training)
                    labeled("Kleidung", "z. B. T-Shirt, kurze Hose", \.clothing)
                    labeled("Ort / wie wurde die Temperatur erzeugt?", "z. B. Bad mit Heizlüfter", \.location)
                    labeled("Name der Sensor-CSV (data/raw/)", "", \.sensorFile)
                }
                ForEach(warnings(for: r), id: \.self) { w in
                    Text(w.text)
                        .font(.footnote)
                        .foregroundStyle(w.danger ? Color.red : Color.orange)
                }
            }

            Section("Gefühlswerte (−3 sehr kalt … +3 sehr heiß)") {
                ForEach(["rest"] + ratingSlots.map { String($0) }, id: \.self) { key in
                    RatingRow(key: key, rating: r.ratings[key])
                }
                Text("Vertippt? Nicht nachträglich ändern, sondern unter „Notizen“ vermerken.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("Notizen und Auffälligkeiten") {
                TextField("Notizen (Besonderheiten, Störungen, Uhrzeit-Abweichung Handy/Sensor …)",
                          text: text(\.notes), axis: .vertical)
                    .lineLimit(3...8)
                Toggle("Als Ausreißer / fehlerhafte Messung markieren", isOn: outlierBinding)
                labeled("Begründung", "", \.outlierReason)
            }

            Section {
                Button("Durchlauf löschen", role: .destructive) { confirm = .delete }
                Text("Abgebrochene oder fehlerhafte Durchläufe besser behalten und markieren statt löschen.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
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

    @ViewBuilder
    private func phaseContent(_ r: Run) -> some View {
        switch r.phase {
        case .setup:
            Text("1. Kopfdaten unten ausfüllen (mindestens Raumtemperatur Start).")
            Text("2. Sensor anlegen und Ruhemessung beginnen (10–15 Min.).")
            Button("Ruhemessung starten") {
                if parseNumber(r.roomTempStart) == nil { confirm = .restWithoutTemp } else { store.startRest(runId) }
            }
            .bold()

        case .rest:
            Text("Ruhemessung seit \(timeString(r.restStart)) · Ziel 10–15 Min.").foregroundStyle(.secondary)
            ClockView(since: r.restStart)
            Text(restText(r))
            Button("Ruhe-Gefühl bewerten") { store.ratingPrompt = RatingPrompt(runId: runId, slot: "rest") }
            Button("Ruhemessung beenden") { store.endRest(runId) }.bold()

        case .afterRest:
            Text("Ruhemessung \(timeString(r.restStart))–\(timeString(r.restEnd)) · \(restText(r))")
            if r.ratings["rest"] == nil {
                Button("Ruhe-Gefühl bewerten") { store.ratingPrompt = RatingPrompt(runId: runId, slot: "rest") }
            }
            Text("3. Sport machen (z. B. 30 Min., immer gleiche Intensität).")
            Button("Sport starten") {
                if r.ratings["rest"] == nil { confirm = .sportWithoutRest } else { store.startSport(runId) }
            }
            .bold()

        case .sport:
            Text("Sport seit \(timeString(r.sportStart))").foregroundStyle(.secondary)
            ClockView(since: r.sportStart)
            Text("Bei Schwindel oder Frösteln sofort abbrechen.").foregroundStyle(Color.orange)
            Button("Sport beendet") { store.endSport(runId) }.bold()

        case .ready:
            Text("Sport \(timeString(r.sportStart))–\(timeString(r.sportEnd)).")
            Text("Sofort in den Messbereich gehen. Sobald du dort bist, Zeitpunkt 0 bestätigen. Danach wirst du bei 0, 5, 10, 15 und 20 Min. erinnert.")
            Button("Ich bin im Messbereich – Zeitpunkt 0 bestätigen") { confirm = .t0 }.bold()

        case .recovery:
            Text("Zeitpunkt 0: \(timeString(r.t0)) · Handy darf gesperrt werden, die Erinnerung kommt als Mitteilung.")
                .foregroundStyle(.secondary)
            ClockView(since: r.t0)
            TimelineView(.periodic(from: .now, by: 1)) { context in
                Text(nextText(r, now: context.date))
                    .frame(maxWidth: .infinity)
            }
            SlotRow(run: r)
            if store.notificationsDenied {
                Text("Mitteilungen sind ausgeschaltet! Einstellungen › Messprotokoll › Mitteilungen einschalten, sonst kommt keine Erinnerung.")
                    .foregroundStyle(Color.red)
            }
            Text("Erst bewerten, dann Kurve ansehen. Während des Versuchs nicht in die CALERA-App schauen.")
                .font(.footnote)
            Text("Bei Schwindel oder Frösteln sofort abbrechen.").foregroundStyle(Color.orange)
            if r.allSlotsRated {
                Text("Fertig! Raumtemperatur am Ende messen und eintragen.").bold()
                labeled("Raumtemperatur Ende [°C]", "z. B. 11,8", \.roomTempEnd, keyboard: .decimalPad)
                Button("Durchlauf abschließen") {
                    if parseNumber(r.roomTempEnd) == nil { confirm = .finishWithoutTemp } else { store.finish(runId) }
                }
                .bold()
            }

        case .done:
            Label("Durchlauf abgeschlossen", systemImage: "checkmark.circle.fill").foregroundStyle(Color.green)
            Text("Zeitpunkt 0: \(dateTimeString(r.t0)). Sensor-CSV nach data/raw/ kopieren und den Dateinamen unten eintragen.")
                .font(.footnote)

        case .aborted:
            Text("Abgebrochen um \(timeString(r.abortedAt))" + (r.abortReason.isEmpty ? "" : ": " + r.abortReason))
                .foregroundStyle(Color.red)
            Text("Der Durchlauf bleibt gespeichert und wird beim Export als „aborted“ markiert.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }

        if r.isActive {
            Button("Versuch abbrechen", role: .destructive) {
                abortReason = ""
                showAbort = true
            }
        }
    }

    // MARK: Aktionen

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

    // MARK: Texte

    private func restText(_ r: Run) -> String {
        if let v = r.ratings["rest"] { return "Ruhe-Gefühl: \(ratingText(v))" }
        return "Ruhe-Gefühl noch nicht bewertet"
    }

    private func nextText(_ r: Run, now: Date) -> String {
        guard let t0 = r.t0 else { return "" }
        guard let next = ratingSlots.first(where: { r.ratings[String($0)] == nil }) else {
            return "Alle Bewertungen erledigt."
        }
        let remaining = t0 + Double(next) * 60000 - now.ms
        return remaining > 0
            ? "Nächste Bewertung (Min. \(next)) in \(durationString(remaining))"
            : "Bewertung Min. \(next) ist jetzt fällig!"
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

    private func labeled(_ label: String, _ placeholder: String, _ keyPath: WritableKeyPath<Run, String>,
                         keyboard: UIKeyboardType = .default) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.caption).foregroundStyle(.secondary)
            TextField(placeholder, text: text(keyPath))
                .keyboardType(keyboard)
        }
    }
}

// MARK: - Hilfsansichten

/// Laufende Uhr (mm:ss) seit einem Zeitpunkt
struct ClockView: View {
    let since: Double?

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            Text(durationString(context.date.ms - (since ?? context.date.ms)))
                .font(.system(size: 48, weight: .bold).monospacedDigit())
                .frame(maxWidth: .infinity)
        }
    }
}

/// Fünf Kästchen für 0, 5, 10, 15, 20 Min.: grün = bewertet, rot = fällig
struct SlotRow: View {
    let run: Run

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            HStack(spacing: 6) {
                ForEach(ratingSlots, id: \.self) { s in
                    SlotBox(minute: s,
                            rating: run.ratings[String(s)],
                            due: run.ratings[String(s)] == nil && context.date.ms - (run.t0 ?? 0) >= Double(s) * 60000)
                }
            }
        }
    }
}

struct SlotBox: View {
    let minute: Int
    let rating: Rating?
    let due: Bool

    private var borderColor: Color {
        if rating != nil { return Color.green }
        if due { return Color.red }
        return Color.secondary.opacity(0.4)
    }

    var body: some View {
        VStack(spacing: 2) {
            Text("\(minute) Min.").font(.caption)
            Text(rating == nil ? "·" : ratingText(rating)).font(.headline.monospacedDigit())
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .background(RoundedRectangle(cornerRadius: 8).stroke(borderColor, lineWidth: 1.5))
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
        HStack {
            Text(key == "rest" ? "Ruhe" : "\(key) Min.")
            Spacer()
            Text(rating?.skipped == true ? "nicht bewertet" : ratingText(rating))
                .bold()
                .monospacedDigit()
            Text(rating.map { timeString($0.time) } ?? "")
                .font(.footnote.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 72, alignment: .trailing)
            Text(delayText)
                .font(.footnote)
                .foregroundStyle(Color.orange)
                .frame(width: 52, alignment: .trailing)
        }
    }
}
