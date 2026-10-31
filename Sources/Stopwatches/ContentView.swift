import SwiftUI
import AppKit

struct ContentView: View {
    @EnvironmentObject var store: StopwatchStore
    @AppStorage("alwaysOnTop") private var alwaysOnTop = false

    private let columns = [GridItem(.adaptive(minimum: 280, maximum: 400), spacing: 16)]

    var body: some View {
        ScrollView {
            if store.stopwatches.isEmpty {
                emptyState
            } else {
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach($store.stopwatches) { $watch in
                        StopwatchCard(watch: $watch)
                    }
                }
                .padding(20)
            }
        }
        .frame(minWidth: 320, minHeight: 240)
        .background(VisualEffectBackground())
        .background(WindowConfigurator(alwaysOnTop: alwaysOnTop))
        .toolbar {
            ToolbarItemGroup {
                Button { store.add() } label: { Label("New Stopwatch", systemImage: "plus") }
                    .help("Add a stopwatch")
                Button { store.pauseAll() } label: { Label("Pause All", systemImage: "pause.circle") }
                    .help("Pause all running stopwatches")
                    .disabled(store.runningCount == 0)
                Toggle(isOn: $alwaysOnTop) {
                    Label("Always on Top", systemImage: alwaysOnTop ? "pin.fill" : "pin")
                }
                .help(alwaysOnTop ? "Window stays above other windows" : "Keep window above other windows")
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "stopwatch")
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(.secondary)
            Text("No stopwatches")
                .font(.title3.weight(.medium))
            Button("Add Stopwatch") { store.add() }
                .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, minHeight: 300)
    }
}

struct StopwatchCard: View {
    @EnvironmentObject var store: StopwatchStore
    @Binding var watch: Stopwatch
    @State private var hovering = false

    @State private var editing = false

    private var accent: Color { Palette.color(watch.colorIndex) }
    private var timeFont: Font { .system(size: 42, weight: .semibold, design: .rounded).monospacedDigit() }

    private func beginEdit() { editing = true }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Circle()
                    .fill(accent)
                    .frame(width: 10, height: 10)
                    .onTapGesture { watch.colorIndex += 1 }
                    .help("Click to change color")
                TextField("Name", text: $watch.name)
                    .textFieldStyle(.plain)
                    .font(.headline)
                Spacer(minLength: 0)
                Button { store.remove(watch.id) } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Delete stopwatch")
                .opacity(hovering ? 1 : 0)
            }

            if editing {
                TimeEditor(initial: watch.elapsed(), font: timeFont) { value in
                    store.setElapsed(watch.id, to: value)
                    editing = false
                } onCancel: {
                    editing = false
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                TimelineView(.animation(minimumInterval: 1.0 / 30, paused: !watch.isRunning)) { context in
                    Text(TimeFormat.full(watch.elapsed(at: context.date)))
                        .font(timeFont)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                        .foregroundStyle(watch.isRunning ? accent : .primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .contentShape(Rectangle())
                .onTapGesture(count: 2, perform: beginEdit)
                .help("Double-click to set the time")
            }

            HStack(spacing: 10) {
                Button { store.toggle(watch.id) } label: {
                    Label(watch.isRunning ? "Pause" : (watch.accumulated > 0 ? "Resume" : "Start"),
                          systemImage: watch.isRunning ? "pause.fill" : "play.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(accent, in: Capsule())
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)

                Button { store.reset(watch.id) } label: {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 13, weight: .semibold))
                        .frame(width: 34, height: 34)
                        .background(.quaternary, in: Circle())
                }
                .buttonStyle(.plain)
                .help("Reset to zero")
                .disabled(watch.elapsed() == 0)
            }
        }
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(watch.isRunning ? accent.opacity(0.6) : Color.primary.opacity(0.08),
                              lineWidth: watch.isRunning ? 1.5 : 1)
        )
        .shadow(color: .black.opacity(0.08), radius: 8, y: 2)
        .animation(.easeInOut(duration: 0.2), value: watch.isRunning)
        .onHover { hovering = $0 }
        .contextMenu {
            Button("Set Time…", action: beginEdit)
            Button("Reset") { store.reset(watch.id) }
            Divider()
            Button("Delete", role: .destructive) { store.remove(watch.id) }
        }
    }
}

