import SwiftUI

struct WaveformView: View {
    let samples: [Float]
    let state: RecordingState

    private let barCount = 50
    private let barWidth: CGFloat = 3
    private let barSpacing: CGFloat = 2

    var body: some View {
        GeometryReader { geometry in
            HStack(alignment: .center, spacing: barSpacing) {
                ForEach(0..<barCount, id: \.self) { index in
                    WaveformBar(
                        amplitude: amplitudeForIndex(index),
                        isActive: state == .recording || state == .playing,
                        maxHeight: geometry.size.height
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func amplitudeForIndex(_ index: Int) -> CGFloat {
        if state == .idle {
            // Show dots when idle
            return 0.05
        }

        if samples.isEmpty {
            return 0.05
        }

        // Map index to samples array
        let sampleIndex = Int(Float(index) / Float(barCount) * Float(samples.count))
        if sampleIndex < samples.count {
            // Normalize and clamp the amplitude
            let amplitude = min(1.0, max(0.05, CGFloat(abs(samples[sampleIndex])) * 2))
            return amplitude
        }

        return 0.05
    }
}

struct WaveformBar: View {
    let amplitude: CGFloat
    let isActive: Bool
    let maxHeight: CGFloat

    @State private var animatedAmplitude: CGFloat = 0.05

    var body: some View {
        RoundedRectangle(cornerRadius: 1.5)
            .fill(Color.red)
            .frame(width: 3, height: max(4, animatedAmplitude * maxHeight))
            .animation(.easeInOut(duration: 0.1), value: animatedAmplitude)
            .onAppear {
                animatedAmplitude = amplitude
            }
            .onChange(of: amplitude) { _, newValue in
                animatedAmplitude = newValue
            }
    }
}

// Preview
struct WaveformView_Previews: PreviewProvider {
    static var previews: some View {
        WaveformView(
            samples: (0..<50).map { _ in Float.random(in: 0.1...0.8) },
            state: .recording
        )
        .frame(width: 280, height: 60)
        .background(Color(white: 0.1))
    }
}
