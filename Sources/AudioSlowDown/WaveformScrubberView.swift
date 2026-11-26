import AudioSlowDownCore
import SwiftUI

struct WaveformScrubberView: View {
    let samples: [Float]
    let duration: TimeInterval
    let currentTime: TimeInterval
    let loopStart: TimeInterval?
    let loopEnd: TimeInterval?
    let isLoopEnabled: Bool
    let isLoading: Bool
    let onSeek: (TimeInterval) -> Void

    @State private var isDragging = false
    @State private var dragProgress: Double = 0
    @State private var isHovering = false
    @State private var hoverProgress: Double = 0

    private var displayedProgress: Double {
        if isDragging {
            return dragProgress
        }
        guard duration > 0 else { return 0 }
        return min(1, max(0, currentTime / duration))
    }

    var body: some View {
        GeometryReader { geometry in
            let width = max(1, geometry.size.width)
            let height = geometry.size.height

            ZStack(alignment: .leading) {
                // Recessed frosted glass well
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.black.opacity(0.14))
                    )

                // A-B loop highlight region
                if let loopStart, let loopEnd, duration > 0, loopEnd > loopStart {
                    let startX = CGFloat(loopStart / duration) * width
                    let endX = CGFloat(loopEnd / duration) * width
                    let loopWidth = max(2, endX - startX)

                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.cyan.opacity(isLoopEnabled ? 0.24 : 0.08),
                                    Color.indigo.opacity(isLoopEnabled ? 0.20 : 0.06)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: loopWidth, height: height)
                        .offset(x: startX)

                    Rectangle()
                        .fill(Color.cyan.opacity(isLoopEnabled ? 0.9 : 0.4))
                        .frame(width: 2, height: height)
                        .offset(x: startX)

                    Rectangle()
                        .fill(Color.cyan.opacity(isLoopEnabled ? 0.9 : 0.4))
                        .frame(width: 2, height: height)
                        .offset(x: endX - 2)
                }

                if isLoading {
                    ProgressView()
                        .controlSize(.small)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    waveformBars(width: width, height: height)
                }

                // Subtle hover guide line
                if isHovering && !isDragging && duration > 0 {
                    Rectangle()
                        .fill(Color.white.opacity(0.28))
                        .frame(width: 1, height: height - 10)
                        .offset(x: CGFloat(hoverProgress) * (width - 1))
                        .allowsHitTesting(false)
                }

                // Luminous playhead
                Capsule()
                    .fill(Color.white)
                    .frame(width: 2.5, height: height - 12)
                    .shadow(color: Color.cyan.opacity(0.8), radius: 5, x: 0, y: 0)
                    .offset(x: CGFloat(displayedProgress) * (width - 2.5))
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
                    hoverProgress = min(1, max(0, Double(location.x / width)))
                case .ended:
                    isHovering = false
                }
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        guard duration > 0 else { return }
                        isDragging = true
                        let progress = min(1, max(0, Double(value.location.x / width)))
                        dragProgress = progress
                    }
                    .onEnded { value in
                        guard duration > 0 else { return }
                        let progress = min(1, max(0, Double(value.location.x / width)))
                        isDragging = false
                        onSeek(progress * duration)
                    }
            )
        }
        .frame(height: 92)
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
