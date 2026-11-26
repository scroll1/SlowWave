import AudioSlowDownCore
import SwiftUI

struct WaveformScrubberView: View {
    private enum DragTarget {
        case playhead
        case markerA
        case markerB
    }

    let samples: [Float]
    let duration: TimeInterval
    let currentTime: TimeInterval
    let loopStart: TimeInterval?
    let loopEnd: TimeInterval?
    let isLoopEnabled: Bool
    let isLoading: Bool
    let onSeek: (TimeInterval) -> Void
    let onMoveLoopStart: (TimeInterval) -> Void
    let onMoveLoopEnd: (TimeInterval) -> Void
    let onEndMoveLoopEnd: () -> Void

    @State private var activeDragTarget: DragTarget?
    @State private var dragProgress: Double = 0
    @State private var isHovering = false
    @State private var hoverX: CGFloat = 0

    private let markerGrabRadius: CGFloat = 12

    private var displayedProgress: Double {
        if activeDragTarget == .playhead {
            return dragProgress
        }
        guard duration > 0 else { return 0 }
        return min(1, max(0, currentTime / duration))
    }

    var body: some View {
        GeometryReader { geometry in
            let width = max(1, geometry.size.width)
            let height = geometry.size.height
            let hoveredTarget = isHovering ? hitTestMarker(at: hoverX, width: width) : nil

            ZStack(alignment: .leading) {
                // Recessed frosted glass well
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.black.opacity(0.14))
                    )

                // A-B shaded region when both markers exist
                if let loopStart, let loopEnd, duration > 0, loopEnd > loopStart {
                    let startX = CGFloat(loopStart / duration) * width
                    let endX = CGFloat(loopEnd / duration) * width
                    let loopWidth = max(2, endX - startX)

                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.cyan.opacity(isLoopEnabled ? 0.24 : 0.14),
                                    Color.indigo.opacity(isLoopEnabled ? 0.20 : 0.10)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: loopWidth, height: height)
                        .offset(x: startX)
                }

                if isLoading {
                    ProgressView()
                        .controlSize(.small)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    waveformBars(width: width, height: height)
                }

                // Subtle hover guide line (hidden while hovering/dragging a marker)
                if isHovering && activeDragTarget == nil && hoveredTarget == nil && duration > 0 {
                    Rectangle()
                        .fill(Color.white.opacity(0.28))
                        .frame(width: 1, height: height - 10)
                        .offset(x: min(max(0, hoverX), width - 1))
                        .allowsHitTesting(false)
                }

                // Luminous playhead
                Capsule()
                    .fill(Color.white)
                    .frame(width: 2.5, height: height - 12)
                    .shadow(color: Color.cyan.opacity(0.8), radius: 5, x: 0, y: 0)
                    .offset(x: CGFloat(displayedProgress) * (width - 2.5))

                // Draggable A & B marker lines with badges
                if let loopStart, duration > 0 {
                    let startX = CGFloat(loopStart / duration) * width
                    let isHighlighted = activeDragTarget == .markerA || (activeDragTarget == nil && hoveredTarget == .markerA)
                    markerLine(label: "A", color: .cyan, x: startX, height: height, totalWidth: width, isHighlighted: isHighlighted)
                }

