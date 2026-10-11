// Profiles for Claude: a native menu-bar panel over the existing CLI.
import Cocoa
import SwiftUI

let cli = NSHomeDirectory() + "/.local/bin/claude-profiles"
private let accent = Color(NSColor(name: nil) { appearance in
    if appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua {
        return NSColor(srgbRed: 0.86, green: 0.55, blue: 0.41, alpha: 1)
    }
    return NSColor(srgbRed: 0.70, green: 0.34, blue: 0.22, alpha: 1)
})

final class PanelModel: ObservableObject {
    @Published var status: Status?
    @Published var switching = false
    @Published var refreshing = true
    @Published var error: String?

    var height: CGFloat {
        let rows = status?.profiles.reduce(0) { total, profile in
            let windows = profile.usageWindows
            let resetRows = stride(from: 0, to: windows.count, by: 2).filter { start in
                windows[start..<min(start + 2, windows.count)].contains { $0.reset != nil }
            }.count
            return total + (profile.logged_in ? 58 + ((windows.count + 1) / 2) * 38 + resetRows * 12 : 78)
        } ?? 110
        let available = (NSApp.keyWindow?.screen ?? NSApp.mainWindow?.screen ?? NSScreen.main)?
            .visibleFrame.height ?? 800
        let minimum: CGFloat = error == nil ? 270 : 360
        return min(max(CGFloat(rows + 186), minimum), min(720, available - 40))
    }
}

private struct UsageMeter: View {
    let window: Window

    var tint: Color {
        guard let remaining = window.remainingPercent else { return .secondary }
        if remaining <= 10 { return Color(NSColor.systemRed) }
        if remaining <= 30 { return Color(NSColor.systemOrange) }
        return accent
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 4) {
                Text(window.displayTitle).foregroundStyle(.secondary).lineLimit(1)
                Spacer(minLength: 4)
                Text(window.remainingPercent.map { "\($0)% left" } ?? "Unknown")
                    .fontWeight(.medium).monospacedDigit()
            }
            .font(.system(size: 11))
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.primary.opacity(0.09))
                    if let remaining = window.remainingPercent {
                        Capsule().fill(tint)
                            .frame(width: geometry.size.width * CGFloat(remaining) / 100)
                    }
                }
            }
            .frame(height: 5)
            if let reset = window.reset {
                Text("Resets \(reset)").font(.system(size: 10)).foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(window.displayTitle)
        .accessibilityValue(window.remainingPercent.map { "\($0) percent remaining, cached" }
                            ?? "Usage unavailable")
        .accessibilityHint(window.reset.map { "Resets \($0)" } ?? "Reset time not recorded")
    }
}

private struct ProfileRow: View {
    let profile: Profile
    let switching: Bool
    let select: () -> Void
    let rename: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: select) {
            VStack(alignment: .leading, spacing: 9) {
                HStack(spacing: 9) {
                    Text(String(profile.n)).font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(profile.active ? accent : Color.secondary)
                        .frame(width: 28, height: 28)
                        .background(profile.active ? accent.opacity(0.12) : Color.primary.opacity(0.05))
                        .clipShape(Circle())
                    VStack(alignment: .leading, spacing: 2) {
                        Text(profile.displayName).font(.system(size: 13, weight: .semibold))
                            .lineLimit(1).truncationMode(.tail)
                        Text(profile.logged_in ? profile.cacheSummary : "Sign-in required")
                            .font(.system(size: 10)).foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 4)
                    if profile.active {
                        Label("Active", systemImage: "checkmark")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(accent)
                    }
                    if profile.n >= 1 && profile.n <= 9 {
                        Text("⌘\(profile.n)").font(.system(size: 10)).foregroundStyle(.secondary)
                    }
                }
                if profile.logged_in {
                    LazyVGrid(columns: [GridItem(.flexible(), alignment: .topLeading),
                                        GridItem(.flexible(), alignment: .topLeading)],
                              alignment: .leading, spacing: 8) {
                        ForEach(Array(profile.usageWindows.enumerated()), id: \.offset) { _, window in
                            UsageMeter(window: window)
                        }
                    }
                } else {
                    Text("Select to sign in through Claude.")
                        .font(.system(size: 11)).foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 12).padding(.vertical, 11)
            .contentShape(Rectangle())
            .background(profile.active ? accent.opacity(0.06)
                        : hovering ? Color.primary.opacity(0.04) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 9))
        }
        .buttonStyle(.plain)
        .profileShortcut(profile.n)
        .disabled(switching)
        .onHover { hovering = $0 }
        .help("\(profile.displayName)\(profile.active ? " is active" : ": switch account")")
        .accessibilityLabel("\(profile.displayName), profile \(profile.n)\(profile.active ? ", active" : "")")
        .accessibilityValue(profile.accessibilityUsage)
        .accessibilityHint(profile.active ? "Already selected" : "Relaunches Claude with this account")
        .contextMenu { Button("Rename profile…", action: rename).disabled(switching) }
    }
}

