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
    private var clickMonitor: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // A click anywhere outside a text field ends editing, so a stopwatch name
        // does not stay focused after the user clicks away.
        clickMonitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown) { event in
            guard let window = event.window,
                  window.firstResponder is NSText,
                  let root = window.contentView?.superview else { return event }
            if !Self.isTextInput(root.hitTest(event.locationInWindow)) {
                window.makeFirstResponder(nil)
            }
            return event
        }
    }

    private static func isTextInput(_ view: NSView?) -> Bool {
        var current = view
        while let v = current {
            if v is NSTextField || v is NSText { return true }
            current = v.superview
        }
        return false
    }

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
    @AppStorage("compactCards") private var compactCards = false
    @Environment(\.openWindow) private var openWindow

    var body: some Scene {
        Window("MultiStopwatch", id: "main") {
            ContentView()
                .environmentObject(store)
        }
        .defaultSize(width: 620, height: 420)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About MultiStopwatch") {
                    openWindow(id: "about")
                    NSApp.activate(ignoringOtherApps: true)
                }
            }
            CommandGroup(replacing: .newItem) {
                Button("New Stopwatch") { store.add() }
                    .keyboardShortcut("n")
            }
            CommandGroup(after: .toolbar) {
                Toggle("Compact Cards", isOn: $compactCards)
                    .keyboardShortcut("c", modifiers: [.command, .option])
            }
            CommandGroup(after: .windowArrangement) {
                Toggle("Always on Top", isOn: $alwaysOnTop)
                    .keyboardShortcut("t", modifiers: [.command, .shift])
            }
        }

        Window("About MultiStopwatch", id: "about") {
            AboutView()
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)

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
    @AppStorage("compactCards") private var compactCards = false
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

            PanelSwitch("Always on Top", systemImage: alwaysOnTop ? "pin.fill" : "pin",
                        isOn: $alwaysOnTop)
            PanelSwitch("Compact Cards",
                        systemImage: compactCards ? "rectangle.grid.1x2.fill" : "rectangle.grid.1x2",
                        isOn: $compactCards)

            PanelButton("Show Window", systemImage: "macwindow") {
                if !MainWindow.show() {
                    openWindow(id: "main")
                    NSApp.activate(ignoringOtherApps: true)
                }
            }

            Divider().padding(.vertical, 4)

            PanelButton("Quit MultiStopwatch", systemImage: "power") { NSApp.terminate(nil) }
        }
        .padding(8)
        .frame(width: 280)
        .background(PanelBackground(cornerRadius: 12))
        // The system shadow is square, so draw a rounded one under the panel instead.
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(nsColor: .windowBackgroundColor))
                .shadow(color: .black.opacity(0.14), radius: 7, y: 3)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color.primary.opacity(0.12), lineWidth: 1)
        )
        // Room around the panel for the shadow.
        .padding(EdgeInsets(top: 2, leading: 10, bottom: 16, trailing: 10))
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
            Button { store.reset(watch.id) } label: {
                Image(systemName: "arrow.counterclockwise")
                    .font(.system(size: 11, weight: .semibold))
                    .frame(width: 26, height: 26)
                    .background(.quaternary, in: Circle())
            }
            .buttonStyle(.plain)
            .help("Reset to zero")
            .disabled(watch.elapsed() == 0)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
    }
}

/// Draws the menu bar panel's frosted background with rounded corners that match
/// macOS menus. SwiftUI draws its own panel background with a small fixed corner
/// radius, so that background is hidden and this one is drawn in its place.
private struct PanelBackground: NSViewRepresentable {
    let cornerRadius: CGFloat

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .menu
        view.blendingMode = .behindWindow
        view.state = .active
        view.maskImage = Self.roundedMask(radius: cornerRadius)
        DispatchQueue.main.async { hideSystemBackground(behind: view) }
        return view
    }

    func updateNSView(_ view: NSVisualEffectView, context: Context) {
        DispatchQueue.main.async { hideSystemBackground(behind: view) }
    }

    /// The system background is drawn by sibling views behind ours that cover the whole
    /// panel, which is larger than our background because of the room left for the shadow.
    /// The system shadow is square, so it is turned off; the panel draws its own.
    private func hideSystemBackground(behind view: NSView) {
        guard let host = view.superview, let container = host.superview,
              let index = container.subviews.firstIndex(of: host) else { return }
        for sibling in container.subviews[..<index]
        where sibling.frame != host.frame && sibling.frame.contains(host.frame) {
            sibling.isHidden = true
        }
        view.window?.hasShadow = false
    }

    private static func roundedMask(radius: CGFloat) -> NSImage {
        let edge = radius * 2 + 1
        let image = NSImage(size: NSSize(width: edge, height: edge), flipped: false) { rect in
            NSColor.black.setFill()
            NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()
            return true
        }
        image.capInsets = NSEdgeInsets(top: radius, left: radius, bottom: radius, right: radius)
        image.resizingMode = .stretch
        return image
    }
}

/// Label on the left, switch on the right, so several switches line up.
private struct PanelSwitch: View {
    let title: String
    let systemImage: String
    @Binding var isOn: Bool

    init(_ title: String, systemImage: String, isOn: Binding<Bool>) {
        self.title = title
        self.systemImage = systemImage
        self._isOn = isOn
    }

    var body: some View {
        HStack {
            Label(title, systemImage: systemImage)
            Spacer()
            Toggle(title, isOn: $isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.small)
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
