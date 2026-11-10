import SwiftUI

// MARK: - Konstanten (gleich wie in der Web-App app/index.html)

/// Bewertungszeitpunkte in Minuten nach Zeitpunkt 0
let ratingSlots = [0, 5, 10, 15, 20]
/// Mindestanzahl Durchläufe pro Bedingung
let targetRuns = 3
let ratingQuestion = "Wie warm oder kalt fühlt sich mein ganzer Körper gerade an?"

struct FeelingOption: Identifiable {
    let value: Int
    let label: String
    var id: Int { value }
}

let feelingScale: [FeelingOption] = [
    FeelingOption(value: 3, label: "sehr heiß"),
    FeelingOption(value: 2, label: "warm"),
    FeelingOption(value: 1, label: "etwas warm"),
    FeelingOption(value: 0, label: "neutral"),
    FeelingOption(value: -1, label: "etwas kalt"),
    FeelingOption(value: -2, label: "kalt"),
    FeelingOption(value: -3, label: "sehr kalt"),
]

// MARK: - Bedingungen

enum Condition: String, Codable, CaseIterable, Identifiable {
    case kalt, angenehm, warm

    var id: String { rawValue }

    var label: String {
        switch self {
        case .kalt: return "Kalt"
        case .angenehm: return "Angenehm"
        case .warm: return "Warm"
        }
    }

    var target: String {
        switch self {
        case .kalt: return "10–12 °C"
        case .angenehm: return "21–22 °C"
        case .warm: return "25–28 °C"
        }
    }

    var minTemp: Double {
        switch self {
        case .kalt: return 10
        case .angenehm: return 21
        case .warm: return 25
        }
    }

    var maxTemp: Double {
        switch self {
        case .kalt: return 12
        case .angenehm: return 22
        case .warm: return 28
        }
    }

    /// Gleiche Farben wie in allen Diagrammen: Kalt = blau, Angenehm = grün, Warm = rot
    var color: Color {
        switch self {
        case .kalt: return Color.blue
        case .angenehm: return Color.green
        case .warm: return Color.red
        }
    }
}

enum Phase {
    case setup, rest, afterRest, sport, ready, recovery, done, aborted
}

// MARK: - Datenmodell
// Zeiten werden wie in der Web-App als Millisekunden seit 1970 gespeichert,
// damit JSON-Sicherungen zwischen Web-App und iOS-App austauschbar sind.

struct Rating: Codable, Equatable {
    var value: Int?
    var time: Double
    var skipped: Bool?
    var delayS: Int?

    enum CodingKeys: String, CodingKey {
        case value, time, skipped
        case delayS = "delay_s"
    }
}

struct Run: Codable, Identifiable, Equatable {
    var id: String
    var condition: Condition
    var runNo: String
    var date: String
    var roomTempStart: String = ""
    var roomTempEnd: String = ""
    var humidity: String = ""
    var training: String = ""
    var clothing: String = ""
    var location: String = ""
    var sensorFile: String = ""
    var notes: String = ""
    var outlier: Bool = false
    var outlierReason: String = ""
    var restStart: Double? = nil
    var restEnd: Double? = nil
    var sportStart: Double? = nil
    var sportEnd: Double? = nil
    var t0: Double? = nil
    /// Schlüssel: "rest", "0", "5", "10", "15", "20"
    var ratings: [String: Rating] = [:]
    var finished: Bool = false
    var aborted: Bool = false
    var abortReason: String = ""
    var abortedAt: Double? = nil
    var createdAt: Double

    enum CodingKeys: String, CodingKey {
        case id, condition, runNo, date, roomTempStart, roomTempEnd, humidity, training, clothing,
             location, sensorFile, notes, outlier, outlierReason, restStart, restEnd, sportStart,
             sportEnd, t0, ratings, finished, aborted, abortReason, abortedAt, createdAt
    }

    var phase: Phase {
        if aborted { return .aborted }
        if finished { return .done }
        if t0 != nil { return .recovery }
        if sportStart != nil && sportEnd == nil { return .sport }
        if sportEnd != nil { return .ready }
        if restStart != nil && restEnd == nil { return .rest }
        if restEnd != nil { return .afterRest }
        return .setup
    }

