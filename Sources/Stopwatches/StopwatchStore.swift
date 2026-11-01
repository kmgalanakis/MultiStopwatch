import SwiftUI

@MainActor
final class StopwatchStore: ObservableObject {
    @Published var stopwatches: [Stopwatch] {
        didSet { save() }
    }
    /// Text shown next to the icon in the menu bar. Empty when nothing is running.
    @Published private(set) var menuTitle = ""

    private static let defaultsKey = "stopwatches.v1"
    private var timer: Timer?

    init() {
        if let data = UserDefaults.standard.data(forKey: Self.defaultsKey),
           let saved = try? JSONDecoder().decode([Stopwatch].self, from: data) {
            stopwatches = saved
        } else {
            stopwatches = [Stopwatch(name: "Stopwatch 1", colorIndex: 0)]
        }
        refreshMenuTitle()
        let t = Timer(timeInterval: 0.25, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refreshMenuTitle() }
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    var runningCount: Int { stopwatches.filter(\.isRunning).count }

    func add() {
        let index = stopwatches.count
        stopwatches.append(Stopwatch(name: "Stopwatch \(index + 1)", colorIndex: index))
        refreshMenuTitle()
    }

    func toggle(_ id: Stopwatch.ID) {
        guard let i = stopwatches.firstIndex(where: { $0.id == id }) else { return }
        if let start = stopwatches[i].startedAt {
            stopwatches[i].accumulated += Date().timeIntervalSince(start)
            stopwatches[i].startedAt = nil
        } else {
            stopwatches[i].startedAt = Date()
        }
        refreshMenuTitle()
    }

    func reset(_ id: Stopwatch.ID) {
        guard let i = stopwatches.firstIndex(where: { $0.id == id }) else { return }
        stopwatches[i].accumulated = 0
        if stopwatches[i].isRunning { stopwatches[i].startedAt = Date() }
        refreshMenuTitle()
    }

    func setElapsed(_ id: Stopwatch.ID, to seconds: TimeInterval) {
        guard let i = stopwatches.firstIndex(where: { $0.id == id }) else { return }
        stopwatches[i].accumulated = seconds
        if stopwatches[i].isRunning { stopwatches[i].startedAt = Date() }
        refreshMenuTitle()
    }

    func remove(_ id: Stopwatch.ID) {
        stopwatches.removeAll { $0.id == id }
        refreshMenuTitle()
    }

    func pauseAll() {
        let now = Date()
        for i in stopwatches.indices {
            if let start = stopwatches[i].startedAt {
                stopwatches[i].accumulated += now.timeIntervalSince(start)
                stopwatches[i].startedAt = nil
            }
        }
        refreshMenuTitle()
    }

    /// Moves a stopwatch into another one's position. Used for drag and drop reordering.
    func move(_ id: Stopwatch.ID, to target: Stopwatch.ID) {
        guard let from = stopwatches.firstIndex(where: { $0.id == id }),
              let to = stopwatches.firstIndex(where: { $0.id == target }),
              from != to else { return }
        stopwatches.move(fromOffsets: IndexSet(integer: from), toOffset: to > from ? to + 1 : to)
        refreshMenuTitle()
    }

    private func refreshMenuTitle() {
        let running = stopwatches.filter(\.isRunning)
        var title = ""
        if let first = running.first {
            title = TimeFormat.compact(first.elapsed())
            if running.count > 1 { title += " +\(running.count - 1)" }
        }
        if title != menuTitle { menuTitle = title }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(stopwatches) {
            UserDefaults.standard.set(data, forKey: Self.defaultsKey)
        }
    }
}
