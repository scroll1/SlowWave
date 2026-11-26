import AppKit
import AudioSlowDownCore
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}

@main
struct AudioSlowDownApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var engine = AudioPlayerEngine()
    @State private var isImporterPresented = false

    var body: some Scene {
        WindowGroup("SlowWave") {
            ContentView(engine: engine, isImporterPresented: $isImporterPresented)
                .onOpenURL { url in
                    engine.loadFile(url: url)
                }
                .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) { _ in
                    engine.cleanupTemporaryFile()
                }
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About SlowWave") {
                    let credits = NSMutableAttributedString(
                        string: "Made by BrennanLabs\nPitch-preserving audio speed player for macOS.\nLicensed under the MIT License.",
                        attributes: [
                            .font: NSFont.systemFont(ofSize: 11),
                            .foregroundColor: NSColor.secondaryLabelColor
                        ]
                    )
                    let paragraphStyle = NSMutableParagraphStyle()
                    paragraphStyle.alignment = .center
                    credits.addAttribute(
                        .paragraphStyle,
                        value: paragraphStyle,
                        range: NSRange(location: 0, length: credits.length)
                    )

                    NSApp.orderFrontStandardAboutPanel(options: [
                        .credits: credits
                    ])
                }
            }

            CommandGroup(replacing: .newItem) {
                Button("Open Audio File…") {
                    isImporterPresented = true
                }
                .keyboardShortcut("o", modifiers: .command)
            }

            CommandMenu("Playback") {
                Button(engine.isPlaying ? "Pause" : "Play") {
                    engine.togglePlayPause()
                }
                .disabled(!engine.hasFileLoaded)

                Divider()

                Button("Skip Back 5 Seconds") {
                    engine.skip(by: -5)
                }
                .keyboardShortcut(.leftArrow, modifiers: .command)
                .disabled(!engine.hasFileLoaded)

                Button("Skip Forward 5 Seconds") {
                    engine.skip(by: 5)
                }
                .keyboardShortcut(.rightArrow, modifiers: .command)
                .disabled(!engine.hasFileLoaded)

                Divider()

                Button("Slower (-5%)") {
                    engine.adjustRate(by: -0.05)
                }
                .keyboardShortcut("-", modifiers: .command)

                Button("Faster (+5%)") {
                    engine.adjustRate(by: 0.05)
                }
                .keyboardShortcut("+", modifiers: .command)

                Button("Reset Speed (1.0×)") {
                    engine.resetRate()
                }
                .keyboardShortcut("0", modifiers: .command)
            }
        }
    }
}
