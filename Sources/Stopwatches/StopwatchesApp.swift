import SwiftUI

/// Keeps a handle on the main window so it can be hidden and shown again.
enum MainWindow {
    static weak var window: NSWindow?

    /// Brings the hidden or minimized window back. Returns false if no window exists yet.
    @discardableResult
    static func show() -> Bool {
        guard let window else { return false }
        if window.isMiniaturized { window.deminiaturize(nil) }
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        return true
    }
}

/// Target for the red close button: hide the window instead of destroying it.
final class CloseHider: NSObject {
    @objc func hide(_ sender: Any?) { MainWindow.window?.orderOut(nil) }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    /// Runs when the user clicks the app icon in the Dock or Finder.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        !MainWindow.show()
    }
}

@main
struct StopwatchesApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var store = StopwatchStore()
    @AppStorage("alwaysOnTop") private var alwaysOnTop = false
    @Environment(\.openWindow) private var openWindow

    var body: some Scene {
        Window("Stopwatches", id: "main") {
            ContentView()
                .environmentObject(store)
        }
        .defaultSize(width: 620, height: 420)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Stopwatch") { store.add() }
                    .keyboardShortcut("n")
            }
            CommandGroup(after: .windowArrangement) {
                Toggle("Always on Top", isOn: $alwaysOnTop)
                    .keyboardShortcut("t", modifiers: [.command, .shift])
            }
        }

        MenuBarExtra {
            MenuBarContent()
                .environmentObject(store)
        } label: {
            HStack(spacing: 4) {
                Image(systemName: store.runningCount > 0 ? "stopwatch.fill" : "stopwatch")
                if !store.menuTitle.isEmpty {
                    Text(store.menuTitle).monospacedDigit()
                }
            }
        }
        .menuBarExtraStyle(.window)
    }
}

struct MenuBarContent: View {
    @EnvironmentObject var store: StopwatchStore
    @AppStorage("alwaysOnTop") private var alwaysOnTop = false
    @Environment(\.openWindow) private var openWindow

    // A SwiftUI panel instead of a native menu: a native menu redraws its rows
    // every time a live time changes, which breaks the hover highlight.
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if store.stopwatches.isEmpty {
                Text("No stopwatches")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            } else {
                ForEach(store.stopwatches) { watch in
                    PanelRow(watch: watch)
                }
            }

            Divider().padding(.vertical, 4)

            PanelButton("New Stopwatch", systemImage: "plus") { store.add() }
            PanelButton("Pause All", systemImage: "pause.circle") { store.pauseAll() }
                .disabled(store.runningCount == 0)

            Divider().padding(.vertical, 4)

            Toggle(isOn: $alwaysOnTop) {
                Label("Always on Top", systemImage: alwaysOnTop ? "pin.fill" : "pin")
            }
            .toggleStyle(.switch)
            .controlSize(.small)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)

            PanelButton("Show Window", systemImage: "macwindow") {
                if !MainWindow.show() {
                    openWindow(id: "main")
                    NSApp.activate(ignoringOtherApps: true)
                }
            }

            Divider().padding(.vertical, 4)

            PanelButton("Quit Stopwatches", systemImage: "power") { NSApp.terminate(nil) }
        }
        .padding(8)
        .frame(width: 280)
    }
}

private struct PanelRow: View {
    @EnvironmentObject var store: StopwatchStore
    let watch: Stopwatch

    var body: some View {
        let accent = Palette.color(watch.colorIndex)
        HStack(spacing: 10) {
            Circle().fill(accent).frame(width: 9, height: 9)
            Text(watch.name).lineLimit(1)
            Spacer(minLength: 8)
            TimelineView(.periodic(from: .now, by: 1)) { context in
                Text(TimeFormat.compact(watch.elapsed(at: context.date)))
                    .monospacedDigit()
                    .foregroundStyle(watch.isRunning ? accent : .secondary)
            }
            Button { store.toggle(watch.id) } label: {
                Image(systemName: watch.isRunning ? "pause.fill" : "play.fill")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 26, height: 26)
                    .background(accent, in: Circle())
            }
            .buttonStyle(.plain)
            .help(watch.isRunning ? "Pause" : "Start")
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
    }
}

private struct PanelButton: View {
    let title: String
    let systemImage: String
    let action: () -> Void
    @State private var hovering = false
    @Environment(\.isEnabled) private var isEnabled

    init(_ title: String, systemImage: String, action: @escaping () -> Void) {
        self.title = title
        self.systemImage = systemImage
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(hovering && isEnabled ? Color.primary.opacity(0.1) : .clear,
                    in: RoundedRectangle(cornerRadius: 6))
        .opacity(isEnabled ? 1 : 0.4)
        .onHover { hovering = $0 }
    }
}
