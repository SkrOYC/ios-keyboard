import AVFoundation
import Foundation
import ImageIO
import UniformTypeIdentifiers

struct FrameRequest: Decodable {
    let seconds: Double
    let output: String
}

let arguments = CommandLine.arguments
guard arguments.count == 3 else { fatalError("Expected a simulator movie and frame request file") }
let asset = AVURLAsset(url: URL(fileURLWithPath: arguments[1]))
let generator = AVAssetImageGenerator(asset: asset)
generator.appliesPreferredTrackTransform = true
generator.requestedTimeToleranceBefore = .zero
generator.requestedTimeToleranceAfter = .zero
let requests = try JSONDecoder().decode([FrameRequest].self, from: Data(contentsOf: URL(fileURLWithPath: arguments[2])))
for request in requests {
    let frame = try await generator.image(at: CMTime(seconds: request.seconds, preferredTimescale: 600))
    let url = URL(fileURLWithPath: request.output)
    guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
        fatalError("Could not create a simulator frame destination")
    }
    CGImageDestinationAddImage(destination, frame.image, nil)
    guard CGImageDestinationFinalize(destination) else { fatalError("Could not write a simulator frame") }
    print("Exported simulator frame: \(request.output)")
}
