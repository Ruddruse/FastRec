import Foundation
import ScreenCaptureKit
import AVFoundation
import CoreMedia

class SystemAudioCapture: NSObject, @unchecked Sendable {
    private var stream: SCStream?
    private var streamOutput: AudioStreamOutput?

    // Callbacks
    var onAudioSamples: (([Float]) -> Void)?
    var onAudioBuffer: ((AVAudioPCMBuffer) -> Void)?

    // Target format: 44.1kHz stereo
    private let targetSampleRate: Double = 44100
    private let targetChannelCount: AVAudioChannelCount = 2

    private var audioConverter: AVAudioConverter?
    private var inputFormat: AVAudioFormat?
    private var outputFormat: AVAudioFormat?

    override init() {
        super.init()
        setupOutputFormat()
    }

    private func setupOutputFormat() {
        outputFormat = AVAudioFormat(
            standardFormatWithSampleRate: targetSampleRate,
            channels: targetChannelCount
        )
    }

    func startCapture() async throws {
        // Get available content
        let availableContent: SCShareableContent
        do {
            availableContent = try await SCShareableContent.current
        } catch {
            print("Failed to get shareable content: \(error)")
            // Check if it's a permission error
            if (error as NSError).domain == "com.apple.screencapturekit" {
                throw CaptureError.permissionDenied
            }
            throw error
        }

        guard let display = availableContent.displays.first else {
            throw CaptureError.noDisplayFound
        }

        // Create filter - we need a display but won't capture video
        let filter = SCContentFilter(display: display, excludingWindows: [])

        // Configure for audio-only capture
        let config = SCStreamConfiguration()
        config.capturesAudio = true
        config.sampleRate = 48000  // ScreenCaptureKit typically delivers 48kHz
        config.channelCount = 2
        config.excludesCurrentProcessAudio = true  // Avoid feedback loops

        // Disable video capture
        config.width = 2
        config.height = 2
        config.minimumFrameInterval = CMTime(value: 1, timescale: 1)  // 1 fps minimum
        config.showsCursor = false

        // Create stream
        stream = SCStream(filter: filter, configuration: config, delegate: self)

        // Create and add stream output
        streamOutput = AudioStreamOutput(
            onSamples: { [weak self] samples in
                self?.onAudioSamples?(samples)
            },
            onBuffer: { [weak self] buffer in
                self?.processAndForwardBuffer(buffer)
            }
        )

        guard let streamOutput = streamOutput else {
            throw CaptureError.failedToCreateOutput
        }

        try stream?.addStreamOutput(
            streamOutput,
            type: .audio,
            sampleHandlerQueue: DispatchQueue(label: "com.fastrec.audio", qos: .userInteractive)
        )

        // Start capturing
        do {
            try await stream?.startCapture()
        } catch {
            print("Failed to start capture: \(error)")
            throw CaptureError.permissionDenied
        }
    }

    func stopCapture() async {
        do {
            try await stream?.stopCapture()
        } catch {
            print("Error stopping capture: \(error)")
        }
        stream = nil
        streamOutput = nil
        audioConverter = nil
    }

    private func processAndForwardBuffer(_ buffer: AVAudioPCMBuffer) {
        // Convert sample rate if needed
        guard let outputFormat = outputFormat else {
            onAudioBuffer?(buffer)
            return
        }

        let inputFormat = buffer.format

        // Check if conversion is needed
        if inputFormat.sampleRate == outputFormat.sampleRate {
            onAudioBuffer?(buffer)
            return
        }

        // Create converter if needed or if format changed
        if audioConverter == nil || self.inputFormat != inputFormat {
            self.inputFormat = inputFormat
            audioConverter = AVAudioConverter(from: inputFormat, to: outputFormat)
        }

        guard let converter = audioConverter else {
            onAudioBuffer?(buffer)
            return
        }

        // Calculate output frame count
        let ratio = outputFormat.sampleRate / inputFormat.sampleRate
        let outputFrameCount = AVAudioFrameCount(Double(buffer.frameLength) * ratio)

        guard let outputBuffer = AVAudioPCMBuffer(
            pcmFormat: outputFormat,
            frameCapacity: outputFrameCount
        ) else {
            onAudioBuffer?(buffer)
            return
        }

        var error: NSError?
        var inputBufferConsumed = false

        let status = converter.convert(to: outputBuffer, error: &error) { inNumPackets, outStatus in
            if inputBufferConsumed {
                outStatus.pointee = .noDataNow
                return nil
            }
            inputBufferConsumed = true
            outStatus.pointee = .haveData
            return buffer
        }

        if status == .haveData || status == .inputRanDry {
            onAudioBuffer?(outputBuffer)
        } else if let error = error {
            print("Conversion error: \(error)")
            onAudioBuffer?(buffer)
        }
    }
}