                if let loopEnd, duration > 0 {
                    let endX = CGFloat(loopEnd / duration) * width
                    let isHighlighted = activeDragTarget == .markerB || (activeDragTarget == nil && hoveredTarget == .markerB)
                    markerLine(label: "B", color: .purple, x: endX, height: height, totalWidth: width, isHighlighted: isHighlighted)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.24),
                                Color.white.opacity(0.06)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 1
                    )
            )
            .contentShape(Rectangle())
            .onContinuousHover { phase in
                switch phase {
                case .active(let location):
                    isHovering = true
                    hoverX = location.x
                case .ended:
                    isHovering = false
                }
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        guard duration > 0 else { return }
                        if activeDragTarget == nil {
                            activeDragTarget = hitTestMarker(at: value.startLocation.x, width: width) ?? .playhead
                        }

                        let progress = min(1, max(0, Double(value.location.x / width)))
                        let targetTime = progress * duration

                        switch activeDragTarget {
                        case .markerA:
                            onMoveLoopStart(targetTime)
                        case .markerB:
                            onMoveLoopEnd(targetTime)
                        case .playhead, .none:
                            dragProgress = progress
                        }
                    }
                    .onEnded { value in
                        guard duration > 0 else { return }
                        let progress = min(1, max(0, Double(value.location.x / width)))
                        let targetTime = progress * duration

                        switch activeDragTarget {
                        case .markerA:
                            onMoveLoopStart(targetTime)
                        case .markerB:
                            onMoveLoopEnd(targetTime)
                            onEndMoveLoopEnd()
                        case .playhead, .none:
                            onSeek(targetTime)
                        }
                        activeDragTarget = nil
                    }
            )
        }
        .frame(height: 92)
    }

    private func hitTestMarker(at x: CGFloat, width: CGFloat) -> DragTarget? {
        guard duration > 0 else { return nil }
        var closest: (target: DragTarget, distance: CGFloat)?

        if let loopStart {
            let dist = abs(x - CGFloat(loopStart / duration) * width)
            if dist <= markerGrabRadius {
                closest = (.markerA, dist)
            }
        }

        if let loopEnd {
            let dist = abs(x - CGFloat(loopEnd / duration) * width)
            if dist <= markerGrabRadius, closest == nil || dist < closest!.distance {
                closest = (.markerB, dist)
            }
        }

        return closest?.target
    }

    @ViewBuilder
    private func markerLine(
        label: String,
        color: Color,
        x: CGFloat,
        height: CGFloat,
        totalWidth: CGFloat,
        isHighlighted: Bool
    ) -> some View {
        let clampedX = min(max(1, x), totalWidth - 2)
        let badgeX = min(max(10, clampedX), totalWidth - 10)

        ZStack(alignment: .topLeading) {
            Rectangle()
                .fill(color.opacity(isHighlighted ? 1.0 : 0.9))
                .frame(width: isHighlighted ? 3 : 2, height: height)
                .shadow(color: isHighlighted ? color.opacity(0.85) : .clear, radius: 4, x: 0, y: 0)
                .offset(x: clampedX - (isHighlighted ? 0.5 : 0))

            Text(label)
                .font(.system(size: 9.5, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .frame(width: 18, height: 15)
                .background(color.opacity(isHighlighted ? 1.0 : 0.92), in: RoundedRectangle(cornerRadius: 4, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .strokeBorder(Color.white.opacity(isHighlighted ? 0.85 : 0.25), lineWidth: 1)
                )
                .scaleEffect(isHighlighted ? 1.16 : 1.0)
                .shadow(color: isHighlighted ? color.opacity(0.6) : .clear, radius: 5, x: 0, y: 0)
                .offset(x: badgeX - 9, y: 4)
        }
        .animation(.easeOut(duration: 0.12), value: isHighlighted)
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private func waveformBars(width: CGFloat, height: CGFloat) -> some View {
        let displaySamples = samples.isEmpty ? Array(repeating: Float(0.18), count: 80) : samples
        let count = displaySamples.count
        let spacing: CGFloat = 2
        let totalSpacing = spacing * CGFloat(max(0, count - 1))
        let barWidth = max(1.5, (width - 20 - totalSpacing) / CGFloat(max(1, count)))
        let maxBarHeight = max(14, height - 22)

        HStack(alignment: .center, spacing: spacing) {
            ForEach(0..<count, id: \.self) { index in
                let barProgress = Double(index) / Double(max(1, count - 1))
                let isPlayed = barProgress <= displayedProgress
                let amplitude = CGFloat(displaySamples[index])

                Capsule()
                    .fill(
                        isPlayed
                            ? AnyShapeStyle(
                                LinearGradient(
                                    colors: [Color.cyan, Color.blue, Color.indigo],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            : AnyShapeStyle(Color.primary.opacity(0.22))
                    )
                    .frame(width: barWidth, height: max(4, amplitude * maxBarHeight))
            }
        }
        .padding(.horizontal, 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
