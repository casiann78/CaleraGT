import SwiftUI

/// Vollbild-Abfrage des Gefühlswerts (−3 bis +3), immer mit derselben Frage
struct RatingView: View {
    @EnvironmentObject var store: Store
    let prompt: RatingPrompt
    @State private var confirmSkip = false

    private var isRest: Bool { prompt.slot == "rest" }

    private var conditionColor: Color {
        store.run(prompt.runId)?.condition.color ?? Color.accentColor
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                header

                if !isRest {
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        let late = lateText(now: context.date)
                        if !late.isEmpty {
                            BannerView(icon: "clock.badge.exclamationmark", text: late, color: Color.red)
                        }
                    }
                }

                VStack(spacing: 10) {
                    ForEach(feelingScale) { option in
                        Button {
                            store.storeRating(prompt, value: option.value, skipped: false)
                        } label: {
                            HStack {
                                Text(signedText(option.value))
                                    .font(.system(size: 28, weight: .bold, design: .rounded).monospacedDigit())
                                    .frame(width: 64, alignment: .leading)
                                Text(option.label)
                                    .font(.title3.weight(.semibold))
                                Spacer()
                            }
                            .foregroundStyle(Color.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 14)
                            .frame(maxWidth: .infinity)
                            .background(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(feelingColor(option.value).gradient)
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(signedText(option.value)), \(option.label)")
                    }
                }

                if isRest {
                    Button("Später bewerten") { store.ratingPrompt = nil }
                        .padding(.top, 4)
                } else {
                    Button("Nicht bewertet (überspringen)", role: .destructive) { confirmSkip = true }
                        .font(.subheadline)
                        .padding(.top, 4)
                }
            }
            .padding()
        }
        .background(Color(uiColor: .systemGroupedBackground))
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

    private var header: some View {
        VStack(spacing: 10) {
            Text(isRest ? "In Ruhe" : "Minute \(prompt.slot)")
                .font(.subheadline.bold())
                .foregroundStyle(Color.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(Capsule().fill(conditionColor))
            Text(ratingQuestion)
                .font(.title2.bold())
                .multilineTextAlignment(.center)
            Text("Spontan antworten. Nicht vorher in die CALERA-App schauen.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 20)
    }

    private func lateText(now: Date) -> String {
        guard let run = store.run(prompt.runId), let t0 = run.t0, let minute = Int(prompt.slot) else { return "" }
        let late = now.ms - (t0 + Double(minute) * 60000)
        return late > 15000 ? "Fällig seit \(durationString(late)). Bitte jetzt bewerten." : ""
    }
}
