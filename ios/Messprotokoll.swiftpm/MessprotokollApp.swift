import SwiftUI
import UserNotifications

@main
struct MessprotokollApp: App {
    @StateObject private var store = Store()
    private let notificationDelegate: NotificationDelegate

    init() {
        // Früh setzen, damit Mitteilungen auch bei geöffneter App angezeigt werden
        let delegate = NotificationDelegate()
        UNUserNotificationCenter.current().delegate = delegate
        notificationDelegate = delegate
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
        }
    }
}

/// Zeigt Mitteilungen auch an, wenn die App gerade offen ist (mit Ton).
/// Tippt man auf eine Mitteilung, öffnet sich die App; die fällige Bewertung
/// erscheint dann automatisch (Store.checkDue).
final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound, .list])
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        completionHandler()
    }
}

struct ContentView: View {
    @EnvironmentObject var store: Store
    @Environment(\.scenePhase) private var scenePhase
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        NavigationStack(path: $store.path) {
            HomeView()
                .navigationDestination(for: String.self) { id in
                    RunView(runId: id)
                }
        }
        .fullScreenCover(item: $store.ratingPrompt) { prompt in
            RatingView(prompt: prompt)
                .environmentObject(store)
        }
        .onReceive(timer) { _ in
            store.checkDue()
        }
        .onChange(of: scenePhase) { newPhase in
            if newPhase == .active { store.becameActive() }
        }
        .onAppear {
            store.requestNotificationPermission()
            store.becameActive()
        }
    }
}
