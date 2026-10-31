# Stopwatches

A small native macOS app for running several stopwatches at once.

- Add as many stopwatches as you need. Each has a name, a color and its own controls.
- Double-click a time to set it by hand, with separate hours, minutes and seconds slots.
- Keep the window always on top with the pin button or Shift-Command-T.
- See the running time in the menu bar and control stopwatches from its menu.
- Stopwatches survive a restart. A running stopwatch keeps counting while the app is closed.
- The red close button hides the window. Click the app icon to bring it back.

## Build and run

Requires macOS 14 or later and the Swift toolchain (Xcode or the Command Line Tools).

```sh
./build.sh && open Stopwatches.app
```

`build.sh` builds a release binary and wraps it in `Stopwatches.app`. With only the
Command Line Tools installed, it builds against the 26.5 SDK, because the newest SDK
needs a SwiftUI macro plugin that the tools do not include.

## App icon

`tools/make-icon.swift` draws the icon and writes `Resources/AppIcon.icns`:

```sh
swift tools/make-icon.swift Resources/AppIcon.icns
```
