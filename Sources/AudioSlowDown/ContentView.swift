import AudioSlowDownCore
import SwiftUI
import UniformTypeIdentifiers

// MARK: - Glass Surface Modifier

private struct GlassCardModifier: ViewModifier {
    var cornerRadius: CGFloat = 18

    func body(content: Content) -> some View {
        content
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.12),
                                        Color.white.opacity(0.02)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )
            }
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.32),
                                Color.white.opacity(0.08),
                                Color.white.opacity(0.14)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            }
            .shadow(color: Color.black.opacity(0.14), radius: 14, x: 0, y: 6)
    }
}

private extension View {
    func glassCard(cornerRadius: CGFloat = 18) -> some View {
        modifier(GlassCardModifier(cornerRadius: cornerRadius))
    }
}

// MARK: - Main Content View

struct ContentView: View {
    @Bindable var engine: AudioPlayerEngine
    @Binding var isImporterPresented: Bool

    @State private var isDropTargeted = false

    private static let supportedAudioTypes: [UTType] = [
        .audio,
        .mp3,
        .mpeg4Audio,
        .wav,
        .aiff
    ]

    var body: some View {
        ZStack {
            ambientGlassBackdrop

            VStack(spacing: 16) {
                headerSection

                if engine.hasFileLoaded {
                    playerSection
                } else {
                    emptyDropZone
                }

                speedSection

                footerSection
            }
            .padding(.horizontal, 22)
            .padding(.top, 42)
            .padding(.bottom, 18)
        }
        .frame(minWidth: 600, idealWidth: 640, minHeight: 484)
        .overlay {
            if isDropTargeted {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [.cyan, .blue, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 2.5, dash: [8, 5])
                    )
                    .background(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(Color.cyan.opacity(0.10))
                    )
                    .padding(10)
                    .allowsHitTesting(false)
            }
        }
        .onDrop(of: [.fileURL], isTargeted: $isDropTargeted) { providers in
            handleDrop(providers: providers)
        }
        .fileImporter(
            isPresented: $isImporterPresented,
            allowedContentTypes: Self.supportedAudioTypes,
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    engine.loadFile(url: url)
                }
            case .failure(let error):
                print("File import error: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Ambient Backdrop

    private var ambientGlassBackdrop: some View {
        ZStack {
            Rectangle()
                .fill(.ultraThinMaterial)

            RadialGradient(
                colors: [
                    Color.cyan.opacity(0.20),
                    Color.blue.opacity(0.08),
                    Color.clear
                ],
                center: .topLeading,
                startRadius: 20,
                endRadius: 380
            )

            RadialGradient(
                colors: [
                    Color.indigo.opacity(0.22),
                    Color.purple.opacity(0.10),
                    Color.clear
                ],
                center: .bottomTrailing,
                startRadius: 30,
                endRadius: 420
            )
        }
        .ignoresSafeArea()
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack(alignment: .center, spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color.cyan.opacity(0.85), Color.indigo.opacity(0.95)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 38, height: 38)
                    .overlay(
                        RoundedRectangle(cornerRadius: 11, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.35), lineWidth: 1)
                    )
                    .shadow(color: Color.cyan.opacity(0.35), radius: 8, x: 0, y: 3)

                Image(systemName: "waveform")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(engine.hasFileLoaded ? engine.fileName : "SlowWave")
                    .font(.title3.weight(.semibold))
                    .lineLimit(1)
                    .truncationMode(.middle)

                HStack(spacing: 8) {
                    Label("Pitch Locked · 0 st", systemImage: "lock.fill")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.primary.opacity(0.82))
                        .padding(.horizontal, 9)
                        .padding(.vertical, 3)
                        .background(.thinMaterial, in: Capsule())
                        .overlay(
                            Capsule()
                                .strokeBorder(Color.white.opacity(0.22), lineWidth: 0.75)
                        )

                    if engine.hasFileLoaded {
                        Text(TimeFormatting.format(engine.duration))
                            .font(.caption.monospacedDigit().weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()

            Button {
                isImporterPresented = true
            } label: {
                Label("Open Audio", systemImage: "folder.badge.plus")
                    .font(.subheadline.weight(.medium))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.plain)
            .background(.regularMaterial, in: Capsule())
            .overlay(
                Capsule()
                    .strokeBorder(Color.white.opacity(0.25), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.10), radius: 6, x: 0, y: 2)
        }
    }

    // MARK: - Empty Drop Zone

    private var emptyDropZone: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.cyan.opacity(0.25), Color.indigo.opacity(0.25)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 66, height: 66)
                    .overlay(
                        Circle()
                            .strokeBorder(Color.white.opacity(0.28), lineWidth: 1)
                    )

