//
//  Secrets.swift
//  Rooted
//
//  Loads API keys from Secrets.plist (gitignored).
//  To set up: copy Secrets.plist.template → Secrets.plist and add your keys.
//

import Foundation

enum Secrets {
    static var claudeAPIKey: String {
        guard
            let url = Bundle.main.url(forResource: "Secrets", withExtension: "plist"),
            let dict = NSDictionary(contentsOf: url),
            let key = dict["CLAUDE_API_KEY"] as? String,
            !key.isEmpty
        else {
            return ""
        }
        return key
    }
}