// MARK: - SCStreamDelegate
extension SystemAudioCapture: SCStreamDelegate {
    func stream(_ stream: SCStream, didStopWithError error: Error) {
        print("Stream stopped with error: \(error)")
    }
}

// MARK: - Stream Output Handler
private class AudioStreamOutput: NSObject, SCStreamOutput {
    let onSamples: ([Float]) -> Void
    let onBuffer: (AVAudioPCMBuffer) -> Void

    init(onSamples: @escaping ([Float]) -> Void, onBuffer: @escaping (AVAudioPCMBuffer) -> Void) {
        self.onSamples = onSamples
        self.onBuffer = onBuffer
    }

    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .audio else { return }

        // Extract audio buffer
        guard let audioBuffer = createPCMBuffer(from: sampleBuffer) else { return }

        // Extract samples for waveform visualization
        let samples = extractSamples(from: audioBuffer)
        onSamples(samples)

        // Forward buffer for recording
        onBuffer(audioBuffer)
    }

    private func createPCMBuffer(from sampleBuffer: CMSampleBuffer) -> AVAudioPCMBuffer? {
        guard let formatDescription = CMSampleBufferGetFormatDescription(sampleBuffer),
              let asbd = CMAudioFormatDescriptionGetStreamBasicDescription(formatDescription) else {
            return nil
        }

        guard let format = AVAudioFormat(streamDescription: asbd) else {
            return nil
        }

        let frameCount = CMSampleBufferGetNumSamples(sampleBuffer)
        guard let pcmBuffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(frameCount)) else {
            return nil
        }

        pcmBuffer.frameLength = AVAudioFrameCount(frameCount)

        // Copy audio data
        guard let blockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer) else {
            return nil
        }

        var dataPointer: UnsafeMutablePointer<Int8>?
        var lengthAtOffset: Int = 0
        var totalLength: Int = 0

        let status = CMBlockBufferGetDataPointer(
            blockBuffer,
            atOffset: 0,
            lengthAtOffsetOut: &lengthAtOffset,
            totalLengthOut: &totalLength,
            dataPointerOut: &dataPointer
        )

        guard status == kCMBlockBufferNoErr, let dataPointer = dataPointer else {
            return nil
        }

        // Copy to PCM buffer
        if let floatChannelData = pcmBuffer.floatChannelData {
            let channelCount = Int(format.channelCount)
            let bytesPerFrame = Int(asbd.pointee.mBytesPerFrame)

            if asbd.pointee.mFormatFlags & kAudioFormatFlagIsFloat != 0 {
                // Float format - direct copy
                memcpy(floatChannelData[0], dataPointer, totalLength)
            } else {
                // Convert from int to float if needed
                let int16Pointer = UnsafeRawPointer(dataPointer).bindMemory(to: Int16.self, capacity: frameCount * channelCount)
                for i in 0..<frameCount * channelCount {
                    floatChannelData[0][i] = Float(int16Pointer[i]) / Float(Int16.max)
                }
            }
        }

        return pcmBuffer
    }

    private func extractSamples(from buffer: AVAudioPCMBuffer) -> [Float] {
        guard let channelData = buffer.floatChannelData else { return [] }

        let frameCount = Int(buffer.frameLength)
        let channelCount = Int(buffer.format.channelCount)

        // Downsample for visualization (take every Nth sample)
        let targetSamples = 10
        let step = max(1, frameCount / targetSamples)

        var samples: [Float] = []

        for i in stride(from: 0, to: frameCount, by: step) {
            // Average across channels
            var sum: Float = 0
            for channel in 0..<channelCount {
                sum += abs(channelData[channel][i])
            }
            samples.append(sum / Float(channelCount))
        }

        return samples
    }
}

// MARK: - Errors
enum CaptureError: Error {
    case noDisplayFound
    case failedToCreateOutput
    case permissionDenied
}