/// Three-slot editor (hours : minutes : seconds). Tab, Shift-Tab and the arrow keys
/// move between slots, and the cursor jumps ahead after two digits. Return saves,
/// Escape cancels, and clicking away saves.
struct TimeEditor: View {
    let font: Font
    let onCommit: (TimeInterval) -> Void
    let onCancel: () -> Void

    private enum Slot: Int, CaseIterable { case hours, minutes, seconds }

    @State private var hours: String
    @State private var minutes: String
    @State private var seconds: String
    @State private var finished = false
    @FocusState private var focus: Slot?

    init(initial: TimeInterval, font: Font,
         onCommit: @escaping (TimeInterval) -> Void,
         onCancel: @escaping () -> Void) {
        let total = Int(initial)
        _hours = State(initialValue: String(format: "%02d", total / 3600))
        _minutes = State(initialValue: String(format: "%02d", (total / 60) % 60))
        _seconds = State(initialValue: String(format: "%02d", total % 60))
        self.font = font
        self.onCommit = onCommit
        self.onCancel = onCancel
    }

    var body: some View {
        HStack(spacing: 0) {
            slot($hours, .hours)
            Text(":").font(font)
            slot($minutes, .minutes)
            Text(":").font(font)
            slot($seconds, .seconds)
        }
        .onSubmit(commit)
        .onExitCommand {
            finished = true
            onCancel()
        }
        .onAppear { focus = .hours }
        .onChange(of: focus) { _, new in
            guard new == nil else { return }
            // Focus passes through nil briefly when moving between slots.
            DispatchQueue.main.async { if focus == nil { commit() } }
        }
    }

    private func slot(_ text: Binding<String>, _ which: Slot) -> some View {
        TextField("00", text: text)
            .textFieldStyle(.plain)
            .font(font)
            .multilineTextAlignment(.center)
            .frame(width: 62)
            .focused($focus, equals: which)
            .onChange(of: text.wrappedValue) { _, new in
                let digits = String(new.filter(\.isNumber).prefix(2))
                if digits != new { text.wrappedValue = digits }
                if digits.count == 2, focus == which, which != .seconds { move(1) }
            }
            .onKeyPress(.leftArrow) { move(-1); return .handled }
            .onKeyPress(.rightArrow) { move(1); return .handled }
            .onKeyPress(.tab) {
                move(NSEvent.modifierFlags.contains(.shift) ? -1 : 1)
                return .handled
            }
    }

    private func move(_ delta: Int) {
        let all = Slot.allCases
        let current = focus?.rawValue ?? 0
        focus = all[(current + delta + all.count) % all.count]
    }

    private func commit() {
        guard !finished else { return }
        finished = true
        let h = Double(hours) ?? 0, m = Double(minutes) ?? 0, s = Double(seconds) ?? 0
        onCommit(h * 3600 + m * 60 + s)
    }
}

/// Frosted window background.
struct VisualEffectBackground: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let v = NSVisualEffectView()
        v.material = .underWindowBackground
        v.blendingMode = .behindWindow
        v.state = .active
        return v
    }
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}

/// Applies window-level settings SwiftUI does not expose.
struct WindowConfigurator: NSViewRepresentable {
    var alwaysOnTop: Bool

    func makeNSView(context: Context) -> NSView {
        let v = NSView()
        DispatchQueue.main.async { apply(v.window) }
        // SwiftUI focuses the first text field on launch, which selects a stopwatch name. Clear it once.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { v.window?.makeFirstResponder(nil) }
        return v
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async { apply(nsView.window) }
    }

    private static let closeHider = CloseHider()

    private func apply(_ window: NSWindow?) {
        guard let window else { return }
        MainWindow.window = window
        if let close = window.standardWindowButton(.closeButton) {
            close.target = Self.closeHider
            close.action = #selector(CloseHider.hide(_:))
        }
        window.level = alwaysOnTop ? .floating : .normal
        window.collectionBehavior = alwaysOnTop ? [.canJoinAllSpaces, .fullScreenAuxiliary] : []
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true
    }
}
