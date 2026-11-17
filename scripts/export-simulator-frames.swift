import AVFoundation
import Darwin
import Foundation
import ImageIO
import UniformTypeIdentifiers

struct FrameRequest: Decodable {
    let seconds: Double
    let output: String
}

func exportFrames() async throws {
    let arguments = CommandLine.arguments
    guard arguments.count == 3 else {
        throw NSError(domain: "SimulatorFrameExport", code: 1, userInfo: [NSLocalizedDescriptionKey: "Expected a simulator movie and frame request file"])
    }
    let asset = AVURLAsset(url: URL(fileURLWithPath: arguments[1]))
    let loadedDuration = try await asset.load(.duration)
    let duration = loadedDuration.seconds
    let requests = try JSONDecoder().decode([FrameRequest].self, from: Data(contentsOf: URL(fileURLWithPath: arguments[2])))
    guard duration.isFinite, duration > 0 else {
        throw NSError(domain: "SimulatorFrameExport", code: 2, userInfo: [NSLocalizedDescriptionKey: "Simulator movie has no finite positive duration"])
    }
    for request in requests {
        guard request.seconds.isFinite, request.seconds >= 0, request.seconds < duration else {
            let message = "Frame request \(request.seconds)s is outside movie duration \(duration)s"
            throw NSError(domain: "SimulatorFrameExport", code: 3, userInfo: [NSLocalizedDescriptionKey: message])
        }
    }
    let generator = AVAssetImageGenerator(asset: asset)
    generator.appliesPreferredTrackTransform = true
    generator.requestedTimeToleranceBefore = .zero
    generator.requestedTimeToleranceAfter = .zero
    for request in requests {
        let frame = try await generator.image(at: CMTime(seconds: request.seconds, preferredTimescale: 600))
        let url = URL(fileURLWithPath: request.output)
        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
            throw NSError(domain: "SimulatorFrameExport", code: 4, userInfo: [NSLocalizedDescriptionKey: "Could not create a simulator frame destination"])
        }
        CGImageDestinationAddImage(destination, frame.image, nil)
        guard CGImageDestinationFinalize(destination) else {
            throw NSError(domain: "SimulatorFrameExport", code: 5, userInfo: [NSLocalizedDescriptionKey: "Could not write a simulator frame"])
        }
        print("Exported simulator frame: \(request.output) at \(frame.actualTime.seconds)s")
    }
}

do {
    try await exportFrames()
} catch {
    FileHandle.standardError.write(Data("Simulator frame export failed: \(error)\n".utf8))
    exit(1)
}
