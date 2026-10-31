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
        .menuBarExtraStyle(.menu)
    }
}

struct MenuBarContent: View {
    @EnvironmentObject var store: StopwatchStore
    @AppStorage("alwaysOnTop") private var alwaysOnTop = false
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        ForEach(store.stopwatches) { watch in
            Button {
                store.toggle(watch.id)
            } label: {
                Text("\(watch.isRunning ? "Pause" : "Start") \(watch.name)  \(TimeFormat.compact(watch.elapsed()))")
            }
        }
        if !store.stopwatches.isEmpty { Divider() }
        Button("New Stopwatch") { store.add() }
        Button("Pause All") { store.pauseAll() }
            .disabled(store.runningCount == 0)
        Divider()
        Toggle("Always on Top", isOn: $alwaysOnTop)
        Button("Show Window") {
            if !MainWindow.show() {
                openWindow(id: "main")
                NSApp.activate(ignoringOtherApps: true)
            }
        }
        Divider()
        Button("Quit Stopwatches") { NSApp.terminate(nil) }
            .keyboardShortcut("q")
    }
}
