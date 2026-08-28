import AVFoundation
import Foundation
import Vision

enum CameraMonitorError: LocalizedError {
    case permissionDenied
    case permissionRestricted
    case cameraUnavailable
    case inputUnavailable
    case outputUnavailable

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "请在“系统设置 → 隐私与安全性 → 摄像头”中允许 PAPAlu 实时口型使用摄像头。原有实时口型仍可继续使用。"
        case .permissionRestricted:
            return "这台 Mac 当前限制了摄像头访问。原有实时口型仍可继续使用。"
        case .cameraUnavailable:
            return "没有找到可用的摄像头。原有实时口型仍可继续使用。"
        case .inputUnavailable:
            return "无法读取摄像头输入。原有实时口型仍可继续使用。"
        case .outputUnavailable:
            return "无法分析摄像头画面。原有实时口型仍可继续使用。"
        }
    }
}

final class CameraMonitor: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    typealias SampleHandler = (HandPoseSample) -> Void

    static let analysisFramesPerSecond = 12.0

    private let session = AVCaptureSession()
    private let output = AVCaptureVideoDataOutput()
    private let sessionQueue = DispatchQueue(label: "papalu.camera.session")
    private let analysisQueue = DispatchQueue(label: "papalu.camera.analysis")
    private let faceRequest = VNDetectFaceRectanglesRequest()
    private let handPoseRequest: VNDetectHumanHandPoseRequest = {
        let request = VNDetectHumanHandPoseRequest()
        request.maximumHandCount = 2
        return request
    }()
    private let onSample: SampleHandler
    private var isConfigured = false
    private var lastAnalysisTime = -Double.greatestFiniteMagnitude

    init(onSample: @escaping SampleHandler) {
        self.onSample = onSample
        super.init()
    }

    func requestAccessAndStart(
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            start(completion: completion)
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                guard let self else { return }
                if granted {
                    self.start(completion: completion)
                } else {
                    completion(.failure(CameraMonitorError.permissionDenied))
                }
            }
        case .denied:
            completion(.failure(CameraMonitorError.permissionDenied))
        case .restricted:
            completion(.failure(CameraMonitorError.permissionRestricted))
        @unknown default:
            completion(.failure(CameraMonitorError.permissionDenied))
        }
    }

    func stop() {
        sessionQueue.async { [session] in
            if session.isRunning {
                session.stopRunning()
            }
        }
    }

    private func start(completion: @escaping (Result<Void, Error>) -> Void) {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            do {
                try self.configureIfNeeded()
                if !self.session.isRunning {
                    self.session.startRunning()
                }
                completion(.success(()))
            } catch {
                completion(.failure(error))
            }
        }
    }

    private func configureIfNeeded() throws {
        guard !isConfigured else { return }
        guard let camera = AVCaptureDevice.default(for: .video) else {
            throw CameraMonitorError.cameraUnavailable
        }

        let input = try AVCaptureDeviceInput(device: camera)
        session.beginConfiguration()
        defer { session.commitConfiguration() }

        if session.canSetSessionPreset(.vga640x480) {
            session.sessionPreset = .vga640x480
        } else if session.canSetSessionPreset(.low) {
            session.sessionPreset = .low
        }

        guard session.canAddInput(input) else {
            throw CameraMonitorError.inputUnavailable
        }
        session.addInput(input)

        output.alwaysDiscardsLateVideoFrames = true
        output.setSampleBufferDelegate(self, queue: analysisQueue)
        guard session.canAddOutput(output) else {
            throw CameraMonitorError.outputUnavailable
        }
        session.addOutput(output)

        if let connection = output.connection(with: .video),
           connection.isVideoMinFrameDurationSupported {
            connection.videoMinFrameDuration = CMTime(
                value: 1,
                timescale: CMTimeScale(Self.analysisFramesPerSecond)
            )
        }

        isConfigured = true
    }

    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        let now = ProcessInfo.processInfo.systemUptime
        let minimumInterval = 1 / Self.analysisFramesPerSecond
        guard now - lastAnalysisTime >= minimumInterval else { return }
        lastAnalysisTime = now

        let handler = VNImageRequestHandler(
            cmSampleBuffer: sampleBuffer,
            orientation: .up,
            options: [:]
        )
        do {
            try handler.perform([faceRequest, handPoseRequest])
            let face = faceRequest.results?.first
            let hand = handPoseRequest.results?.first
            let sample = face.flatMap { face in
                hand.flatMap { hand in
                    Self.makeHandSample(
                      face: face,
                      hand: hand,
                      timestamp: now
                    )
                }
            }
            guard let sample else { return }
            onSample(sample)
        } catch {
            return
        }
    }

    private static func makeHandSample(
        face: VNFaceObservation,
        hand: VNHumanHandPoseObservation,
        timestamp: Double
    ) -> HandPoseSample? {
        guard let wrist = recognizedPoint(.wrist, in: hand) else { return nil }
        let palmJoints: [VNHumanHandPoseObservation.JointName] = [
            .indexMCP,
            .middleMCP,
            .ringMCP,
            .littleMCP,
        ]
        let palmPoints = [wrist] + palmJoints.compactMap {
            recognizedPoint($0, in: hand)
        }

        let pointCount = Double(palmPoints.count)
        let palm = PosePoint(
            x: palmPoints.reduce(0) { $0 + Double($1.location.x) } / pointCount,
            y: palmPoints.reduce(0) { $0 + Double($1.location.y) } / pointCount,
            confidence: Double(wrist.confidence)
        )
        let bounds = face.boundingBox
        return HandPoseSample(
            timestamp: timestamp,
            palm: palm,
            faceBounds: NormalizedRect(
                x: Double(bounds.origin.x),
                y: Double(bounds.origin.y),
                width: Double(bounds.width),
                height: Double(bounds.height)
            )
        )
    }

    private static func recognizedPoint(
        _ name: VNHumanHandPoseObservation.JointName,
        in observation: VNHumanHandPoseObservation
    ) -> VNRecognizedPoint? {
        guard let point = try? observation.recognizedPoint(name),
              point.confidence >= 0.3 else {
            return nil
        }
        return point
    }
}