private extension View {
    @ViewBuilder func profileShortcut(_ number: Int) -> some View {
        if number >= 1 && number <= 9 {
            keyboardShortcut(KeyEquivalent(Character(String(number))), modifiers: .command)
        } else {
            self
        }
    }
}

private struct ProfilesPanel: View {
    @ObservedObject var model: PanelModel
    let select: (Int) -> Void
    let next: () -> Void
    let add: () -> Void
    let rename: (Profile) -> Void
    let refresh: () -> Void
    let quit: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "person.2.circle.fill")
                    .font(.system(size: 23)).foregroundStyle(accent)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Profiles").font(.system(size: 17, weight: .semibold))
                    Text("Claude Desktop").font(.system(size: 11)).foregroundStyle(.secondary)
                }
                Spacer()
                if let status = model.status {
                    Text("\(status.profiles.count) accounts")
                        .font(.system(size: 11)).foregroundStyle(.secondary)
                }
            }
            .padding(16)
            Divider()
            HStack {
                Text(model.switching ? "Switching accounts…" : "Select an account")
                    .font(.system(size: 11, weight: .medium))
                Spacer()
                Text("Cached usage").font(.system(size: 10)).foregroundStyle(.secondary)
                    .help("Saved usage can lag behind Claude. Check Claude's Usage card for live limits.")
            }
            .padding(.horizontal, 20).padding(.top, 12).padding(.bottom, 5)

            if let error = model.error {
                VStack(spacing: 9) {
                    Image(systemName: "exclamationmark.circle").font(.system(size: 24))
                    Text(error).font(.system(size: 13, weight: .medium))
                    Text("Check that claude-profiles is installed, then try again.")
                        .font(.system(size: 11)).foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    Button("Try again", action: refresh)
                }
                .padding(20).frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let status = model.status {
                if status.profiles.isEmpty {
                    VStack(spacing: 8) {
                        Text("No profiles yet").font(.system(size: 13, weight: .medium))
                        Text("Add an account to get started.").font(.system(size: 11))
                            .foregroundStyle(.secondary)
                        Button("Add profile…", action: add).disabled(model.switching)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        VStack(spacing: 2) {
                            ForEach(status.profiles, id: \.n) { profile in
                                ProfileRow(profile: profile, switching: model.switching,
                                           select: { select(profile.n) }, rename: { rename(profile) })
                            }
                        }
                        .padding(.horizontal, 8).padding(.vertical, 3)
                    }
                }
            } else {
                VStack(spacing: 9) {
                    ProgressView().controlSize(.small)
                    Text("Loading profiles…").font(.system(size: 12)).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            Divider()
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 12) {
                    Button(action: refresh) { Label("Refresh", systemImage: "arrow.clockwise") }
                        .keyboardShortcut("r", modifiers: .command)
                        .help("Reread saved usage; does not query Claude's servers")
                        .disabled(model.refreshing)
                    if model.refreshing { ProgressView().controlSize(.mini) }
                    Spacer(minLength: 0)
                    Button(action: next) { Label("Next", systemImage: "arrow.right") }
                        .keyboardShortcut("n", modifiers: .command)
                        .disabled(model.switching || (model.status?.profiles.count ?? 0) < 2)
                    Menu {
                        Button("Add profile…", action: add).disabled(model.switching)
                        Menu("Rename profile") {
                            ForEach(model.status?.profiles ?? [], id: \.n) { profile in
                                Button(profile.displayName) { rename(profile) }
                            }
                        }.disabled(model.switching || (model.status?.profiles.isEmpty ?? true))
                        Divider()
                        Button("Quit Profiles for Claude", action: quit)
                            .keyboardShortcut("q", modifiers: .command)
                    } label: {
                        Image(systemName: "ellipsis.circle").font(.system(size: 16))
                            .accessibilityLabel("Profile options")
                    }
                    .menuStyle(.borderlessButton).fixedSize()
                    .accessibilityLabel("Profile options")
                    .help("Add profiles, rename accounts or quit")
                }
                .font(.system(size: 12)).buttonStyle(.borderless)
                Text("Usage is cached. Refresh rereads saved data.")
                    .font(.system(size: 10)).foregroundStyle(.secondary)
                Text("Switching relaunches Claude. Finish running responses first.")
                    .font(.system(size: 10)).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 20).padding(.vertical, 13)
        }
        .frame(width: 400, height: model.height)
        .background(Color(NSColor.windowBackgroundColor))
    }
}

