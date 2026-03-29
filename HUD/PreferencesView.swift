import SwiftUI

// MARK: - Preferences Window

struct PreferencesView: View {
    @State private var selectedTab = 0
    private let prefs = HUDPreferences.shared

    var body: some View {
        TabView(selection: $selectedTab) {
            GeneralTab(prefs: prefs)
                .tabItem { Label("General", systemImage: "gear") }
                .tag(0)

            DisplayTab(prefs: prefs)
                .tabItem { Label("Display", systemImage: "display") }
                .tag(1)

            PluginsTab(prefs: prefs)
                .tabItem { Label("Plugins", systemImage: "puzzlepiece") }
                .tag(2)

            NotificationsTab(prefs: prefs)
                .tabItem { Label("Notifications", systemImage: "bell") }
                .tag(3)

            KeyboardTab()
                .tabItem { Label("Keyboard", systemImage: "keyboard") }
                .tag(4)
        }
        .frame(minWidth: 500, minHeight: 400)
        .padding()
    }
}

// MARK: - General Tab

private struct GeneralTab: View {
    @Bindable var prefs: HUDPreferences

    var body: some View {
        Form {
            Section("Startup") {
                Toggle("Launch at login", isOn: $prefs.launchAtLogin)
                    .onChange(of: prefs.launchAtLogin) { prefs.save() }
            }

            Section("Window") {
                Toggle("Show in notch (vs floating panel)", isOn: $prefs.showInNotch)
                    .onChange(of: prefs.showInNotch) { prefs.save() }

                Picker("Default status bar size", selection: $prefs.statusBarSize) {
                    Text("XS").tag(StatusBarSize.xs)
                    Text("S").tag(StatusBarSize.small)
                    Text("M").tag(StatusBarSize.medium)
                    Text("L").tag(StatusBarSize.large)
                    Text("XL").tag(StatusBarSize.xl)
                }
                .onChange(of: prefs.statusBarSize) { prefs.save() }
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Display Tab

private struct DisplayTab: View {
    @Bindable var prefs: HUDPreferences

    var body: some View {
        Form {
            Section("Renderer") {
                Picker("Default renderer", selection: $prefs.displayMode) {
                    Text("Scanner").tag("scanner")
                    Text("LCD (dot-matrix)").tag("lcd")
                    Text("Text").tag("text")
                }
                .onChange(of: prefs.displayMode) { prefs.save() }

                Picker("Default LCD theme", selection: $prefs.lcdTheme) {
                    Text("Red").tag("red")
                    Text("Green").tag("green")
                    Text("Amber").tag("amber")
                    Text("Blue").tag("blue")
                }
                .onChange(of: prefs.lcdTheme) { prefs.save() }
            }

            Section("Animation") {
                HStack {
                    Text("Scanner speed")
                    Slider(value: $prefs.scannerSpeed, in: 0.5...3.0, step: 0.1) {
                        Text("Scanner speed")
                    }
                    Text(String(format: "%.1fx", prefs.scannerSpeed))
                        .monospacedDigit()
                        .frame(width: 40, alignment: .trailing)
                }
                .onChange(of: prefs.scannerSpeed) { prefs.save() }

                HStack {
                    Text("RSVP reading speed")
                    Slider(value: Binding(
                        get: { Double(prefs.rsvpWPM) },
                        set: { prefs.rsvpWPM = Int($0) }
                    ), in: 100...600, step: 10) {
                        Text("WPM")
                    }
                    Text("\(prefs.rsvpWPM) WPM")
                        .monospacedDigit()
                        .frame(width: 70, alignment: .trailing)
                }
                .onChange(of: prefs.rsvpWPM) { prefs.save() }
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Plugins Tab

private struct PluginsTab: View {
    @Bindable var prefs: HUDPreferences
    private var registry: PluginRegistry { PluginRegistry.shared }

    var body: some View {
        Form {
            Section("Installed Plugins") {
                if registry.plugins.isEmpty {
                    Text("No plugins installed")
                        .foregroundStyle(.secondary)
                        .italic()
                } else {
                    ForEach(registry.plugins, id: \.id) { plugin in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(plugin.name)
                                    .font(.headline)
                                Text(plugin.description)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            let isRunning = registry.pluginStates[plugin.id]?.isRunning ?? false
                            Toggle("", isOn: Binding(
                                get: { isRunning },
                                set: { newValue in
                                    if newValue {
                                        registry.startPlugin(plugin.id)
                                    } else {
                                        registry.stopPlugin(plugin.id)
                                    }
                                }
                            ))
                            .toggleStyle(.switch)
                            .labelsHidden()
                        }
                    }
                }
            }

            Section("Rotation") {
                HStack {
                    Text("Rotation interval")
                    Slider(value: $prefs.rotationInterval, in: 3...60, step: 1) {
                        Text("Rotation interval")
                    }
                    Text("\(Int(prefs.rotationInterval))s")
                        .monospacedDigit()
                        .frame(width: 40, alignment: .trailing)
                }
                .onChange(of: prefs.rotationInterval) { prefs.save() }
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Notifications Tab

private struct NotificationsTab: View {
    @Bindable var prefs: HUDPreferences
    private var focusManager: FocusManager { FocusManager.shared }

    var body: some View {
        Form {
            Section("TTL & Escalation") {
                HStack {
                    Text("Default TTL")
                    Slider(value: Binding(
                        get: { Double(prefs.defaultTTL) },
                        set: { prefs.defaultTTL = Int($0) }
                    ), in: 30...1800, step: 30) {
                        Text("Default TTL")
                    }
                    Text(formatDuration(prefs.defaultTTL))
                        .monospacedDigit()
                        .frame(width: 55, alignment: .trailing)
                }
                .onChange(of: prefs.defaultTTL) { prefs.save() }

                Toggle("Enable escalation", isOn: $prefs.escalationEnabled)
                    .onChange(of: prefs.escalationEnabled) { prefs.save() }
            }

            Section("Focus Mode") {
                Picker("Focus mode", selection: Binding(
                    get: { focusManager.activeProfileName ?? "off" },
                    set: { newValue in
                        if newValue == "off" {
                            focusManager.deactivate()
                        } else {
                            focusManager.activate(newValue)
                        }
                        prefs.focusMode = newValue
                        prefs.save()
                    }
                )) {
                    Text("Off").tag("off")
                    Text("Work (red + sos only)").tag("work")
                    Text("Sleep (sos only)").tag("sleep")
                    Text("Personal (all)").tag("personal")
                }
            }

            Section("Rate Limiting") {
                HStack {
                    Text("Max per source (per minute)")
                    Stepper("\(prefs.rateLimitPerSource)", value: $prefs.rateLimitPerSource, in: 1...60)
                        .monospacedDigit()
                }
                .onChange(of: prefs.rateLimitPerSource) { prefs.save() }
            }
        }
        .formStyle(.grouped)
    }

    private func formatDuration(_ seconds: Int) -> String {
        if seconds < 60 { return "\(seconds)s" }
        let min = seconds / 60
        let sec = seconds % 60
        if sec == 0 { return "\(min)m" }
        return "\(min)m \(sec)s"
    }
}

// MARK: - Keyboard Tab

private struct KeyboardTab: View {
    private let shortcuts: [(String, String)] = [
        ("Toggle HUD", "Ctrl + Shift + H"),
        ("Next plugin", "Ctrl + Shift + N"),
        ("Previous plugin", "Ctrl + Shift + P"),
        ("Cycle size (XS-S-M-L-XL)", "Ctrl + Shift + S"),
        ("Cycle display mode", "Ctrl + Shift + D"),
        ("Cycle LCD theme", "Ctrl + Shift + T"),
        ("Cycle focus mode", "Ctrl + Shift + F"),
        ("Mute/unmute", "Ctrl + Shift + M"),
        ("Toggle panel (legacy)", "` (backtick)"),
    ]

    var body: some View {
        Form {
            Section("Keyboard Shortcuts") {
                ForEach(shortcuts, id: \.0) { shortcut in
                    HStack {
                        Text(shortcut.0)
                        Spacer()
                        Text(shortcut.1)
                            .font(.system(.body, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.gray.opacity(0.15))
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                }
            }

            Section {
                Text("Custom key bindings coming in a future update.")
                    .foregroundStyle(.tertiary)
                    .italic()
            }
        }
        .formStyle(.grouped)
    }
}
