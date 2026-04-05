//
//  ContentView.swift
//  Rooted
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @State private var locationManager = LocationManager()

    var body: some View {
        TabView {
            Tab("Camera", systemImage: "camera.fill") {
                CameraView()
            }
            Tab("Browse", systemImage: "leaf.fill") {
                BrowseView()
            }
            Tab("Log", systemImage: "book.fill") {
                LogView()
            }
        }
        .task { locationManager.requestIfNeeded() }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [CachedSpeciesContent.self, LogEntry.self], inMemory: true)
}
