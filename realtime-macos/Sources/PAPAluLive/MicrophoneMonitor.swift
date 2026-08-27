import AVFoundation

enum MicrophoneMonitorError: LocalizedError {
    case permissionDenied
    case permissionRestricted
    case inputUnavailable

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "请在“系统设置 → 隐私与安全性 → 麦克风”中允许 PAPAlu 实时口型使用麦克风。"
        case .permissionRestricted:
            return "这台 Mac 当前限制了麦克风访问，PAPAlu 将保持闭嘴。"
        case .inputUnavailable:
            return "没有找到可用的麦克风输入，PAPAlu 将保持闭嘴。"
        }
    }
}

final class MicrophoneMonitor {
    typealias SampleHandler = (_ rms: Double, _ duration: Double) -> Void

    private static let tapBufferSize = AVAudioFrameCount(256)

    private let engine = AVAudioEngine()
    private let onSample: SampleHandler
    private var tapInstalled = false

    init(onSample: @escaping SampleHandler) {
        self.onSample = onSample
    }

    func requestAccessAndStart(completion: @escaping (Result<Void, Error>) -> Void) {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            startOnMainQueue(completion: completion)
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .audio) { [weak self] granted in
                guard let self else { return }
                if granted {
                    self.startOnMainQueue(completion: completion)
                } else {
                    DispatchQueue.main.async {
                        completion(.failure(MicrophoneMonitorError.permissionDenied))
                    }
                }
            }
        case .denied:
            completion(.failure(MicrophoneMonitorError.permissionDenied))
        case .restricted:
            completion(.failure(MicrophoneMonitorError.permissionRestricted))
        @unknown default:
            completion(.failure(MicrophoneMonitorError.permissionDenied))
        }
    }

    func stop() {
        if tapInstalled {
            engine.inputNode.removeTap(onBus: 0)
            tapInstalled = false
        }
        engine.stop()
    }

    private func startOnMainQueue(completion: @escaping (Result<Void, Error>) -> Void) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            do {
                try self.start()
                completion(.success(()))
            } catch {
                completion(.failure(error))
            }
        }
    }

    private func start() throws {
        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        guard format.sampleRate > 0, format.channelCount > 0 else {
            throw MicrophoneMonitorError.inputUnavailable
        }

        input.installTap(
            onBus: 0,
            bufferSize: Self.tapBufferSize,
            format: format
        ) { [weak self] buffer, _ in
            guard let self, let rms = Self.calculateRms(buffer) else { return }
            let duration = Double(buffer.frameLength) / buffer.format.sampleRate
            self.onSample(rms, duration)
        }
        tapInstalled = true

        engine.prepare()
        do {
            try engine.start()
        } catch {
            input.removeTap(onBus: 0)
            tapInstalled = false
            throw error
        }
    }

    private static func calculateRms(_ buffer: AVAudioPCMBuffer) -> Double? {
        guard let channelData = buffer.floatChannelData else { return nil }
        let frameCount = Int(buffer.frameLength)
        let channelCount = Int(buffer.format.channelCount)
        guard frameCount > 0, channelCount > 0 else { return nil }

        var sum = 0.0
        for channel in 0..<channelCount {
            let samples = channelData[channel]
            for frame in 0..<frameCount {
                let sample = Double(samples[frame])
                sum += sample * sample
            }
        }

        return sqrt(sum / Double(frameCount * channelCount))
    }
}
