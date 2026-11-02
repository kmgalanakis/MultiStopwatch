import SwiftUI
import AppKit
import UniformTypeIdentifiers

extension UTType {
    /// Private drag type for reordering cards. Text fields ignore it, unlike plain text.
    static let stopwatchCard = UTType(exportedAs: "com.kmg.stopwatches.card")
}

struct ContentView: View {
    @EnvironmentObject var store: StopwatchStore
    @AppStorage("alwaysOnTop") private var alwaysOnTop = false
    @AppStorage("compactCards") private var compact = false
    @State private var dragging: Stopwatch.ID?

    private var spacing: CGFloat { compact ? 10 : 16 }
    private var columns: [GridItem] {
        [GridItem(.adaptive(minimum: compact ? 360 : 280, maximum: compact ? 500 : 400), spacing: spacing)]
    }

    var body: some View {
        ScrollView {
            if store.stopwatches.isEmpty {
                emptyState
            } else {
                LazyVGrid(columns: columns, spacing: spacing) {
                    ForEach($store.stopwatches) { $watch in
                        StopwatchCard(watch: $watch)
                            .opacity(dragging == watch.id ? 0 : 1)
                            .overlay {
                                if dragging == watch.id { dropPlaceholder.transition(.opacity) }
                            }
                            .onDrag {
                                let id = watch.id
                                // Set after the drag image is taken, so the image still shows the card.
                                DispatchQueue.main.async { dragging = id }
                                let provider = NSItemProvider()
                                provider.registerDataRepresentation(
                                    forTypeIdentifier: UTType.stopwatchCard.identifier,
                                    visibility: .ownProcess
                                ) { completion in
                                    completion(Data(id.uuidString.utf8), nil)
                                    return nil
                                }
                                return provider
                            }
                            .onDrop(of: [.stopwatchCard], delegate: ReorderDropDelegate(
                                target: watch.id, store: store, dragging: $dragging))
                    }
                }
                .padding(compact ? 14 : 20)
                .animation(.easeInOut(duration: 0.2), value: compact)
            }
        }
        .frame(minWidth: 400, minHeight: 240)
        // Accept the drop anywhere in the window, including the gaps between cards,
        // so macOS does not slide the dragged image back to where it started.
        .onDrop(of: [.stopwatchCard], delegate: AcceptDropDelegate(dragging: $dragging))
        .task(id: dragging) {
            // The drag ends when the mouse button is released, whether the card was
            // dropped or the drag was cancelled. Show the card only after macOS has
            // removed the floating drag image, so the two never appear together.
            guard dragging != nil else { return }
            while NSEvent.pressedMouseButtons & 1 != 0 {
                do { try await Task.sleep(for: .milliseconds(50)) } catch { return }
            }
            do { try await Task.sleep(for: .milliseconds(180)) } catch { return }
            withAnimation(.dropSettle) { dragging = nil }
        }
        .background(VisualEffectBackground())
        .background(WindowConfigurator(alwaysOnTop: alwaysOnTop))
        .toolbar {
            ToolbarItemGroup {
                Button { store.add() } label: { Label("New Stopwatch", systemImage: "plus") }
                    .help("Add a stopwatch")
                Button { store.pauseAll() } label: { Label("Pause All", systemImage: "pause.circle") }
                    .help("Pause all running stopwatches")
                    .disabled(store.runningCount == 0)
                Toggle(isOn: $compact) {
                    Label("Compact Cards", systemImage: compact ? "rectangle.grid.1x2.fill" : "rectangle.grid.1x2")
                }
                .help(compact ? "Show full-size cards" : "Show slim, one-line cards")
                Toggle(isOn: $alwaysOnTop) {
                    Label("Always on Top", systemImage: alwaysOnTop ? "pin.fill" : "pin")
                }
                .help(alwaysOnTop ? "Window stays above other windows" : "Keep window above other windows")
            }
        }
    }

