//
//  ContentView.swift
//  Rooted
//

import SwiftUI
import SwiftData

struct ContentView: View {
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
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [CachedSpeciesContent.self, LogEntry.self], inMemory: true)
}
