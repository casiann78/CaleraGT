import SwiftUI
import UserNotifications

/// Welche Bewertung gerade abgefragt wird. slot ist "rest" oder eine Minute ("0", "5", …)
struct RatingPrompt: Identifiable, Equatable {
    let runId: String
    let slot: String
    var id: String { runId + ":" + slot }
}

/// Dateien für das Teilen-Menü (Export)
struct ShareItems: Identifiable {
    let id = UUID()
    let urls: [URL]
}

/// Hält alle Durchläufe, speichert sie als JSON-Datei auf dem iPhone
/// und plant die Erinnerungen (lokale Mitteilungen).
final class Store: ObservableObject {
    @Published var runs: [Run] = []
    @Published var path: [String] = []
    @Published var ratingPrompt: RatingPrompt?
    @Published var notificationStatus: UNAuthorizationStatus = .notDetermined
    /// true, sobald der Status einmal abgefragt wurde (verhindert kurzes Aufblinken von Warnungen)
    @Published var notificationStatusKnown = false
    /// Hinweise, warum Erinnerungen evtl. nicht ankommen (z. B. Töne aus)
    @Published var notificationHints: [String] = []
    /// Anzahl geplanter Erinnerungen (ohne Test-Erinnerung)
    @Published var pendingReminderCount = 0

    var notificationsDenied: Bool { notificationStatus == .denied }
    @Published var saveError: String?

