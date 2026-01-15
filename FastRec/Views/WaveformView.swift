import SwiftUI

struct WaveformView: View {
    let samples: [Float]
    let state: RecordingState

    private let dotCount = 35
    private let dotSize: CGFloat = 3
    private let dotSpacing: CGFloat = 1.5

    var body: some View {
        GeometryReader { geometry in
            HStack(alignment: .center, spacing: dotSpacing) {
                ForEach(0..<dotCount, id: \.self) { index in
                    WaveformDot(
                        amplitude: amplitudeForIndex(index),
                        isActive: state == .recording || state == .playing,
                        baseSize: dotSize,
                        maxHeight: geometry.size.height
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .clipped()
    }

    private func amplitudeForIndex(_ index: Int) -> CGFloat {
        if state == .idle {
            // Show uniform dots when idle
            return 0.5
        }

        if samples.isEmpty {
            return 0.5
        }

        // Map index to samples array
        let sampleIndex = Int(Float(index) / Float(dotCount) * Float(samples.count))
        if sampleIndex < samples.count {
            // Amplify the signal for better visual feedback
            let rawAmplitude = CGFloat(abs(samples[sampleIndex]))
            // Boost amplitude by 3x and clamp between 0.2 and 1.0
            let amplitude = min(1.0, max(0.2, rawAmplitude * 3.0))
            return amplitude
        }

        return 0.5
    }
}

struct WaveformDot: View {
    let amplitude: CGFloat
    let isActive: Bool
    let baseSize: CGFloat
    let maxHeight: CGFloat

    @State private var animatedAmplitude: CGFloat = 0.5

    var body: some View {
        Group {
            if isActive {
                // When recording/playing, show as dynamic bars
                Capsule()
                    .fill(barColor)
                    .frame(width: barWidth, height: barHeight)
                    .shadow(color: Color.red.opacity(0.6), radius: 2, x: 0, y: 0)
            } else {
                // When idle, show as circle
                Circle()
                    .fill(Color.red.opacity(0.6))
                    .frame(width: dotWidth, height: dotWidth)
            }
        }
        .fixedSize()
        .animation(.spring(response: 0.15, dampingFraction: 0.7), value: animatedAmplitude)
        .onAppear {
            animatedAmplitude = amplitude
        }
        .onChange(of: amplitude) { _, newValue in
            animatedAmplitude = newValue
        }
    }
    
    private var barColor: Color {
        // Brighter color with intensity based on amplitude
        let brightness = 0.7 + (0.3 * animatedAmplitude)
        return Color.red.opacity(brightness)
    }
    
    private var barWidth: CGFloat {
        // Fixed width - won't change
        return 3.5
    }
    
    private var barHeight: CGFloat {
        // Constrain height to container
        // Use power curve to amplify differences
        let amplifiedAmplitude = pow(animatedAmplitude, 0.75)
        
        let minHeight: CGFloat = 6
        let constrainedMaxHeight = min(maxHeight * 0.9, 26) // Stay within 90% of container
        
        let height = minHeight + (constrainedMaxHeight - minHeight) * amplifiedAmplitude
        return height
    }

    private var dotWidth: CGFloat {
        // Larger dots when idle
        let size = max(3, baseSize * animatedAmplitude * 1.2)
        return size
    }
}

// Preview
struct WaveformView_Previews: PreviewProvider {
    static var previews: some View {
        WaveformView(
            samples: (0..<50).map { _ in Float.random(in: 0.1...0.8) },
            state: .recording
        )
        .frame(width: 200, height: 30)
        .background(Color(white: 0.1))
    }
}
