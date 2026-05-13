import SwiftUI
import SwiftData

@main
struct BookManagerApp: App {
    @StateObject private var localization = LocalizationManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(localization)
        }
        .modelContainer(for: Book.self)
    }
}
