import SwiftUI

struct Stopwatch: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String
    var colorIndex: Int
    var accumulated: TimeInterval = 0
    var startedAt: Date? = nil

    var isRunning: Bool { startedAt != nil }

    func elapsed(at date: Date = .now) -> TimeInterval {
        accumulated + (startedAt.map { max(0, date.timeIntervalSince($0)) } ?? 0)
    }
}

enum Palette {
    static let colors: [Color] = [
        Color(red: 0.25, green: 0.52, blue: 1.00),
        Color(red: 0.96, green: 0.36, blue: 0.42),
        Color(red: 0.20, green: 0.78, blue: 0.55),
        Color(red: 1.00, green: 0.62, blue: 0.20),
        Color(red: 0.62, green: 0.40, blue: 0.95),
        Color(red: 0.15, green: 0.74, blue: 0.84),
        Color(red: 1.00, green: 0.80, blue: 0.15),
        Color(red: 0.95, green: 0.40, blue: 0.75),
        Color(red: 0.55, green: 0.80, blue: 0.20),
        Color(red: 0.65, green: 0.45, blue: 0.30),
        Color(red: 0.50, green: 0.56, blue: 0.64),
        Color(red: 0.10, green: 0.55, blue: 0.55),
    ]

    static func color(_ index: Int) -> Color {
        colors[((index % colors.count) + colors.count) % colors.count]
    }
}

enum TimeFormat {
    /// Full precision for the stopwatch cards: 00:12:34.56 or 01:02:03.45
    static func full(_ t: TimeInterval) -> String {
        let cs = Int(t * 100)
        let h = cs / 360_000, m = (cs / 6000) % 60, s = (cs / 100) % 60, c = cs % 100
        return String(format: "%02d:%02d:%02d.%02d", h, m, s, c)
    }

    /// Compact form for the menu bar: 00:12:34 or 01:02:03
    static func compact(_ t: TimeInterval) -> String {
        let total = Int(t)
        let h = total / 3600, m = (total / 60) % 60, s = total % 60
        return String(format: "%02d:%02d:%02d", h, m, s)
    }
}