private final class NameFieldDelegate: NSObject, NSTextFieldDelegate {
    let save: NSButton
    init(save: NSButton) { self.save = save }
    func controlTextDidChange(_ notification: Notification) {
        guard let field = notification.object as? NSTextField else { return }
        save.isEnabled = !field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate {
    var item: NSStatusItem!
    var timer: Timer?
    var switching = false
    var lastActive: Int?
    let model = PanelModel()
    let popover = NSPopover()
    var keyMonitor: Any?

    func applicationDidFinishLaunching(_ note: Notification) {
        item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = item.button {
            button.image = NSImage(systemSymbolName: "person.2.circle", accessibilityDescription: "Profiles for Claude")
            button.imagePosition = .imageLeading
            button.title = " Profiles"
            button.target = self
            button.action = #selector(togglePanel)
        }
        popover.behavior = .transient
        popover.delegate = self
        popover.contentViewController = NSHostingController(rootView: ProfilesPanel(
            model: model, select: { [weak self] in self?.switchTo($0) },
            next: { [weak self] in self?.doSwitch(["next"]) },
            add: { [weak self] in self?.doSwitch(["add", "--switch"]) },
            rename: { [weak self] in self?.renameProfile($0) },
            refresh: { [weak self] in self?.refresh() }, quit: { NSApp.terminate(nil) }))
        installEditMenu()
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { _ in self.refresh() }
    }

    func installEditMenu() {
        let menu = NSMenu()
        let application = NSMenuItem(title: "Profiles for Claude", action: nil, keyEquivalent: "")
        let applicationMenu = NSMenu()
        applicationMenu.addItem(NSMenuItem(title: "Quit Profiles for Claude",
                                           action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        application.submenu = applicationMenu
        menu.addItem(application)
        let edit = NSMenuItem(title: "Edit", action: nil, keyEquivalent: "")
        let submenu = NSMenu(title: "Edit")
        for (title, action, key) in [("Cut", #selector(NSText.cut(_:)), "x"),
                                     ("Copy", #selector(NSText.copy(_:)), "c"),
                                     ("Paste", #selector(NSText.paste(_:)), "v"),
                                     ("Select All", #selector(NSText.selectAll(_:)), "a")] {
            submenu.addItem(NSMenuItem(title: title, action: action, keyEquivalent: key))
        }
        edit.submenu = submenu
        menu.addItem(edit)
        NSApp.mainMenu = menu
    }

    @objc func togglePanel() {
        if popover.isShown { popover.performClose(nil); return }
        guard let button = item.button else { return }
        popover.animates = !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        popover.contentSize = NSSize(width: 400, height: model.height)
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        NSApp.activate(ignoringOtherApps: true)
        popover.contentViewController?.view.window?.makeKey()
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 { self?.popover.performClose(nil); return nil }
            return event
        }
        refresh()
    }

    func popoverDidClose(_ notification: Notification) {
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor); self.keyMonitor = nil }
    }

    func runCLI(_ args: [String]) -> String {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: cli)
        p.arguments = args
        let out = Pipe()
        p.standardOutput = out
        p.standardError = FileHandle.nullDevice
        do { try p.run() } catch { return "" }
        let data = out.fileHandleForReading.readDataToEndOfFile()
        p.waitUntilExit()
        return String(data: data, encoding: .utf8) ?? ""
    }

    func refresh() {
        model.refreshing = true
        DispatchQueue.global().async {
            let json = self.runCLI(["status", "--json"])
            guard let data = json.data(using: .utf8),
                  let st = try? JSONDecoder().decode(Status.self, from: data) else {
                DispatchQueue.main.async {
                    self.item.button?.title = "  Profiles · !"
                    self.model.error = "Couldn't read profiles"
                    self.model.refreshing = false
                }
                return
            }
            DispatchQueue.main.async { self.render(st) }
        }
    }

    func render(_ st: Status) {
        if switching, let a = st.active, a != lastActive { switching = false }
        lastActive = st.active
        model.status = st
        model.switching = switching
        model.refreshing = false
        model.error = nil
        popover.contentSize = NSSize(width: 400, height: model.height)
        let profile = st.profiles.first(where: { $0.active })
        item.button?.title = "  " + (switching ? "Switching…" : profile?.menuBarTitle ?? "Profiles")
        item.button?.toolTip = profile.map { "\($0.displayName) · \($0.updated). Usage is cached." }
        item.button?.setAccessibilityLabel(switching ? "Profiles for Claude, switching accounts"
                                          : "Profiles for Claude, \(profile?.menuBarTitle ?? "no active account")")
    }

    func switchTo(_ number: Int) {
        if number == lastActive { return }
        doSwitch([String(number)])
    }

    func renameProfile(_ profile: Profile) {
        guard !switching else { return }
        popover.performClose(nil)
        let alert = NSAlert()
        alert.messageText = "Rename profile"
        alert.informativeText = "Choose a short name for the menu bar."
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Cancel")
        let field = NSTextField(string: profile.label)
        field.frame = NSRect(x: 0, y: 0, width: 300, height: 24)
        field.placeholderString = "Profile name"
        field.setAccessibilityLabel("Profile name")
        let validation = NameFieldDelegate(save: alert.buttons[0])
        field.delegate = validation
        alert.buttons[0].isEnabled = !profile.label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        alert.accessoryView = field
        alert.window.initialFirstResponder = field
        NSApp.activate(ignoringOtherApps: true)
        guard withExtendedLifetime(validation, { alert.runModal() }) == .alertFirstButtonReturn else { return }
        let name = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        DispatchQueue.global().async {
            _ = self.runCLI(["label", String(profile.n), name])
            DispatchQueue.main.async { self.refresh() }
        }
    }

    func doSwitch(_ args: [String]) {
        guard !switching else { return }
        switching = true
        model.switching = true
        popover.performClose(nil)
        item.button?.title = "  Switching…"
        DispatchQueue.global().async {
            let out = self.runCLI(args)          // the CLI detaches and returns immediately
            if out.contains("already") || out.contains("No other") {
                DispatchQueue.main.async { self.switching = false; self.refresh() }
                return
            }
            for i in 1...30 {                    // wait up to 60 s for the switch to land
                Thread.sleep(forTimeInterval: 2)
                DispatchQueue.main.async { self.refresh() }
                if !self.switching || i == 30 { break }
            }
            DispatchQueue.main.async { self.switching = false; self.refresh() }
        }
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
