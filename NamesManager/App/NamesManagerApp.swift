import SwiftUI

@main
struct NamesManagerApp: App {
    @StateObject private var namesStore = NamesStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(namesStore)
                .environment(\.managedObjectContext, namesStore.persistence.container.viewContext)
        }
    }
}
