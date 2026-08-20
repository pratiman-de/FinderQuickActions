import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @State private var fileExtension: String = "txt"
    @State private var customExtension: String = ""
    @State private var fileNamePrefix: String = "Untitled"
    @State private var terminalApp: String = "terminal"
    @State private var launchAtLogin: Bool = false
    
    let extensionOptions = ["txt", "md", "py", "ipynb", "custom"]
    let terminalOptions = [
        ("terminal", "macOS Terminal"),
        ("vscode", "Visual Studio Code"),
        ("antigravity", "Antigravity IDE")
        
    ]
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 28))
                    .foregroundColor(.accentColor)
                VStack(alignment: .leading, spacing: 2) {
                    Text("FinderQuickActions")
                        .font(.headline)
                        .fontWeight(.bold)
                    Text("Configure your Finder right-click actions")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
            .padding(.bottom, 5)
            
            Divider()
            
            // Settings Form
            VStack(alignment: .leading, spacing: 16) {
                // New File Configuration
                VStack(alignment: .leading, spacing: 8) {
                    Text("New File Options")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                    
                    HStack {
                        Text("File Name:")
                            .frame(width: 100, alignment: .leading)
                        TextField("e.g. Untitled", text: $fileNamePrefix)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                    
                    HStack {
                        Text("Extension:")
                            .frame(width: 100, alignment: .leading)
                        Picker("", selection: $fileExtension) {
                            ForEach(extensionOptions, id: \.self) { opt in
                                Text(opt == "custom" ? "Custom..." : ".\(opt)").tag(opt)
                            }
                        }
                        .pickerStyle(SegmentedPickerStyle())
                    }
                    
                    if fileExtension == "custom" {
                        HStack {
                            Spacer().frame(width: 100)
                            TextField("Enter custom extension (e.g. py, json)", text: $customExtension)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                        }
                    }
                }
                
                Divider()
                
                // Terminal Configuration
                VStack(alignment: .leading, spacing: 8) {
                    Text("Terminal Options")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                    
                    HStack {
                        Text("Open In:")
                            .frame(width: 100, alignment: .leading)
                        Picker("", selection: $terminalApp) {
                            ForEach(terminalOptions, id: \.0) { key, label in
                                Text(label).tag(key)
                            }
                        }
                        .pickerStyle(PopUpButtonPickerStyle())
                    }
                }
                
                Divider()
                
                // Launch & System Settings
                VStack(alignment: .leading, spacing: 8) {
                    Text("System Integration")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                    
                    Toggle("Launch at Login", isOn: $launchAtLogin)
                        .toggleStyle(SwitchToggleStyle())
                        .onChange(of: launchAtLogin) { oldValue, newValue in
                            toggleLaunchAtLogin(newValue)
                        }
                    
                    HStack {
                        Button(action: openSystemExtensions) {
                            HStack {
                                Image(systemName: "gearshape")
                                Text("Open Extension Settings")
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        
                        Spacer()
                    }
                    .padding(.top, 4)
                    

                }
            }
            
            Divider()
            
            // Footer Save Button
            HStack {
                Spacer()
                Button(action: saveSettings) {
                    Text("Save Changes")
                        .fontWeight(.semibold)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(24)
        .frame(width: 450)
        .onAppear(perform: loadSettings)
    }
    
    // MARK: - Actions
    
    private func loadSettings() {
        let prefs = Preferences.load()
        self.fileNamePrefix = prefs.fileNamePrefix
        self.terminalApp = prefs.terminalApp
        
        let ext = prefs.fileExtension
        if extensionOptions.contains(ext) && ext != "custom" {
            self.fileExtension = ext
        } else {
            self.fileExtension = "custom"
            self.customExtension = ext
        }
        
        // Load launch at login status
        if #available(macOS 13.0, *) {
            self.launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }
    
    private func saveSettings() {
        var prefs = Preferences()
        prefs.fileNamePrefix = fileNamePrefix
        prefs.terminalApp = terminalApp
        
        if fileExtension == "custom" {
            let trimmed = customExtension.trimmingCharacters(in: CharacterSet(charactersIn: "."))
            prefs.fileExtension = trimmed.isEmpty ? "txt" : trimmed
        } else {
            prefs.fileExtension = fileExtension
        }
        
        prefs.save()
        
        let alert = NSAlert()
        alert.messageText = "Settings Saved"
        alert.informativeText = "Your preferences have been successfully updated."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
    
    private func toggleLaunchAtLogin(_ enable: Bool) {
        if #available(macOS 13.0, *) {
            do {
                if enable {
                    if SMAppService.mainApp.status != .enabled {
                        try SMAppService.mainApp.register()
                    }
                } else {
                    if SMAppService.mainApp.status == .enabled {
                        try SMAppService.mainApp.unregister()
                    }
                }
            } catch {
                NSLog("FinderQuickActions: Failed to toggle launch at login: \(error.localizedDescription)")
            }
        }
    }
    
    private func openSystemExtensions() {
        let url = URL(string: "x-apple.systempreferences:com.apple.ExtensionsPreferences")!
        NSWorkspace.shared.open(url)
    }
}
