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
        .aiff,
        .movie,
        .mpeg4Movie,
        .quickTimeMovie
    ]

    var body: some View {
        ZStack {
            ambientGlassBackdrop

            VStack(spacing: 16) {
                headerSection

                if engine.isExtractingAudio {
                    extractingCard
                } else if engine.hasFileLoaded {
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

            Text("Drop an audio or video file to slow it down")
                .font(.headline)

            Text("MP3, M4A, WAV, AIFF, FLAC, CAF, plus MP4 & MOV (audio only)")
                .font(.caption)
                .foregroundStyle(.secondary)

            Button {
                isImporterPresented = true
            } label: {
                Text("Choose Audio or Video…")
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

    private var extractingCard: some View {
        VStack(spacing: 12) {
            ProgressView()
                .controlSize(.regular)

            Text("Extracting audio track…")
                .font(.headline)

            Text(engine.fileName)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
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
                isLoading: engine.isLoadingWaveform,
                onSeek: { newTime in
                    engine.seek(to: newTime)
                },
                onMoveLoopStart: { newStart in
                    engine.setLoopStart(newStart)
                },
                onMoveLoopEnd: { newEnd in
                    engine.setLoopEnd(newEnd)
                },
                onEndMoveLoopEnd: {
                    engine.previewLoopEnd()
                }
            )

            HStack {
                Text(TimeFormatting.format(engine.currentTime))
                    .font(.caption.monospacedDigit().weight(.medium))
                    .foregroundStyle(.secondary)

                Spacer()

                Text("−\(TimeFormatting.format(max(0, engine.duration - engine.currentTime)))")
                    .font(.caption.monospacedDigit().weight(.medium))
                    .foregroundStyle(.secondary)
            }

            // Transport controls (+ Start from A & Loop playback settings on the same row)
            HStack(spacing: 12) {
                if engine.hasValidLoop {
                    startFromAPill
                }

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

                if engine.hasValidLoop {
                    loopPill
                }
            }

            Divider()
                .opacity(0.25)

            // A-B Markers bar — Clear A on left of A, Clear B on right of B
            HStack(spacing: 10) {
                if engine.loopStart != nil {
                    clearMarkerPillButton(label: "Clear A", accent: .cyan) {
                        engine.clearLoopStart()
                    }
                }

                markerPillButton(
                    badge: "A",
                    title: engine.loopStart.map { TimeFormatting.format($0) } ?? "Set A",
                    accent: .cyan,
                    isActive: engine.loopStart != nil,
                    onSet: { engine.setLoopStartAtCurrentTime() },
                    onNudgeBack: { engine.nudgeLoopStart(by: -0.2) },
                    onNudgeForward: { engine.nudgeLoopStart(by: 0.2) }
                )
                .help("Set A marker (click < / > to nudge by 0.2s)")

                markerPillButton(
                    badge: "B",
                    title: engine.loopEnd.map { TimeFormatting.format($0) } ?? "Set B",
                    accent: .purple,
                    isActive: engine.loopEnd != nil,
                    onSet: { engine.setLoopEndAtCurrentTime() },
                    onNudgeBack: { engine.nudgeLoopEnd(by: -0.2, preview: true) },
                    onNudgeForward: { engine.nudgeLoopEnd(by: 0.2, preview: true) }
                )
                .help("Set B marker (click < / > or drag B to nudge and preview the cut)")

                if engine.loopEnd != nil {
                    clearMarkerPillButton(label: "Clear B", accent: .purple) {
                        engine.clearLoopEnd()
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 2)
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

    private var startFromAPill: some View {
        Button {
            engine.snapToAOnPause.toggle()
        } label: {
            HStack(spacing: 5) {
                Image(systemName: engine.snapToAOnPause ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 12, weight: .semibold))
                Text("Start from A")
                    .font(.caption.weight(.semibold))
            }
            .foregroundStyle(engine.snapToAOnPause ? .white : .primary.opacity(0.8))
            .padding(.horizontal, 10)
            .frame(height: 30)
            .background {
                if engine.snapToAOnPause {
                    Capsule()
                        .fill(Color.cyan.opacity(0.35))
                        .background(.regularMaterial, in: Capsule())
                } else {
                    Capsule()
                        .fill(.regularMaterial)
                }
            }
            .overlay(
                Capsule()
                    .strokeBorder(
                        engine.snapToAOnPause ? Color.cyan.opacity(0.75) : Color.white.opacity(0.22),
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
        .help("When on, Space/Pause returns to A. Turn off to pause in place while keeping A & B.")
    }

    private var loopPill: some View {
        Button {
            engine.isLoopEnabled.toggle()
        } label: {
            HStack(spacing: 5) {
                Image(systemName: "repeat")
                    .font(.system(size: 11, weight: .semibold))
                Text("Loop")
                    .font(.caption.weight(.semibold))
            }
            .foregroundStyle(engine.isLoopEnabled ? .white : .primary.opacity(0.8))
            .padding(.horizontal, 10)
            .frame(height: 30)
            .background {
                if engine.isLoopEnabled {
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [Color.cyan, Color.blue],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                } else {
                    Capsule()
                        .fill(.regularMaterial)
                }
            }
            .overlay(
                Capsule()
                    .strokeBorder(Color.white.opacity(engine.isLoopEnabled ? 0.42 : 0.22), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .help("Repeat A→B continuously instead of stopping at B")
    }

    private func clearMarkerPillButton(label: String, accent: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: "xmark")
                    .font(.system(size: 9.5, weight: .bold))
                    .foregroundStyle(accent)
                Text(label)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 10)
            .frame(height: 28)
            .background(.thinMaterial, in: Capsule())
            .overlay(
                Capsule()
                    .strokeBorder(Color.white.opacity(0.18), lineWidth: 0.75)
            )
        }
        .buttonStyle(.plain)
    }

    private func markerPillButton(
        badge: String,
        title: String,
        accent: Color,
        isActive: Bool,
        onSet: @escaping () -> Void,
        onNudgeBack: @escaping () -> Void,
        onNudgeForward: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 0) {
            Button(action: onSet) {
                HStack(spacing: 6) {
                    Text(badge)
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(width: 20, height: 20)
                        .background(accent.opacity(isActive ? 1.0 : 0.78), in: Circle())

                    if !isActive {
                        Text(title)
                            .font(.callout.monospacedDigit().weight(.semibold))
                            .foregroundStyle(.primary)
                    }
                }
                .padding(.leading, 7)
                .padding(.trailing, isActive ? 4 : 14)
                .frame(height: 32)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isActive {
                Button(action: onNudgeBack) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 9.5, weight: .bold))
                        .foregroundStyle(.white.opacity(0.85))
                        .frame(width: 22, height: 32)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("Nudge \(badge) earlier by 0.2s")

                Button(action: onSet) {
                    Text(title)
                        .font(.caption.monospacedDigit().weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(height: 32)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("Move \(badge) to current playhead")

                Button(action: onNudgeForward) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9.5, weight: .bold))
                        .foregroundStyle(.white.opacity(0.85))
                        .frame(width: 22, height: 32)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.trailing, 6)
                .help("Nudge \(badge) later by 0.2s")
            }
        }
        .background {
            if isActive {
                Capsule()
                    .fill(accent.opacity(0.32))
                    .background(.regularMaterial, in: Capsule())
            } else {
                Capsule()
                    .fill(.regularMaterial)
            }
        }
        .overlay(
            Capsule()
                .strokeBorder(
                    isActive ? accent.opacity(0.75) : Color.white.opacity(0.24),
                    lineWidth: 1
                )
        )
        .shadow(color: isActive ? accent.opacity(0.28) : Color.black.opacity(0.10), radius: 6, x: 0, y: 2)
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
