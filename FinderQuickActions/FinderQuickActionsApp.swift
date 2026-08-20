import SwiftUI
import AppKit
import os.log

let logger = OSLog(subsystem: "com.yourcompany.FinderQuickActions", category: "HostApp")

class BackgroundService: NSObject {
    static let shared = BackgroundService()
    private var settingsWindow: NSWindow? = nil
    private var statusItem: NSStatusItem?
    
    private override init() {
        super.init()
    }
    
    func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "slider.horizontal.3", accessibilityDescription: nil)
            button.action = #selector(statusItemClicked)
            button.target = self
        }
    }
    
    @objc private func statusItemClicked() {
        showSettings()
    }
    
    private func getSharedPendingFileURL() -> URL {
        let username = NSUserName()
        let homeDir = URL(fileURLWithPath: "/Users").appendingPathComponent(username)
        let containerDir = homeDir
            .appendingPathComponent("Library")
            .appendingPathComponent("Containers")
            .appendingPathComponent("com.yourcompany.FinderQuickActions.Extension")
            .appendingPathComponent("Data")
            .appendingPathComponent("tmp")
        try? FileManager.default.createDirectory(at: containerDir, withIntermediateDirectories: true, attributes: nil)
        return containerDir.appendingPathComponent("pending.json")
    }
    
    func start() {
        os_log("FinderQuickActions Host App: Starting background service...", log: logger, type: .default)
        
        let pendingFileURL = getSharedPendingFileURL()
        if FileManager.default.fileExists(atPath: pendingFileURL.path) {
            try? FileManager.default.removeItem(at: pendingFileURL)
        }
        
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(handleActionNotification(_:)),
            name: NSNotification.Name("com.yourcompany.FinderQuickActions.trigger"),
            object: nil,
            suspensionBehavior: .deliverImmediately
        )
    }
    
    deinit {
        DistributedNotificationCenter.default().removeObserver(self)
    }
    
    func showSettings() {
        if settingsWindow == nil {
            let controller = NSHostingController(rootView: SettingsView())
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 450, height: 450),
                styleMask: [.titled, .closable, .miniaturizable],
                backing: .buffered,
                defer: false
            )
            window.contentViewController = controller
            window.title = "FinderQuickActions Preferences"
            window.center()
            window.isReleasedWhenClosed = false
            settingsWindow = window
        }
        
        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    @objc private func handleActionNotification(_ notification: Notification) {
        os_log("FinderQuickActions Host App: Received distributed notification!", log: logger, type: .default)
        
        let pendingFileURL = getSharedPendingFileURL()
        
        guard let data = try? Data(contentsOf: pendingFileURL),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: String],
              let action = json["action"],
              let path = json["path"] else {
            os_log("FinderQuickActions Host App: Failed to read pending action data from %{public}@", log: logger, type: .error, pendingFileURL.path)
            return
        }
        
        os_log("FinderQuickActions Host App: Executing action %{public}@ for path %{public}@", log: logger, type: .default, action, path)
        
        try? FileManager.default.removeItem(at: pendingFileURL)
        
        let targetURL = URL(fileURLWithPath: path)
        
        switch action {
        case "new_file":
            createNewFile(in: targetURL)
        case "open_terminal":
            openTerminal(for: targetURL)
        default:
            os_log("FinderQuickActions Host App: Unknown action %{public}@", log: logger, type: .error, action)
        }
    }
    
    private func createNewFile(in directoryURL: URL) {
        let fileManager = FileManager.default
        
        var isDir: ObjCBool = false
        guard fileManager.fileExists(atPath: directoryURL.path, isDirectory: &isDir), isDir.boolValue else {
            os_log("FinderQuickActions Host App: Target path is not a valid directory: %{public}@", log: logger, type: .error, directoryURL.path)
            return
        }
        
        let prefs = Preferences.load()
        let prefix = prefs.fileNamePrefix.isEmpty ? "Untitled" : prefs.fileNamePrefix
        
        // Instead of hardcoding an extension, we just use Untitled or whatever they have, but omit the extension if they want.
        // But to make it Windows-like, we can use the default extension from preferences.
        let ext = prefs.fileExtension.isEmpty ? "txt" : prefs.fileExtension
        var fileURL = directoryURL.appendingPathComponent("\(prefix).\(ext)")
        
        // If they want truly extension-free by default, we could skip the extension:
        // let fileURL = directoryURL.appendingPathComponent("\(prefix)")
        
        var counter = 0
        while fileManager.fileExists(atPath: fileURL.path) {
            fileURL = directoryURL.appendingPathComponent("\(prefix)_\(counter).\(ext)")
            counter += 1
        }
        
        do {
            try "".write(to: fileURL, atomically: true, encoding: .utf8)
            os_log("FinderQuickActions Host App: Created file at %{public}@", log: logger, type: .default, fileURL.path)
        } catch {
            os_log("FinderQuickActions Host App: Failed to create file: %{public}@", log: logger, type: .error, error.localizedDescription)
        }
    }
    
    private func openTerminal(for directoryURL: URL) {
        let fileManager = FileManager.default
        
        var isDir: ObjCBool = false
        guard fileManager.fileExists(atPath: directoryURL.path, isDirectory: &isDir), isDir.boolValue else {
            os_log("FinderQuickActions Host App: Target path is not a valid directory for Terminal: %{public}@", log: logger, type: .error, directoryURL.path)
            return
        }
        
        let prefs = Preferences.load()
        let path = directoryURL.path
        
        switch prefs.terminalApp {
        case "antigravity":
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
            process.arguments = ["-a", "Antigravity IDE", path]
            try? process.run()
            
        case "vscode":
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
            process.arguments = ["-a", "Visual Studio Code", path]
            try? process.run()
            
        default:
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
            process.arguments = ["-a", "Terminal", path]
            try? process.run()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApplication.shared.setActivationPolicy(.accessory)
        
        // Setup Main Menu for Cmd+Q to work
        let mainMenu = NSMenu()
        let appMenuItem = NSMenuItem()
        mainMenu.addItem(appMenuItem)
        let appMenu = NSMenu()
        appMenu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        appMenuItem.submenu = appMenu
        NSApp.mainMenu = mainMenu
        
        BackgroundService.shared.start()
        BackgroundService.shared.setupStatusItem()
    }
}

@main
struct FinderQuickActionsApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}