    var isActive: Bool {
        [Phase.rest, .afterRest, .sport, .ready, .recovery].contains(phase)
    }

    var status: String {
        if aborted { return "aborted" }
        if finished { return "done" }
        return "incomplete"
    }

    var allSlotsRated: Bool {
        ratingSlots.allSatisfy { ratings[String($0)] != nil }
    }
}

extension Run {
    /// Tolerantes Einlesen: die Web-App speichert manche Felder als Zahl oder Text.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        condition = try c.decode(Condition.self, forKey: .condition)
        runNo = Run.flexString(c, .runNo)
        date = Run.flexString(c, .date)
        roomTempStart = Run.flexString(c, .roomTempStart)
        roomTempEnd = Run.flexString(c, .roomTempEnd)
        humidity = Run.flexString(c, .humidity)
        training = Run.flexString(c, .training)
        clothing = Run.flexString(c, .clothing)
        location = Run.flexString(c, .location)
        sensorFile = Run.flexString(c, .sensorFile)
        notes = Run.flexString(c, .notes)
        outlier = (try? c.decodeIfPresent(Bool.self, forKey: .outlier)) ?? false
        outlierReason = Run.flexString(c, .outlierReason)
        restStart = try? c.decodeIfPresent(Double.self, forKey: .restStart)
        restEnd = try? c.decodeIfPresent(Double.self, forKey: .restEnd)
        sportStart = try? c.decodeIfPresent(Double.self, forKey: .sportStart)
        sportEnd = try? c.decodeIfPresent(Double.self, forKey: .sportEnd)
        t0 = try? c.decodeIfPresent(Double.self, forKey: .t0)
        ratings = (try? c.decodeIfPresent([String: Rating].self, forKey: .ratings)) ?? [:]
        finished = (try? c.decodeIfPresent(Bool.self, forKey: .finished)) ?? false
        aborted = (try? c.decodeIfPresent(Bool.self, forKey: .aborted)) ?? false
        abortReason = Run.flexString(c, .abortReason)
        abortedAt = try? c.decodeIfPresent(Double.self, forKey: .abortedAt)
        createdAt = (try? c.decodeIfPresent(Double.self, forKey: .createdAt)) ?? Date().ms
    }

    private static func flexString(_ c: KeyedDecodingContainer<CodingKeys>, _ key: CodingKeys) -> String {
        if let s = try? c.decodeIfPresent(String.self, forKey: key) { return s }
        if let i = try? c.decodeIfPresent(Int.self, forKey: key) { return String(i) }
        if let d = try? c.decodeIfPresent(Double.self, forKey: key) { return String(d) }
        return ""
    }
}

/// Format der JSON-Sicherung (gleich wie in der Web-App)
struct Backup: Codable {
    var runs: [Run]
}

// MARK: - Hilfsfunktionen

extension Date {
    var ms: Double { timeIntervalSince1970 * 1000 }
    init(ms: Double) { self.init(timeIntervalSince1970: ms / 1000) }
}

enum Fmt {
    static func make(_ format: String) -> DateFormatter {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = format
        return f
    }
    static let time = make("HH:mm:ss")
    static let dateTime = make("yyyy-MM-dd HH:mm:ss")
    static let day = make("yyyy-MM-dd")
}

func timeString(_ ms: Double?) -> String {
    guard let ms = ms else { return "" }
    return Fmt.time.string(from: Date(ms: ms))
}

func dateTimeString(_ ms: Double?) -> String {
    guard let ms = ms else { return "" }
    return Fmt.dateTime.string(from: Date(ms: ms))
}

func durationString(_ ms: Double) -> String {
    let s = max(0, Int(ms / 1000))
    return String(format: "%02d:%02d", s / 60, s % 60)
}

func signedText(_ v: Int?) -> String {
    guard let v = v else { return "–" }
    return v > 0 ? "+\(v)" : "\(v)"
}

