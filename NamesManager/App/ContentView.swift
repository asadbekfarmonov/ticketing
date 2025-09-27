import SwiftUI

struct ContentView: View {
    @StateObject private var importViewModel = ImportViewModel()
    @EnvironmentObject private var namesStore: NamesStore

    var body: some View {
        TabView {
            NavigationStack {
                ImportView()
                    .environmentObject(importViewModel)
                    .environmentObject(namesStore)
                    .navigationTitle("Import")
            }
            .tabItem {
                Label("Import", systemImage: "tray.and.arrow.down")
            }

            NavigationStack {
                NamesListView()
                    .environmentObject(namesStore)
                    .navigationTitle("Names")
            }
            .tabItem {
                Label("Names", systemImage: "person.3")
            }

            NavigationStack {
                DuplicatesView()
                    .environmentObject(namesStore)
                    .navigationTitle("Duplicates")
            }
            .tabItem {
                Label("Duplicates", systemImage: "rectangle.on.rectangle")
            }

            NavigationStack {
                StatsView()
                    .environmentObject(namesStore)
                    .navigationTitle("Stats")
            }
            .tabItem {
                Label("Stats", systemImage: "chart.bar")
            }
        }
        .task {
            namesStore.refreshFromStore()
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(NamesStore(persistence: PersistenceController.preview()))
}
