// Optional macOS runtime-frame encoder; uses the installed Apple SDK.
// Input images are actual Godot captures. H.264 encoding is lossy; no visual grading.
import Foundation
import AppKit
import AVFoundation
let folder = URL(fileURLWithPath: CommandLine.arguments[1])
let output = URL(fileURLWithPath: CommandLine.arguments[2])
let frames = try FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil).filter { $0.pathExtension == "png" }.sorted { $0.lastPathComponent < $1.lastPathComponent }
guard let first = frames.first, let firstImage = NSImage(contentsOf: first), let cg = firstImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else { fatalError("No runtime frames") }
try? FileManager.default.removeItem(at: output)
let writer = try AVAssetWriter(outputURL: output, fileType: .mp4)
let settings: [String:Any] = [AVVideoCodecKey:AVVideoCodecType.h264, AVVideoWidthKey:cg.width, AVVideoHeightKey:cg.height, AVVideoCompressionPropertiesKey:[AVVideoAverageBitRateKey:12_000_000,AVVideoMaxKeyFrameIntervalKey:60]]
let input = AVAssetWriterInput(mediaType:.video, outputSettings:settings)
input.expectsMediaDataInRealTime = false
let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput:input,sourcePixelBufferAttributes:[kCVPixelBufferPixelFormatTypeKey as String:kCVPixelFormatType_32ARGB,kCVPixelBufferWidthKey as String:cg.width,kCVPixelBufferHeightKey as String:cg.height])
writer.add(input)
writer.startWriting()
writer.startSession(atSourceTime:.zero)
for (index,url) in frames.enumerated() {
    while !input.isReadyForMoreMediaData { Thread.sleep(forTimeInterval:0.001) }
    guard let img = NSImage(contentsOf:url)?.cgImage(forProposedRect:nil,context:nil,hints:nil) else { fatalError("Invalid frame") }
    var pixel:CVPixelBuffer?
    CVPixelBufferCreate(kCFAllocatorDefault,cg.width,cg.height,kCVPixelFormatType_32ARGB,nil,&pixel)
    guard let pixel else { fatalError("Allocation failed") }
    CVPixelBufferLockBaseAddress(pixel,[])
    let context = CGContext(data:CVPixelBufferGetBaseAddress(pixel),width:cg.width,height:cg.height,bitsPerComponent:8,bytesPerRow:CVPixelBufferGetBytesPerRow(pixel),space:CGColorSpaceCreateDeviceRGB(),bitmapInfo:CGImageAlphaInfo.noneSkipFirst.rawValue)!
    context.draw(img,in:CGRect(x:0,y:0,width:cg.width,height:cg.height))
    CVPixelBufferUnlockBaseAddress(pixel,[])
    guard adaptor.append(pixel,withPresentationTime:CMTime(value:Int64(index),timescale:60)) else { fatalError("Append failed: \(String(describing:writer.error))") }
}
input.markAsFinished()
let finish = DispatchSemaphore(value:0)
writer.finishWriting { finish.signal() }
finish.wait()
guard writer.status == .completed else { fatalError("Encode failed: \(String(describing:writer.error))") }
print("Encoded \(frames.count) unchanged runtime frames, \(cg.width)x\(cg.height), 60 Hz: \(output.path)")