    private let fileURL: URL = FileManager.default
        .urls(for: .documentDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("protokoll.json")

    init() {
        load()
    }

    // MARK: Speichern und Laden

    func load() {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        do {
            runs = try JSONDecoder().decode(Backup.self, from: data).runs
        } catch {
            // Defekte Datei nicht überschreiben, sondern beiseitelegen
            let broken = fileURL.deletingLastPathComponent()
                .appendingPathComponent("protokoll-defekt-\(Int(Date().timeIntervalSince1970)).json")
            try? FileManager.default.copyItem(at: fileURL, to: broken)
            saveError = "Gespeicherte Daten konnten nicht gelesen werden. Eine Kopie liegt unter \(broken.lastPathComponent)."
        }
    }

    func save() {
        do {
            let data = try JSONEncoder().encode(Backup(runs: runs))
            try data.write(to: fileURL, options: .atomic)
            saveError = nil
        } catch {
            saveError = "Speichern fehlgeschlagen: \(error.localizedDescription)"
        }
    }

    // MARK: Abfragen

    func run(_ id: String) -> Run? {
        runs.first { $0.id == id }
    }

    func update(_ id: String, _ change: (inout Run) -> Void) {
        guard let i = runs.firstIndex(where: { $0.id == id }) else { return }
        change(&runs[i])
        save()
    }

    var recoveryRun: Run? {
        runs.first { $0.phase == .recovery }
    }

    func runsFor(_ c: Condition) -> [Run] {
        runs.filter { $0.condition == c }
            .sorted { (Int($0.runNo) ?? 0) < (Int($1.runNo) ?? 0) }
    }

    func completedCount(_ c: Condition) -> Int {
        runs.filter { $0.condition == c && $0.finished && !$0.aborted }.count
    }

    // MARK: Ablauf eines Versuchs

    func newRun(_ c: Condition) {
        let nextNo = (runs.filter { $0.condition == c }.map { Int($0.runNo) ?? 0 }.max() ?? 0) + 1
        let last = runs.max { $0.createdAt < $1.createdAt }
        let now = Date().ms
        let id = String(Int(now), radix: 36) + String(UUID().uuidString.prefix(5)).lowercased()
        var r = Run(id: id, condition: c, runNo: String(nextNo), date: Fmt.day.string(from: Date()), createdAt: now)
        // Training und Kleidung vom letzten Durchlauf übernehmen (immer gleiche Bedingungen)
        r.training = last?.training ?? ""
        r.clothing = last?.clothing ?? ""
        runs.append(r)
        save()
        path = [id]
    }

    func startRest(_ id: String) {
        update(id) { $0.restStart = Date().ms }
    }

    func endRest(_ id: String) {
        update(id) { $0.restEnd = Date().ms }
        if run(id)?.ratings["rest"] == nil {
            ratingPrompt = RatingPrompt(runId: id, slot: "rest")
        }
    }

    func startSport(_ id: String) {
        update(id) { $0.sportStart = Date().ms }
    }

    func endSport(_ id: String) {
        update(id) { $0.sportEnd = Date().ms }
    }

    /// Zeitpunkt 0: Erholung beginnt, Erinnerungen werden geplant
    func confirmT0(_ id: String) {
        update(id) { $0.t0 = Date().ms }
        if let r = run(id) { scheduleReminders(r) }
        ratingPrompt = RatingPrompt(runId: id, slot: "0")
    }

    func storeRating(_ p: RatingPrompt, value: Int?, skipped: Bool) {
        let now = Date().ms
        update(p.runId) { r in
            var entry = Rating(value: skipped ? nil : value, time: now, skipped: skipped ? true : nil, delayS: nil)
            if p.slot != "rest", let t0 = r.t0, let minute = Int(p.slot) {
                entry.delayS = Int(((now - (t0 + Double(minute) * 60000)) / 1000).rounded())
            }
            r.ratings[p.slot] = entry
        }
        cancelReminders(runId: p.runId, slots: [p.slot])
        if ratingPrompt == p { ratingPrompt = nil }
    }

    func finish(_ id: String) {
        update(id) { $0.finished = true }
        cancelReminders(runId: id, slots: ratingSlots.map { String($0) })
    }

    func abort(_ id: String, reason: String) {
        update(id) {
            $0.aborted = true
            $0.abortReason = reason
            $0.abortedAt = Date().ms
        }
        cancelReminders(runId: id, slots: ratingSlots.map { String($0) })
        if ratingPrompt?.runId == id { ratingPrompt = nil }
    }

    func delete(_ id: String) {
        cancelReminders(runId: id, slots: ratingSlots.map { String($0) })
        runs.removeAll { $0.id == id }
        save()
        path = []
    }

    /// Wird jede Sekunde aufgerufen: fällige Bewertung als Vollbild öffnen
    func checkDue() {
        guard ratingPrompt == nil, let r = recoveryRun, let t0 = r.t0 else { return }
        let elapsed = Date().ms - t0
        if let s = ratingSlots.first(where: { r.ratings[String($0)] == nil && elapsed >= Double($0) * 60000 }) {
            if path.last != r.id { path = [r.id] }
            ratingPrompt = RatingPrompt(runId: r.id, slot: String(s))
        }
    }

    func becameActive() {
        refreshNotificationStatus()
        if let r = recoveryRun { scheduleReminders(r) }
        checkDue()
    }

    // MARK: Mitteilungen (kommen auch bei gesperrtem Bildschirm)

    func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in
            self.refreshNotificationStatus()
        }
    }

    func refreshNotificationStatus() {
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { settings in
            let status = settings.authorizationStatus
            var hints: [String] = []
            if status == .authorized || status == .provisional {
                if settings.lockScreenSetting == .disabled { hints.append("Auf dem Sperrbildschirm ausgeschaltet.") }
                if settings.alertSetting == .disabled { hints.append("Banner sind ausgeschaltet.") }
                if settings.soundSetting == .disabled { hints.append("Töne sind ausgeschaltet.") }
                if settings.scheduledDeliverySetting == .enabled {
                    hints.append("Zustellung steht auf „Geplante Zusammenfassung“. Bitte auf „Sofortige Zustellung“ stellen.")
                }
            }
            if status == .provisional { hints.append("Mitteilungen kommen nur leise in die Mitteilungszentrale.") }
            center.getPendingNotificationRequests { requests in
                let count = requests.filter { $0.identifier != "test" }.count
                DispatchQueue.main.async {
                    self.notificationStatus = status
                    self.notificationStatusKnown = true
                    self.notificationHints = hints
                    self.pendingReminderCount = count
                }
            }
        }
    }

    /// Einzelne Erinnerung in 10 Sekunden, um Mitteilungen zu prüfen
    func sendTestNotification() {
        let content = UNMutableNotificationContent()
        content.title = "Test-Erinnerung"
        content.body = "Wenn du das siehst und hörst, funktionieren die Erinnerungen."
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 10, repeats: false)
        let request = UNNotificationRequest(identifier: "test", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }

    private func reminderIds(runId: String, slot: String) -> [String] {
        (0..<3).map { "\(runId)-\(slot)-\($0)" }
    }

    /// Pro Bewertungszeitpunkt eine Erinnerung plus zwei Nachfass-Erinnerungen
    /// (1 und 2 Minuten später), falls noch nicht bewertet wurde.
    func scheduleReminders(_ r: Run) {
        guard let t0 = r.t0 else { return }
        let center = UNUserNotificationCenter.current()
        for s in ratingSlots where s > 0 && r.ratings[String(s)] == nil {
            for k in 0..<3 {
                let fire = Date(ms: t0).addingTimeInterval(Double(s * 60 + k * 60))
                let interval = fire.timeIntervalSinceNow
                if interval < 1 { continue }
                let content = UNMutableNotificationContent()
                content.title = k == 0 ? "Bewertung: Minute \(s)" : "Noch nicht bewertet: Minute \(s)"
                content.body = ratingQuestion
                content.sound = .default
                content.userInfo = ["runId": r.id, "slot": String(s)]
                let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
                let request = UNNotificationRequest(identifier: "\(r.id)-\(s)-\(k)", content: content, trigger: trigger)
                center.add(request, withCompletionHandler: nil)
            }
        }
        // Anzeige der geplanten Erinnerungen aktualisieren
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { self.refreshNotificationStatus() }
    }

    func cancelReminders(runId: String, slots: [String]) {
        let ids = slots.flatMap { reminderIds(runId: runId, slot: $0) }
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ids)
        center.removeDeliveredNotifications(withIdentifiers: ids)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { self.refreshNotificationStatus() }
    }

    // MARK: Export (CSV wie in der Web-App)

    private func csvCell(_ v: String) -> String {
        if v.contains(",") || v.contains("\"") || v.contains("\n") || v.contains("\r") {
            return "\"" + v.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }
        return v
    }

    private func csv(_ header: [String], _ rows: [[String]]) -> String {
        ([header] + rows).map { $0.map { cell in self.csvCell(cell) }.joined(separator: ",") }.joined(separator: "\n") + "\n"
    }

    /// Zahl einheitlich mit Punkt exportieren. Ist die Eingabe keine Zahl,
    /// wird der Originaltext exportiert (nie stillschweigend leer).
    private func numberText(_ s: String) -> String {
        guard let d = parseNumber(s) else { return s.trimmingCharacters(in: .whitespaces) }
        if d == d.rounded() && abs(d) < 1e9 { return String(Int(d)) }
        return String(d)
    }

    private func optInt(_ v: Int?) -> String {
        v.map { String($0) } ?? ""
    }

    private var sortedRuns: [Run] {
        let order = Condition.allCases.map { $0.rawValue }
        return runs.sorted {
            let a = order.firstIndex(of: $0.condition.rawValue) ?? 0
            let b = order.firstIndex(of: $1.condition.rawValue) ?? 0
            if a != b { return a < b }
            return (Int($0.runNo) ?? 0) < (Int($1.runNo) ?? 0)
        }
    }

    func runsCSV() -> String {
        let header: [String] = ["condition", "run_no", "date", "room_temp_start_c", "room_temp_end_c", "humidity_pct", "training",
                      "clothing", "location", "sensor_file", "rest_start", "rest_end", "sport_start", "sport_end", "t0",
                      "feel_rest"] + ratingSlots.map { "feel_\($0)" } +
                     ["status", "abort_reason", "outlier", "outlier_reason", "notes"]
        let rows: [[String]] = sortedRuns.map { r in
            var row: [String] = [r.condition.rawValue, r.runNo, r.date, numberText(r.roomTempStart), numberText(r.roomTempEnd),
                       numberText(r.humidity), r.training, r.clothing, r.location, r.sensorFile,
                       dateTimeString(r.restStart), dateTimeString(r.restEnd), dateTimeString(r.sportStart),
                       dateTimeString(r.sportEnd), dateTimeString(r.t0), optInt(r.ratings["rest"]?.value)]
            row += ratingSlots.map { optInt(r.ratings[String($0)]?.value) }
            row += [r.status, r.abortReason, r.outlier ? "1" : "0", r.outlierReason, r.notes]
            return row
        }
        return csv(header, rows)
    }

    func ratingsCSV() -> String {
        let header: [String] = ["condition", "run_no", "date", "minute", "feel", "rated_at", "delay_s", "skipped", "status", "outlier"]
        var rows: [[String]] = []
        for r in sortedRuns {
            for key in ["rest"] + ratingSlots.map({ String($0) }) {
                guard let v = r.ratings[key] else { continue }
                rows.append([r.condition.rawValue, r.runNo, r.date, key, optInt(v.value), dateTimeString(v.time),
                             optInt(v.delayS), v.skipped == true ? "1" : "0", r.status, r.outlier ? "1" : "0"])
            }
        }
        return csv(header, rows)
    }

    /// Schreibt CSV-Dateien und Sicherung in einen temporären Ordner für das Teilen-Menü
    func exportFiles() -> ShareItems? {
        let day = Fmt.day.string(from: Date())
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("export", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            let runsURL = dir.appendingPathComponent("protokoll_durchlaeufe_\(day).csv")
            let ratingsURL = dir.appendingPathComponent("protokoll_gefuehlswerte_\(day).csv")
            let backupURL = dir.appendingPathComponent("protokoll_sicherung_\(day).json")
            try runsCSV().write(to: runsURL, atomically: true, encoding: .utf8)
            try ratingsCSV().write(to: ratingsURL, atomically: true, encoding: .utf8)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(Backup(runs: runs)).write(to: backupURL, options: .atomic)
            return ShareItems(urls: [runsURL, ratingsURL, backupURL])
        } catch {
            saveError = "Export fehlgeschlagen: \(error.localizedDescription)"
            return nil
        }
    }

    /// JSON-Sicherung laden (auch aus der Web-App). Vorhandene Durchläufe werden nicht überschrieben.
    func importBackup(_ result: Result<URL, Error>) -> String {
        switch result {
        case .failure(let error):
            return "Datei konnte nicht geöffnet werden: \(error.localizedDescription)"
        case .success(let url):
            let access = url.startAccessingSecurityScopedResource()
            defer { if access { url.stopAccessingSecurityScopedResource() } }
            do {
                let data = try Data(contentsOf: url)
                let backup = try JSONDecoder().decode(Backup.self, from: data)
                var added = 0
                for r in backup.runs where run(r.id) == nil {
                    runs.append(r)
                    added += 1
                }
                save()
                if let r = recoveryRun { scheduleReminders(r) }
                return "\(added) Durchläufe hinzugefügt (bereits vorhandene übersprungen)."
            } catch {
                return "Datei konnte nicht gelesen werden: \(error.localizedDescription)"
            }
        }
    }
}
