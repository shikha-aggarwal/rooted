//
//  Secrets.swift
//  Rooted
//
//  Loads API keys from Secrets.plist (gitignored).
//  To set up: copy Secrets.plist.template → Secrets.plist and add your keys.
//

import Foundation

enum Secrets {
    static var plantNetAPIKey: String { string(for: "PLANTNET_API_KEY") }
    static var claudeAPIKey:   String { string(for: "CLAUDE_API_KEY") }

    private static let dict: NSDictionary? = {
        guard let url = Bundle.main.url(forResource: "Secrets", withExtension: "plist") else { return nil }
        return NSDictionary(contentsOf: url)
    }()

    private static func string(for key: String) -> String {
        (dict?[key] as? String) ?? ""
    }
}
