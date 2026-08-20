import Cocoa
import FinderSync
import os.log

let logger = OSLog(subsystem: "com.yourcompany.FinderQuickActions", category: "Extension")

@objc(FinderSync)
class FinderSync: FIFinderSync {
    
    override init() {
        super.init()
        os_log("FinderSyncExtension: Initializing...", log: logger, type: .default)
        
        // Set up the directories we are monitoring.
        // Resolve the real home directory path to bypass sandbox container redirection.
        let username = NSUserName()
        let homeURL = URL(fileURLWithPath: "/Users").appendingPathComponent(username)
        var monitoredURLs: Set<URL> = [homeURL]
        
        if let volumesURL = URL(string: "file:///Volumes") {
            monitoredURLs.insert(volumesURL)
        }
        
        FIFinderSyncController.default().directoryURLs = monitoredURLs
    }
    
    // MARK: - Menu Construction
    
    override func menu(for menuKind: FIMenuKind) -> NSMenu? {
        // We only show items in the container background context menu or item context menus
        guard menuKind == .contextualMenuForContainer || menuKind == .contextualMenuForItems else {
            return nil
        }
        
        let menu = NSMenu(title: "")
        
        // New File item
        let newFileItem = NSMenuItem(title: "New File", action: #selector(newFileAction(_:)), keyEquivalent: "")
        newFileItem.target = self
        
        // Open in Terminal item
        let openTerminalItem = NSMenuItem(title: "Open in Terminal", action: #selector(openTerminalAction(_:)), keyEquivalent: "")
        openTerminalItem.target = self
        
        // Finder Sync extensions often lose the "isTemplate" property when sending menus over XPC,
        // causing icons to render black in dark mode. We manually tint them white if dark mode is active (or just white since requested).
        let isDarkMode = UserDefaults.standard.string(forKey: "AppleInterfaceStyle") == "Dark"
        let iconColor: NSColor = isDarkMode ? .white : .black
        
        if #available(macOS 11.0, *) {
            if let newFileImg = NSImage(systemSymbolName: "doc.badge.plus", accessibilityDescription: nil) {
                newFileItem.image = tintImage(image: newFileImg, color: iconColor)
            }
            if let terminalImg = NSImage(systemSymbolName: "terminal", accessibilityDescription: nil) {
                openTerminalItem.image = tintImage(image: terminalImg, color: iconColor)
            }
        } else {
            if let newFileImg = NSImage(named: NSImage.addTemplateName) {
                newFileItem.image = tintImage(image: newFileImg, color: iconColor)
            }
            if let terminalImg = NSImage(named: NSImage.shareTemplateName) {
                openTerminalItem.image = tintImage(image: terminalImg, color: iconColor)
            }
        }
        
        menu.addItem(newFileItem)
        menu.addItem(openTerminalItem)
        
        return menu
    }
    
    private func tintImage(image: NSImage, color: NSColor) -> NSImage {
        let newImage = NSImage(size: image.size)
        newImage.lockFocus()
        color.set()
        let rect = NSRect(origin: .zero, size: image.size)
        rect.fill()
        image.draw(in: rect, from: .zero, operation: .destinationIn, fraction: 1.0)
        newImage.unlockFocus()
        newImage.isTemplate = false // explicitly disable template to keep our custom color
        return newImage
    }
    
    // MARK: - Helper to get Target Directory
    
    private func getTargetDirectory() -> URL? {
        let controller = FIFinderSyncController.default()
        
        // 1. Check selected items. If the user right-clicked a file or folder, use it
        if let selectedItems = controller.selectedItemURLs(), let firstSelected = selectedItems.first {
            var isDir: ObjCBool = false
            if FileManager.default.fileExists(atPath: firstSelected.path, isDirectory: &isDir) {
                if isDir.boolValue {
                    return firstSelected
                } else {
                    return firstSelected.deletingLastPathComponent()
                }
            }
        }
        
        // 2. Otherwise use targetedURL (the folder currently open in Finder)
        return controller.targetedURL()
    }
    
    // MARK: - Actions
    
    @objc func newFileAction(_ sender: NSMenuItem) {
        os_log("FinderSyncExtension: newFileAction triggered", log: logger, type: .default)
        guard let targetDir = getTargetDirectory() else {
            os_log("FinderSyncExtension: Could not determine target directory for new file", log: logger, type: .error)
            return
        }
        
        triggerHostApp(action: "new_file", path: targetDir.path)
    }
    
    @objc func openTerminalAction(_ sender: NSMenuItem) {
        os_log("FinderSyncExtension: openTerminalAction triggered", log: logger, type: .default)
        guard let targetDir = getTargetDirectory() else {
            os_log("FinderSyncExtension: Could not determine target directory for terminal", log: logger, type: .error)
            return
        }
        
        triggerHostApp(action: "open_terminal", path: targetDir.path)
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
    
    private func triggerHostApp(action: String, path: String) {
        let pendingFileURL = getSharedPendingFileURL()
        
        let payload = [
            "action": action,
            "path": path
        ]
        
        do {
            let data = try JSONSerialization.data(withJSONObject: payload, options: .prettyPrinted)
            try data.write(to: pendingFileURL)
            
            // Post Distributed Notification to alert the host app
            DistributedNotificationCenter.default().postNotificationName(
                NSNotification.Name("com.yourcompany.FinderQuickActions.trigger"),
                object: nil,
                userInfo: nil,
                deliverImmediately: true
            )
            
            os_log("FinderSyncExtension: Triggered host app for %{public}@ on %{public}@", log: logger, type: .default, action, path)
        } catch {
            os_log("FinderSyncExtension: Failed to write trigger file: %{public}@", log: logger, type: .error, error.localizedDescription)
        }
    }
}
