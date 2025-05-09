import Foundation
import InlineProtocol

#if os(iOS)
public typealias PlatformImage = UIImage
import UIKit
#else
public typealias PlatformImage = NSImage
import AppKit
#endif

public enum ImageFormat: String, Codable, Sendable {
  case jpeg
  case png

  var fileExtension: String {
    switch self {
      case .jpeg: "jpg"
      case .png: "png"
    }
  }

  var mimeType: String {
    switch self {
      case .jpeg: "image/jpeg"
      case .png: "image/png"
    }
  }

  public func toProtocol() -> InlineProtocol.Photo.Format {
    switch self {
      case .jpeg:
        .jpeg
      case .png:
        .png
    }
  }

  public func toExt() -> String {
    switch self {
      case .jpeg: ".jpg"
      case .png: ".png"
    }
  }

  public func toMimeType() -> String {
    switch self {
      case .jpeg: "image/jpeg"
      case .png: "image/png"
    }
  }
}

public protocol ImageSaving {
  func save(to directory: URL, withName fileName: String, format: ImageFormat, optimize: Bool) -> String?
}

#if os(iOS)
import ImageIO
import UniformTypeIdentifiers

extension UIImage: ImageSaving {
  public func save(
    to directory: URL,
    withName fileName: String,
    format: ImageFormat,
    optimize: Bool = false
  ) -> String? {
    // TODO: Resize on optimize=true
    let path = fileName.isEmpty ? UUID().uuidString + "." + format.fileExtension : fileName
    let fileUrl = directory.appendingPathComponent(path)

    let imageData: Data? =
      switch format {
        case .png:
          optimize ? optimizedPNGData() : pngData()
        case .jpeg:
          jpegData(compressionQuality: optimize ? 0.8 : 1.0)
      }

    guard let data = imageData else { return nil }

    do {
      try data.write(to: fileUrl)
      return path
    } catch {
      return nil
    }
  }

  private func optimizedPNGData() -> Data? {
    let imageToOptimize = self

    // Use ImageIO for better compression control
    guard let cgImage = imageToOptimize.cgImage else {
      return imageToOptimize.pngData()
    }

    let data = NSMutableData()
    guard let destination = CGImageDestinationCreateWithData(
      data as CFMutableData,
      UTType.png.identifier as CFString,
      1,
      nil
    ) else {
      return imageToOptimize.pngData()
    }

    // PNG optimization properties
    let properties: [CFString: Any] = [
      kCGImagePropertyPNGCompressionFilter: 0,
      kCGImagePropertyPNGInterlaceType: 0,
      kCGImageDestinationOptimizeColorForSharing: true,
    ]

    CGImageDestinationAddImage(destination, cgImage, properties as CFDictionary)

    if CGImageDestinationFinalize(destination) {
      return data as Data
    } else {
      return imageToOptimize.pngData()
    }
  }
}

#else
extension NSImage: ImageSaving {
  public func save(
    to directory: URL,
    withName fileName: String,
    format: ImageFormat,
    optimize: Bool = false
  ) -> String? {
    let path = fileName.isEmpty ? UUID().uuidString + "." + format.fileExtension : fileName
    let fileUrl = directory.appendingPathComponent(path)

    guard let data = tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: data)
    else {
      return nil
    }

    let imageData = switch format {
      case .png:
        bitmap.representation(
          using: .png,
          properties: optimize ? [.compressionFactor: 0.8] : [:]
        )
      case .jpeg:
        bitmap.representation(
          using: .jpeg,
          properties: optimize ? [.compressionFactor: 0.8] : [:]
        )
    }

    // guard let data = imageData else { return nil }

    do {
      try data.write(to: fileUrl)
      return path
    } catch {
      return nil
    }
  }
}
#endif

// Helper extension for File type
public extension File {
  var imageFormat: ImageFormat {
    switch mimeType {
      case "image/png":
        .png
      case "image/jpeg":
        .jpeg
      default:
        .jpeg
    }
  }
}

func hasAlphaChannel(image: PlatformImage) -> Bool {
  let cgImage: CGImage?

  #if canImport(UIKit)
  cgImage = image.cgImage
  #elseif canImport(AppKit)
  cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil)
  #endif

  guard let cgImage else { return false }

  let alphaInfo = cgImage.alphaInfo
  switch alphaInfo {
    case .first, .last, .premultipliedFirst, .premultipliedLast, .alphaOnly:
      return true
    case .none, .noneSkipFirst, .noneSkipLast:
      return false
    @unknown default:
      return false
  }
}
