import Foundation
import AVFoundation

struct AudioFileInfo {
    var bitDepth: Int?
    var bitrateKbps: Int?
}

enum AudioFileInfoInspector {
    static func inspect(url: URL) async -> AudioFileInfo {
        var info = AudioFileInfo(bitDepth: nil, bitrateKbps: nil)
        let ext = url.pathExtension.lowercased()
        if ["wav", "aiff", "aif", "caf"].contains(ext) {
            // Try to get bit depth from stream description (synchronous)
            if let file = try? AVAudioFile(forReading: url) {
                let asbd = file.processingFormat.streamDescription.pointee
                let depth = Int(asbd.mBitsPerChannel)
                if depth > 0 { info.bitDepth = depth }
            }
        } else {
            // Compressed: use modern async AVAsset loading APIs
            let asset = AVURLAsset(url: url)
            if let tracks = try? await asset.loadTracks(withMediaType: .audio), let track = tracks.first {
                if let bps = try? await track.load(.estimatedDataRate), bps > 0 {
                    info.bitrateKbps = Int((bps / 1000.0).rounded())
                }
            }
        }
        return info
    }
}
