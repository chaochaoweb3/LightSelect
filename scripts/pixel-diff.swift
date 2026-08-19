#!/usr/bin/env swift

import CoreGraphics
import Foundation
import ImageIO

guard CommandLine.arguments.count == 3 else {
    FileHandle.standardError.write(Data("usage: pixel-diff.swift <reference.png> <candidate.png>\n".utf8))
    exit(2)
}

let referenceURL = URL(fileURLWithPath: CommandLine.arguments[1])
let candidateURL = URL(fileURLWithPath: CommandLine.arguments[2])

func loadImage(_ url: URL) -> CGImage? {
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
    return CGImageSourceCreateImageAtIndex(source, 0, nil)
}

func rgba(_ image: CGImage, width: Int, height: Int) -> [UInt8]? {
    var bytes = [UInt8](repeating: 0, count: width * height * 4)
    guard let context = CGContext(
        data: &bytes,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: width * 4,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else { return nil }
    context.interpolationQuality = .high
    context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
    return bytes
}

guard let reference = loadImage(referenceURL),
      let candidate = loadImage(candidateURL),
      let referenceBytes = rgba(reference, width: reference.width, height: reference.height),
      let candidateBytes = rgba(candidate, width: reference.width, height: reference.height) else {
    FileHandle.standardError.write(Data("PIXEL_DIFF_FAILED\n".utf8))
    exit(1)
}

var differentPixels = 0
var absoluteDifference: UInt64 = 0
let pixelCount = reference.width * reference.height
for pixel in 0..<pixelCount {
    var different = false
    for channel in 0..<4 {
        let index = pixel * 4 + channel
        let delta = abs(Int(referenceBytes[index]) - Int(candidateBytes[index]))
        absoluteDifference += UInt64(delta)
        different = different || delta > 0
    }
    if different { differentPixels += 1 }
}

let percent = Double(differentPixels) * 100 / Double(pixelCount)
let mean = Double(absoluteDifference) / Double(pixelCount * 4)
print(String(
    format: "PIXEL_DIFF reference=%dx%d candidate=%dx%d normalized=%dx%d differing=%d/%d (%.3f%%) mean_abs_rgba=%.3f",
    reference.width, reference.height, candidate.width, candidate.height,
    reference.width, reference.height, differentPixels, pixelCount, percent, mean
))