    /// Empty slot shown where the dragged card will land.
    private var dropPlaceholder: some View {
        let shape = RoundedRectangle(cornerRadius: compact ? 12 : 18, style: .continuous)
        return shape
            .fill(Color.primary.opacity(0.04))
            .overlay(shape.strokeBorder(Color.primary.opacity(0.2),
                                        style: StrokeStyle(lineWidth: 1.5, dash: [6, 4])))
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

extension Animation {
    /// Quick fade-in for a dropped card.
    static let dropSettle = Animation.easeOut(duration: 0.15)
}

/// Live reordering: as a dragged card passes over another card, the two swap places.
struct ReorderDropDelegate: DropDelegate {
    let target: Stopwatch.ID
    let store: StopwatchStore
    @Binding var dragging: Stopwatch.ID?

    func dropEntered(info: DropInfo) {
        guard let dragging, dragging != target else { return }
        withAnimation(.easeInOut(duration: 0.2)) {
            store.move(dragging, to: target)
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    // The order is already updated; the window shows the card once the drag has ended.
    func performDrop(info: DropInfo) -> Bool { true }
}

/// Accepts a card dropped between cards. The order is already updated while dragging.
struct AcceptDropDelegate: DropDelegate {
    @Binding var dragging: Stopwatch.ID?

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    // The order is already updated; the window shows the card once the drag has ended.
    func performDrop(info: DropInfo) -> Bool { true }
}

struct StopwatchCard: View {
    @EnvironmentObject var store: StopwatchStore
    @Binding var watch: Stopwatch
    @AppStorage("compactCards") private var compact = false
    @State private var hovering = false
    @State private var editing = false

    private var accent: Color { Palette.color(watch.colorIndex) }
    private var cornerRadius: CGFloat { compact ? 12 : 18 }
    private var timeFont: Font {
        .system(size: compact ? 22 : 42, weight: .semibold, design: .rounded).monospacedDigit()
    }

    private func beginEdit() { editing = true }

    var body: some View {
        Group {
            if compact { compactLayout } else { fullLayout }
        }
        .padding(compact ? 10 : 16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(watch.isRunning ? accent.opacity(0.6) : Color.primary.opacity(0.08),
                              lineWidth: watch.isRunning ? 1.5 : 1)
        )
        .shadow(color: .black.opacity(0.08), radius: compact ? 4 : 8, y: compact ? 1 : 2)
        .animation(.easeInOut(duration: 0.2), value: watch.isRunning)
        .onHover { hovering = $0 }
        .contextMenu {
            Button("Set Time…", action: beginEdit)
            Button("Reset") { store.reset(watch.id) }
            Divider()
            Button("Delete", role: .destructive) { store.remove(watch.id) }
        }
    }

    // MARK: Layouts

    private var fullLayout: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                colorDot
                nameField.font(.headline)
                Spacer(minLength: 0)
                deleteButton
            }

            time.frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 10) {
                Button { store.toggle(watch.id) } label: {
                    Image(systemName: watch.isRunning ? "pause.fill" : "play.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .frame(width: 30, height: 30)
                        .background(accent, in: Circle())
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
                .help(watch.isRunning ? "Pause" : (watch.accumulated > 0 ? "Resume" : "Start"))

                resetButton(size: 30)
                Spacer(minLength: 0)
            }
        }
    }

    private var compactLayout: some View {
        HStack(spacing: 8) {
            colorDot
            // The name fills the free space, which stretches every card to the full
            // column width so the times and buttons line up on the right.
            nameField
                .font(.system(size: 13, weight: .semibold))
                .lineLimit(1)
                .frame(minWidth: 90, maxWidth: .infinity, alignment: .leading)
            time.fixedSize()
            Button { store.toggle(watch.id) } label: {
                Image(systemName: watch.isRunning ? "pause.fill" : "play.fill")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 28, height: 28)
                    .background(accent, in: Circle())
            }
            .buttonStyle(.plain)
            .help(watch.isRunning ? "Pause" : "Start")
            resetButton(size: 28)
            deleteButton
        }
    }

    // MARK: Pieces

    private var colorDot: some View {
        Circle()
            .fill(accent)
            .frame(width: 10, height: 10)
            .onTapGesture { watch.colorIndex += 1 }
            .help("Click to change color")
    }

    private var nameField: some View {
        TextField("Name", text: $watch.name)
            .textFieldStyle(.plain)
            .onSubmit {
                // Wait until AppKit finishes handling Return, or it reselects the text.
                DispatchQueue.main.async { NSApp.keyWindow?.makeFirstResponder(nil) }
            }
    }

    private var deleteButton: some View {
        Button { store.remove(watch.id) } label: {
            Image(systemName: "xmark")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
        .help("Delete stopwatch")
        .opacity(hovering ? 1 : 0)
    }

    @ViewBuilder
    private var time: some View {
        if editing {
            TimeEditor(initial: watch.elapsed(), font: timeFont, slotWidth: compact ? 32 : 62) { value in
                store.setElapsed(watch.id, to: value)
                editing = false
            } onCancel: {
                editing = false
            }
        } else {
            TimelineView(.animation(minimumInterval: 1.0 / 30, paused: !watch.isRunning)) { context in
                Text(TimeFormat.full(watch.elapsed(at: context.date)))
                    .font(timeFont)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .foregroundStyle(watch.isRunning ? accent : .primary)
            }
            .contentShape(Rectangle())
            // No double-click handler here: one would delay every single click.
            .onTapGesture { store.toggle(watch.id) }
            .help("Click to start or pause. Right-click to set the time")
        }
    }

    private func resetButton(size: CGFloat) -> some View {
        Button { store.reset(watch.id) } label: {
            Image(systemName: "arrow.counterclockwise")
                .font(.system(size: size >= 30 ? 12 : 11, weight: .semibold))
                .frame(width: size, height: size)
                .background(.quaternary, in: Circle())
        }
        .buttonStyle(.plain)
        .help("Reset to zero")
        .disabled(watch.elapsed() == 0)
    }
}

/// Three-slot editor (hours : minutes : seconds). Tab, Shift-Tab and the arrow keys
/// move between slots, and the cursor jumps ahead after two digits. Return saves,
/// Escape cancels, and clicking away saves.
struct TimeEditor: View {
    let font: Font
    let slotWidth: CGFloat
    let onCommit: (TimeInterval) -> Void
    let onCancel: () -> Void

    private enum Slot: Int, CaseIterable { case hours, minutes, seconds }

    @State private var hours: String
    @State private var minutes: String
    @State private var seconds: String
    @State private var finished = false
    @FocusState private var focus: Slot?

    init(initial: TimeInterval, font: Font, slotWidth: CGFloat = 62,
         onCommit: @escaping (TimeInterval) -> Void,
         onCancel: @escaping () -> Void) {
        let total = Int(initial)
        _hours = State(initialValue: String(format: "%02d", total / 3600))
        _minutes = State(initialValue: String(format: "%02d", (total / 60) % 60))
        _seconds = State(initialValue: String(format: "%02d", total % 60))
        self.font = font
        self.slotWidth = slotWidth
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
            .frame(width: slotWidth)
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
        // Off so dragging a card reorders it instead of moving the window.
        window.isMovableByWindowBackground = false
    }
}
