import AVFoundation
import CoreVideo
import Foundation

/// Creates tiny deterministic video fixtures for media tests.
enum MediaFixtures {
    struct FixtureError: Error {}

    /// Writes a solid-color H.264 MP4 and returns its URL.
    static func makeVideo(
        lengthSeconds: Double,
        size: CGSize = CGSize(width: 32, height: 32),
        fps: Int32 = 30
    ) async throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("motionstudio-fixture-\(UUID().uuidString).mp4")

        let writer = try AVAssetWriter(outputURL: url, fileType: .mp4)
        let input = AVAssetWriterInput(
            mediaType: .video,
            outputSettings: [
                AVVideoCodecKey: AVVideoCodecType.h264.rawValue,
                AVVideoWidthKey: Int(size.width),
                AVVideoHeightKey: Int(size.height),
            ]
        )
        writer.add(input)

        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: input,
            sourcePixelBufferAttributes: [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
                kCVPixelBufferWidthKey as String: Int(size.width),
                kCVPixelBufferHeightKey as String: Int(size.height),
            ]
        )

        guard writer.startWriting() else { throw FixtureError() }
        writer.startSession(atSourceTime: .zero)

        let frameCount = max(1, Int((Double(fps) * lengthSeconds).rounded()))
        for frame in 0..<frameCount {
            while !input.isReadyForMoreMediaData {
                try await Task.sleep(nanoseconds: 5_000_000)
            }
            let buffer = try makePixelBuffer(width: Int(size.width), height: Int(size.height))
            let time = CMTime(value: CMTimeValue(frame), timescale: fps)
            guard adaptor.append(buffer, withPresentationTime: time) else {
                throw FixtureError()
            }
        }
        input.markAsFinished()

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            writer.finishWriting { continuation.resume() }
        }
        guard writer.status == .completed else { throw FixtureError() }
        return url
    }

    /// Writes a plain-text file masquerading under `fileName`.
    static func makeTextFile(named fileName: String) throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        try Data("not a video".utf8).write(to: url)
        return url
    }

    private static func makePixelBuffer(width: Int, height: Int) throws -> CVPixelBuffer {
        var buffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            width,
            height,
            kCVPixelFormatType_32BGRA,
            nil,
            &buffer
        )
        guard status == kCVReturnSuccess, let buffer else { throw FixtureError() }

        CVPixelBufferLockBaseAddress(buffer, [])
        if let baseAddress = CVPixelBufferGetBaseAddress(buffer) {
            memset(baseAddress, 0x80, CVPixelBufferGetDataSize(buffer))
        }
        CVPixelBufferUnlockBaseAddress(buffer, [])
        return buffer
    }
}
