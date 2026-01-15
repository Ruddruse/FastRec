import SwiftUI

struct RecordButton: View {
    let state: RecordingState
    let action: () -> Void

    private let buttonSize: CGFloat = 28
    private let innerSize: CGFloat = 22

    var body: some View {
        Button(action: action) {
            ZStack {
                // Outer ring
                Circle()
                    .stroke(Color.red, lineWidth: 1.5)
                    .frame(width: buttonSize, height: buttonSize)

                // Inner shape (changes based on state)
                innerContent
            }
        }
        .buttonStyle(.plain)
        .contentShape(Circle())
    }

    @ViewBuilder
    private var innerContent: some View {
        switch state {
        case .idle:
            // Circle for record
            Circle()
                .fill(Color.red)
                .frame(width: innerSize, height: innerSize)
        case .recording:
            // Rounded square for stop
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.red)
                .frame(width: 8, height: 8)
        case .recorded:
            // Triangle for play
            PlayTriangle()
                .fill(Color.red)
                .frame(width: 10, height: 10)
        case .playing:
            // Square for stop
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.red)
                .frame(width: 8, height: 8)
        }
    }
}

// Custom triangle shape for play button
struct PlayTriangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        // Offset slightly to the right to visually center the play icon
        let offsetX: CGFloat = rect.width * 0.1
        path.move(to: CGPoint(x: rect.minX + offsetX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX + offsetX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.minX + offsetX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

// Preview
struct RecordButton_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            RecordButton(state: .idle) {}
            RecordButton(state: .recording) {}
            RecordButton(state: .recorded) {}
            RecordButton(state: .playing) {}
        }
        .padding()
        .background(Color(white: 0.1))
    }
}
