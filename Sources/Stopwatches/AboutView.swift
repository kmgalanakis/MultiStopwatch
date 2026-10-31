import SwiftUI
import AppKit

struct AboutView: View {
    private let info = Bundle.main.infoDictionary ?? [:]
    private var version: String { info["CFBundleShortVersionString"] as? String ?? "1.0" }
    private var copyright: String { info["NSHumanReadableCopyright"] as? String ?? "" }

    private static let repo = URL(string: "https://github.com/kmgalanakis/MultiStopwatch")!

    var body: some View {
        VStack(spacing: 16) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 112, height: 112)

            VStack(spacing: 4) {
                Text("MultiStopwatch")
                    .font(.system(size: 26, weight: .semibold, design: .rounded))
                Text("Version \(version)")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Text("Run as many stopwatches as you need, side by side. Keep the window on top of your work and watch the time from the menu bar.")
                .font(.callout)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 10) {
                linkButton("GitHub", systemImage: "chevron.left.forwardslash.chevron.right",
                           url: Self.repo)
                linkButton("Report an Issue", systemImage: "exclamationmark.bubble",
                           url: Self.repo.appendingPathComponent("issues"))
            }

            if !copyright.isEmpty {
                Text(copyright)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 32)
        .padding(.top, 40)
        .padding(.bottom, 24)
        .frame(width: 360)
        .background(VisualEffectBackground())
    }

    private func linkButton(_ title: String, systemImage: String, url: URL) -> some View {
        Button {
            NSWorkspace.shared.open(url)
        } label: {
            Label(title, systemImage: systemImage)
        }
        .buttonStyle(.bordered)
    }
}
