import Foundation

struct Preferences: Codable {
    var fileExtension: String = "txt"
    var fileNamePrefix: String = "Untitled"
    var terminalApp: String = "terminal" // "terminal", "antigravity", "vscode"
    
    static var configFileURL: URL {
        let username = NSUserName()
        let homeDir = URL(fileURLWithPath: "/Users").appendingPathComponent(username)
        return homeDir.appendingPathComponent(".finder_quick_actions.json")
    }
    
    static func load() -> Preferences {
        do {
            let data = try Data(contentsOf: configFileURL)
            let decoder = JSONDecoder()
            return try decoder.decode(Preferences.self, from: data)
        } catch {
            return Preferences()
        }
    }
    
    func save() {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(self)
            try data.write(to: Preferences.configFileURL, options: .atomic)
        } catch {
            NSLog("FinderQuickActions: Failed to save preferences: \(error.localizedDescription)")
        }
    }
}
