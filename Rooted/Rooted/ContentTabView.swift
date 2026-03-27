//
//  ContentTabView.swift
//  Rooted
//
//  Shared four-tab content card used by Browse, Camera result, and Log detail.
//

import SwiftUI

struct ContentTabView: View {
    let content: SpeciesContent
    @State private var selectedTab = 0

    private let tabs: [(label: String, icon: String, keyPath: KeyPath<SpeciesContent, String>)] = [
        ("Features", "magnifyingglass", \.features),
        ("Uses",     "leaf",            \.uses),
        ("Folklore", "book",            \.folklore),
        ("Local",    "mappin",          \.localSignificance),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Tab selector
            HStack(spacing: 0) {
                ForEach(tabs.indices, id: \.self) { i in
                    Button {
                        selectedTab = i
                    } label: {
                        VStack(spacing: 3) {
                            Image(systemName: tabs[i].icon)
                                .font(.system(size: 14))
                            Text(tabs[i].label)
                                .font(.caption2)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .foregroundStyle(selectedTab == i ? .primary : .secondary)
                    }
                    .overlay(alignment: .bottom) {
                        if selectedTab == i {
                            Rectangle()
                                .frame(height: 2)
                                .foregroundStyle(Color.accentColor)
                        }
                    }
                }
            }
            .background(Color(.systemBackground))

            Divider()

            // Content
            Text(content[keyPath: tabs[selectedTab].keyPath])
                .font(.body)
                .lineSpacing(4)
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .animation(.none, value: selectedTab)
        }
    }
}
