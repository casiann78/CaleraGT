import SwiftUI

/// Vollbild-Abfrage des Gefühlswerts (−3 bis +3), immer mit derselben Frage
struct RatingView: View {
    @EnvironmentObject var store: Store
    let prompt: RatingPrompt
    @State private var confirmSkip = false

    private var isRest: Bool { prompt.slot == "rest" }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                Text(isRest ? "Bewertung in Ruhe" : "Bewertung: Minute \(prompt.slot)")
                    .font(.largeTitle.bold())
                    .multilineTextAlignment(.center)
                    .padding(.top, 12)
                Text("„\(ratingQuestion)“")
                    .font(.title3.weight(.semibold))
                    .multilineTextAlignment(.center)
                Text("Ehrlich und spontan antworten. Nicht vorher in die CALERA-App schauen.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                if !isRest {
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        Text(lateText(now: context.date))
                            .font(.headline)
                            .foregroundStyle(Color.red)
                    }
                }

                ForEach(feelingScale) { option in
                    Button {
                        store.storeRating(prompt, value: option.value, skipped: false)
                    } label: {
                        HStack {
                            Text(signedText(option.value))
                                .font(.title2.bold().monospacedDigit())
                                .frame(width: 56, alignment: .leading)
                            Spacer()
                            Text(option.label).font(.title3)
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 6)
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }

                if isRest {
                    Button("Schließen") { store.ratingPrompt = nil }
                        .padding(.top, 8)
                } else {
                    Button("Nicht bewertet (überspringen)", role: .destructive) { confirmSkip = true }
                        .padding(.top, 8)
                }
            }
            .padding()
        }
        .onAppear {
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
        }
        .confirmationDialog("Diesen Zeitpunkt als „nicht bewertet“ speichern? Das lässt sich nicht rückgängig machen.",
                            isPresented: $confirmSkip, titleVisibility: .visible) {
            Button("Als nicht bewertet speichern", role: .destructive) {
                store.storeRating(prompt, value: nil, skipped: true)
            }
            Button("Zurück", role: .cancel) {}
        }
    }

    private func lateText(now: Date) -> String {
        guard let run = store.run(prompt.runId), let t0 = run.t0, let minute = Int(prompt.slot) else { return "" }
        let late = now.ms - (t0 + Double(minute) * 60000)
        return late > 15000 ? "Fällig seit \(durationString(late)) – bitte jetzt bewerten." : " "
    }
}
