import SwiftUI

struct WaveformView: View {
    let samples: [Float]
    let state: RecordingState

    private let dotCount = 40
    private let dotSize: CGFloat = 4
    private let dotSpacing: CGFloat = 1

    var body: some View {
        HStack(alignment: .center, spacing: dotSpacing) {
            ForEach(0..<dotCount, id: \.self) { index in
                Circle()
                    .fill(Color.red)
                    .frame(width: dotWidth(for: index), height: dotWidth(for: index))
                    .animation(.easeInOut(duration: 0.1), value: samples.count)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func dotWidth(for index: Int) -> CGFloat {
        max(3, dotSize * amplitude(for: index))
    }

    private func amplitude(for index: Int) -> CGFloat {
        guard state != .idle, !samples.isEmpty else { return 0.5 }

        let sampleIndex = index * samples.count / dotCount
        guard sampleIndex < samples.count else { return 0.5 }

        return min(1.0, max(0.3, CGFloat(abs(samples[sampleIndex])) * 2))
    }
}

#Preview {
    WaveformView(
        samples: (0..<40).map { _ in Float.random(in: 0.1...0.8) },
        state: .recording
    )
    .frame(width: 180, height: 24)
    .background(Color(white: 0.1))
}