/// Zahl aus Texteingabe lesen, Komma oder Punkt als Dezimalzeichen
func parseNumber(_ s: String) -> Double? {
    Double(s.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: "."))
}

func ratingText(_ r: Rating?) -> String {
    guard let r = r else { return "–" }
    if r.skipped == true { return "×" }
    return signedText(r.value)
}

struct Warning: Hashable {
    let text: String
    let danger: Bool
}

func warnings(for r: Run) -> [Warning] {
    var out: [Warning] = []
    for (value, name) in [(r.roomTempStart, "Start"), (r.roomTempEnd, "Ende")] {
        guard let t = parseNumber(value) else { continue }
        if t < 8 || t > 30 {
            out.append(Warning(text: "Raumtemperatur \(name) \(value) °C: Sicherheitsgrenze (8–30 °C) überschritten! Versuch so nicht durchführen.", danger: true))
        } else if t < r.condition.minTemp - 1 || t > r.condition.maxTemp + 1 {
            out.append(Warning(text: "Raumtemperatur \(name) \(value) °C liegt außerhalb des Zielbereichs \(r.condition.target). Trotzdem den tatsächlichen Wert notieren.", danger: false))
        }
    }
    if let h = parseNumber(r.humidity), h < 0 || h > 100 {
        out.append(Warning(text: "Luftfeuchte muss zwischen 0 und 100 % liegen.", danger: false))
    }
    if r.condition == .warm {
        out.append(Warning(text: "Warm selbst erzeugen (Heizung/Heizlüfter oder Auto mit Heizung). Keine Sauna, heiße Dusche oder Dampf. Tatsächlich gemessene Temperatur notieren.", danger: false))
    }
    return out
}

// MARK: - Darstellung

extension Condition {
    /// SF-Symbol für die Bedingung
    var icon: String {
        switch self {
        case .kalt: return "snowflake"
        case .angenehm: return "leaf.fill"
        case .warm: return "flame.fill"
        }
    }
}

struct FeelingPoint: Identifiable {
    let minute: Int
    let value: Int
    var id: Int { minute }
}

extension Run {
    var phaseTitle: String {
        switch phase {
        case .setup: return "Vorbereitung"
        case .rest: return "Ruhemessung läuft"
        case .afterRest: return "Bereit für den Sport"
        case .sport: return "Sport läuft"
        case .ready: return "Ab in den Messbereich"
        case .recovery: return "Erholung läuft"
        case .done: return "Abgeschlossen"
        case .aborted: return "Abgebrochen"
        }
    }

    /// Schritt in der Anzeige: 0 Ruhe, 1 Sport, 2 Erholung, 3 Fertig (4 = alles erledigt)
    var stepIndex: Int {
        switch phase {
        case .setup, .rest: return 0
        case .afterRest, .sport: return 1
        case .ready, .recovery: return 2
        case .done: return 4
        case .aborted: return 0
        }
    }

    /// Bewertete Zeitpunkte nach Zeitpunkt 0 (ohne Ruhe, ohne übersprungene)
    var feelingPoints: [FeelingPoint] {
        ratingSlots.compactMap { s -> FeelingPoint? in
            guard let v = ratings[String(s)]?.value else { return nil }
            return FeelingPoint(minute: s, value: v)
        }
    }

    var displayDate: String {
        guard let d = Fmt.day.date(from: date) else { return date }
        return Fmt.german.string(from: d)
    }
}

extension Fmt {
    static let german: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "de_DE")
        f.dateFormat = "EE, d. MMM yyyy"
        return f
    }()
}

/// Farbe für einen Gefühlswert: −3 dunkelblau … 0 grau … +3 rot
func feelingColor(_ v: Int?) -> Color {
    guard let v = v else { return Color.secondary.opacity(0.25) }
    switch v {
    case ...(-3): return Color.indigo
    case -2: return Color.blue
    case -1: return Color.teal
    case 0: return Color.gray
    case 1: return Color.orange
    case 2: return Color(red: 0.93, green: 0.36, blue: 0.2)
    default: return Color.red
    }
}
