//
//  Config.swift
//  Sierix
//
//  Created by Kirichok Lev on 11/15/26.
//  Copyright © 2026 SunflowerrSunflowerr. All rights reserved.
//

import Foundation

enum Config {
    static var geminiAPIKey: String? {
        guard let url = Bundle.main.url(forResource: "Config", withExtension: "plist"),
            let data = try? Data(contentsOf: url),
            let object = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil),
            let plist = object as? [String: Any],
            let key = plist["GeminiAPIKey"] as? String,
            !key.isEmpty else { return nil }
        return key
    }
}
