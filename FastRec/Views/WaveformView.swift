import SwiftUI

struct WaveformView: View {
    let samples: [Float]
    let state: RecordingState

    private let dotCount = 50
    private let dotSize: CGFloat = 3
    private let dotSpacing: CGFloat = 1.5

    var body: some View {
        GeometryReader { geometry in
            HStack(alignment: .center, spacing: dotSpacing) {
                ForEach(0..<dotCount, id: \.self) { index in
                    WaveformDot(
                        amplitude: amplitudeForIndex(index),
                        isActive: state == .recording || state == .playing,
                        baseSize: dotSize
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
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
            // Normalize and clamp the amplitude
            let amplitude = min(1.0, max(0.3, CGFloat(abs(samples[sampleIndex])) * 2))
            return amplitude
        }

        return 0.5
    }
}

struct WaveformDot: View {
    let amplitude: CGFloat
    let isActive: Bool
    let baseSize: CGFloat

    @State private var animatedAmplitude: CGFloat = 0.5

    var body: some View {
        Circle()
            .fill(Color.red)
            .frame(width: dotWidth, height: dotWidth)
            .animation(.easeInOut(duration: 0.1), value: animatedAmplitude)
            .onAppear {
                animatedAmplitude = amplitude
            }
            .onChange(of: amplitude) { _, newValue in
                animatedAmplitude = newValue
            }
    }

    private var dotWidth: CGFloat {
        // Scale dot size based on amplitude (min 2, max baseSize)
        let size = max(2, baseSize * animatedAmplitude)
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