                Image(systemName: "waveform.badge.plus")
                    .font(.system(size: 28, weight: .medium))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.cyan, .blue],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }

            Text("Drop an audio file to slow it down")
                .font(.headline)

            Text("MP3, M4A, WAV, AIFF, FLAC, and CAF · Pitch stays untouched")
                .font(.caption)
                .foregroundStyle(.secondary)

            Button {
                isImporterPresented = true
            } label: {
                Text("Choose Audio File…")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 8)
                    .background(
                        LinearGradient(
                            colors: [Color.cyan, Color.blue, Color.indigo],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        in: Capsule()
                    )
                    .overlay(
                        Capsule()
                            .strokeBorder(Color.white.opacity(0.35), lineWidth: 1)
                    )
                    .shadow(color: Color.blue.opacity(0.35), radius: 10, x: 0, y: 4)
            }
            .buttonStyle(.plain)
            .padding(.top, 2)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 196)
        .glassCard(cornerRadius: 18)
    }

    // MARK: - Player Section

    private var playerSection: some View {
        VStack(spacing: 12) {
            WaveformScrubberView(
                samples: engine.waveformSamples,
                duration: engine.duration,
                currentTime: engine.currentTime,
                loopStart: engine.loopStart,
                loopEnd: engine.loopEnd,
                isLoopEnabled: engine.isLoopEnabled,
                isLoading: engine.isLoadingWaveform
            ) { newTime in
                engine.seek(to: newTime)
            }

            HStack {
                Text(TimeFormatting.format(engine.currentTime))
                    .font(.caption.monospacedDigit().weight(.medium))
                    .foregroundStyle(.secondary)

                Spacer()

                Text("−\(TimeFormatting.format(max(0, engine.duration - engine.currentTime)))")
                    .font(.caption.monospacedDigit().weight(.medium))
                    .foregroundStyle(.secondary)
            }

            // Transport controls
            HStack(spacing: 16) {
                Button {
                    engine.skip(by: -5)
                } label: {
                    HStack(spacing: 7) {
                        Image(systemName: "gobackward.5")
                            .font(.system(size: 16, weight: .semibold))
                        Text("Back 5s")
                            .font(.subheadline.monospacedDigit().weight(.semibold))
                    }
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 16)
                    .frame(height: 40)
                    .background(.regularMaterial, in: Capsule())
                    .overlay(
                        Capsule()
                            .strokeBorder(Color.white.opacity(0.28), lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.12), radius: 6, x: 0, y: 2)
                }
                .buttonStyle(.plain)
                .help("Skip back 5 seconds (⌘←)")

                Button {
                    engine.togglePlayPause()
                } label: {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color.cyan, Color.blue, Color.indigo],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 54, height: 54)
                            .overlay(
                                Circle()
                                    .strokeBorder(Color.white.opacity(0.4), lineWidth: 1)
                            )
                            .shadow(color: Color.blue.opacity(0.45), radius: 12, x: 0, y: 4)

                        Image(systemName: engine.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(.white)
                            .offset(x: engine.isPlaying ? 0 : 1.5)
                    }
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.space, modifiers: [])
                .help("Play / Pause (Space)")

                Button {
                    engine.skip(by: 5)
                } label: {
                    HStack(spacing: 7) {
                        Text("Fwd 5s")
                            .font(.subheadline.monospacedDigit().weight(.semibold))
                        Image(systemName: "goforward.5")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 16)
                    .frame(height: 40)
                    .background(.regularMaterial, in: Capsule())
                    .overlay(
                        Capsule()
                            .strokeBorder(Color.white.opacity(0.28), lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.12), radius: 6, x: 0, y: 2)
                }
                .buttonStyle(.plain)
                .help("Skip forward 5 seconds (⌘→)")
            }

            Divider()
                .opacity(0.25)

            // A-B Loop bar
            HStack(spacing: 8) {
                Label("A–B Loop", systemImage: "repeat")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                glassPillButton(
                    title: engine.loopStart.map { "A · \(TimeFormatting.format($0))" } ?? "Set A",
                    isActive: engine.loopStart != nil
                ) {
                    engine.setLoopStartAtCurrentTime()
                }

                glassPillButton(
                    title: engine.loopEnd.map { "B · \(TimeFormatting.format($0))" } ?? "Set B",
                    isActive: engine.loopEnd != nil
                ) {
                    engine.setLoopEndAtCurrentTime()
                }

                if engine.hasValidLoop {
                    Toggle("Loop", isOn: $engine.isLoopEnabled)
                        .toggleStyle(.switch)
                        .controlSize(.mini)
                        .font(.caption)
                }

                if engine.loopStart != nil || engine.loopEnd != nil {
                    Button("Clear") {
                        engine.clearLoop()
                    }
                    .buttonStyle(.borderless)
                    .controlSize(.small)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }

                Spacer()
            }
        }
        .padding(16)
        .glassCard(cornerRadius: 18)
    }

    // MARK: - Speed Section

    private var speedSection: some View {
        let presetCount = AudioPlayerEngine.speedPresets.count
        let buttonSpacing: CGFloat = 5
        let thumbRadius: CGFloat = 10

        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Label("Playback Speed", systemImage: "gauge.with.dots.needle.33percent")
                    .font(.subheadline.weight(.semibold))

                Spacer()

                Button {
                    engine.adjustRate(by: -0.05)
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Slower by 5% (⌘-)")

                Text(String(format: "%.2f× · %d%%", engine.playbackRate, Int((engine.playbackRate * 100).rounded())))
                    .font(.subheadline.monospacedDigit().weight(.semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.cyan, .blue],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .padding(.horizontal, 10)
                    .padding(.vertical, 3)
                    .background(.thinMaterial, in: Capsule())
                    .overlay(
                        Capsule()
                            .strokeBorder(Color.white.opacity(0.22), lineWidth: 0.75)
                    )
                    .frame(minWidth: 112)

                Button {
                    engine.adjustRate(by: 0.05)
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Faster by 5% (⌘+)")

                Button {
                    engine.resetRate()
                } label: {
                    Text("Reset")
                        .font(.caption.weight(.medium))
                }
                .buttonStyle(.borderless)
                .disabled(abs(engine.playbackRate - 1.0) < 0.005)
                .padding(.leading, 4)
            }

            GeometryReader { geometry in
                let totalWidth = geometry.size.width
                let buttonWidth = (totalWidth - CGFloat(max(0, presetCount - 1)) * buttonSpacing) / CGFloat(max(1, presetCount))
                let sliderInset = max(0, buttonWidth / 2 - thumbRadius)

                VStack(spacing: 10) {
                    Slider(
                        value: Binding(
                            get: { AudioPlayerEngine.sliderPosition(forRate: engine.playbackRate) },
                            set: { engine.playbackRate = AudioPlayerEngine.rate(forSliderPosition: $0) }
                        ),
                        in: 0...Double(max(1, presetCount - 1))
                    )
                    .tint(.cyan)
                    .padding(.horizontal, sliderInset)

                    HStack(spacing: buttonSpacing) {
                        ForEach(AudioPlayerEngine.speedPresets, id: \.self) { preset in
                            let isSelected = abs(engine.playbackRate - preset) < 0.01
                            Button {
                                withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                    engine.playbackRate = preset
                                }
                            } label: {
                                Text(formatPreset(preset))
                                    .font(.caption.monospacedDigit().weight(isSelected ? .semibold : .medium))
                                    .lineLimit(1)
                                    .fixedSize(horizontal: true, vertical: false)
                                    .foregroundStyle(isSelected ? .white : .primary.opacity(0.85))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 6)
                                    .background {
                                        if isSelected {
                                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                                .fill(
                                                    LinearGradient(
                                                        colors: [Color.cyan, Color.blue],
                                                        startPoint: .topLeading,
                                                        endPoint: .bottomTrailing
                                                    )
                                                )
                                                .shadow(color: Color.cyan.opacity(0.35), radius: 6, x: 0, y: 2)
                                        } else {
                                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                                .fill(.thinMaterial)
                                        }
                                    }
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                                            .strokeBorder(
                                                Color.white.opacity(isSelected ? 0.42 : 0.18),
                                                lineWidth: 0.75
                                            )
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .frame(height: 62)
        }
        .padding(16)
        .glassCard(cornerRadius: 18)
    }

    // MARK: - Footer

    private var footerSection: some View {
        HStack(spacing: 10) {
            if let errorMessage = engine.errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.red)
                    .lineLimit(2)
            } else {
                Text("Space: Play/Pause · ⌘←/→: ±5s · ⌘-/+: ±5% · ⌘0: 1.0×")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            HStack(spacing: 8) {
                Button {
                    engine.isMuted.toggle()
                } label: {
                    Image(systemName: volumeIconName)
                        .font(.caption)
                        .frame(width: 18)
                }
                .buttonStyle(.plain)
                .help(engine.isMuted ? "Unmute" : "Mute")

                Slider(
                    value: Binding(
                        get: { Double(engine.isMuted ? 0 : engine.volume) },
                        set: {
                            engine.isMuted = false
                            engine.volume = Float($0)
                        }
                    ),
                    in: 0...1
                )
                .tint(.cyan)
                .controlSize(.small)
                .frame(width: 100)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(.thinMaterial, in: Capsule())
            .overlay(
                Capsule()
                    .strokeBorder(Color.white.opacity(0.18), lineWidth: 0.75)
            )
        }
    }

    // MARK: - Helpers

    private func glassPillButton(title: String, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.caption.monospacedDigit().weight(isActive ? .semibold : .medium))
                .foregroundStyle(isActive ? .white : .primary.opacity(0.85))
                .padding(.horizontal, 9)
                .padding(.vertical, 4)
                .background {
                    if isActive {
                        Capsule()
                            .fill(Color.cyan.opacity(0.75))
                    } else {
                        Capsule()
                            .fill(.thinMaterial)
                    }
                }
                .overlay(
                    Capsule()
                        .strokeBorder(Color.white.opacity(isActive ? 0.4 : 0.18), lineWidth: 0.75)
                )
        }
        .buttonStyle(.plain)
    }

    private var volumeIconName: String {
        if engine.isMuted || engine.volume <= 0.01 {
            return "speaker.slash.fill"
        } else if engine.volume < 0.4 {
            return "speaker.wave.1.fill"
        } else if engine.volume < 0.75 {
            return "speaker.wave.2.fill"
        } else {
            return "speaker.wave.3.fill"
        }
    }

    private func formatPreset(_ preset: Float) -> String {
        if preset == floor(preset) {
            return String(format: "%.1f×", preset)
        }
        let hundredths = Int((preset * 100).rounded()) % 10
        return hundredths == 0 ? String(format: "%.1f×", preset) : String(format: "%.2f×", preset)
    }

    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first(where: { $0.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) }) else {
            return false
        }

        provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
            let url: URL?
            if let data = item as? Data {
                url = URL(dataRepresentation: data, relativeTo: nil)
            } else if let directURL = item as? URL {
                url = directURL
            } else {
                url = nil
            }

            guard let resolvedURL = url else { return }
            Task { @MainActor in
                engine.loadFile(url: resolvedURL)
            }
        }
        return true
    }
}
