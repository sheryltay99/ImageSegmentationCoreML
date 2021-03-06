//
//  Extensions.swift
//  ImageSegmentationSample
//
//  Created by Sheryl Tay on 15/3/21.
//

import UIKit

// MARK: UIImage extensions
extension UIImage {
    /// Returns the data representation of the image after scaling to the given `size` and removing
    /// the alpha component.
    ///
    /// - Parameters
    ///   - size: Size to scale the image to (i.e. image size used while training the model).
    ///   - byteCount: The expected byte count for the scaled image data calculated using the values
    ///       that the model was trained on: `imageWidth * imageHeight * componentsCount * batchSize`.
    ///   - isQuantized: Whether the model is quantized (i.e. fixed point values rather than floating
    ///       point values).
    /// - Returns: The scaled image as data or `nil` if the image could not be scaled.
    func scaledData(with size: CGSize, byteCount: Int, isQuantized: Bool) -> Data? {
        guard let cgImage = self.cgImage, cgImage.width > 0, cgImage.height > 0 else { return nil }
        guard let imageData = imageData(from: cgImage, with: size) else { return nil }
        var scaledBytes = [UInt8](repeating: 0, count: byteCount)
        var index = 0
        for component in imageData.enumerated() {
            let offset = component.offset
            let isAlphaComponent = (offset % Constant.alphaComponent.baseOffset)
                == Constant.alphaComponent.moduloRemainder
            guard !isAlphaComponent else { continue }
            scaledBytes[index] = component.element
            index += 1
        }
        if isQuantized { return Data(scaledBytes) }
        let scaledFloats = scaledBytes.map { (Float32($0) - Constant.imageMean) / Constant.imageStd }
        return Data(copyingBufferOf: scaledFloats)
    }
    
    /// Returns the image data for the given CGImage based on the given `size`.
    func imageData(from cgImage: CGImage, with size: CGSize) -> Data? {
        let bitmapInfo = CGBitmapInfo(
            rawValue: CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue
        )
        let width = Int(size.width)
        let scaledBytesPerRow = (cgImage.bytesPerRow / cgImage.width) * width
        guard
            let context = CGContext(
                data: nil,
                width: width,
                height: Int(size.height),
                bitsPerComponent: cgImage.bitsPerComponent,
                bytesPerRow: scaledBytesPerRow,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: bitmapInfo.rawValue)
        else {
            return nil
        }
        context.draw(cgImage, in: CGRect(origin: .zero, size: size))
        return context.makeImage()?.dataProvider?.data as Data?
    }
    
    /// Overlay an image on top of current image with alpha component
    /// - Parameters
    ///   - alpha: Alpha component of the image to be drawn on the top of current image
    /// - Returns: The overlayed image or `nil` if the image could not be drawn.
    func overlayWithImage(image: UIImage, alpha: Float) -> UIImage? {
        let areaSize = CGRect(x: 0, y: 0, width: self.size.width, height: self.size.height)
        
        UIGraphicsBeginImageContext(self.size)
        self.draw(in: areaSize)
        image.draw(in: areaSize, blendMode: .normal, alpha: CGFloat(alpha))
        let newImage: UIImage? = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return newImage
    }
    
    /// Make the same image with orientation being `.up`.
    /// - Returns:  A copy of the image with .up orientation or `nil` if the image could not be
    /// rotated.
    func transformOrientationToUp() -> UIImage? {
        // Check if the image orientation is already .up and don't need any rotation.
        guard imageOrientation != UIImage.Orientation.up else {
            // No rotation needed so return a copy of this image.
            return self.copy() as? UIImage
        }
        
        // Make sure that this image has an CGImage attached.
        guard let cgImage = self.cgImage else { return nil }
        
        // Create a CGContext to draw the rotated image to.
        guard let colorSpace = cgImage.colorSpace,
              let context = CGContext(
                data: nil,
                width: Int(size.width),
                height: Int(size.height),
                bitsPerComponent: cgImage.bitsPerComponent,
                bytesPerRow: 0,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              )
        else { return nil }
        
        var transform: CGAffineTransform = CGAffineTransform.identity
        
        // Calculate the transformation matrix that needed to bring the image orientation to .up
        switch imageOrientation {
        case .down, .downMirrored:
            transform = transform.translatedBy(x: size.width, y: size.height)
            transform = transform.rotated(by: CGFloat.pi)
            break
        case .left, .leftMirrored:
            transform = transform.translatedBy(x: size.width, y: 0)
            transform = transform.rotated(by: CGFloat.pi / 2.0)
            break
        case .right, .rightMirrored:
            transform = transform.translatedBy(x: 0, y: size.height)
            transform = transform.rotated(by: CGFloat.pi / -2.0)
            break
        case .up, .upMirrored:
            break
        @unknown default:
            break
        }
        
        // If the image is mirrored then flip it.
        switch imageOrientation {
        case .upMirrored, .downMirrored:
            transform.translatedBy(x: size.width, y: 0)
            transform.scaledBy(x: -1, y: 1)
            break
        case .leftMirrored, .rightMirrored:
            transform.translatedBy(x: size.height, y: 0)
            transform.scaledBy(x: -1, y: 1)
        case .up, .down, .left, .right:
            break
        @unknown default:
            break
        }
        
        // Apply transformation matrix to the CGContext.
        context.concatenate(transform)
        
        switch imageOrientation {
        case .left, .leftMirrored, .right, .rightMirrored:
            context.draw(self.cgImage!, in: CGRect(x: 0, y: 0, width: size.height, height: size.width))
        default:
            context.draw(self.cgImage!, in: CGRect(x: 0, y: 0, width: size.width, height: size.height))
            break
        }
        
        // Create a CGImage from the context.
        guard let newCGImage = context.makeImage() else { return nil }
        
        // Convert it to UIImage.
        return UIImage.init(cgImage: newCGImage, scale: 1, orientation: .up)
    }
    
    /// Helper function to center-crop image.
    /// - Returns: Center-cropped copy of this image
    func cropCenter() -> UIImage? {
        let isPortrait = size.height > size.width
        let isLandscape = size.width > size.height
        let breadth = min(size.width, size.height)
        let breadthSize = CGSize(width: breadth, height: breadth)
        let breadthRect = CGRect(origin: .zero, size: breadthSize)
        
        UIGraphicsBeginImageContextWithOptions(breadthSize, false, scale)
        let croppingOrigin = CGPoint(
            x: isLandscape ? floor((size.width - size.height) / 2) : 0,
            y: isPortrait ? floor((size.height - size.width) / 2) : 0
        )
        guard let cgImage = cgImage?.cropping(to: CGRect(origin: croppingOrigin, size: breadthSize))
        else { return nil }
        UIImage(cgImage: cgImage).draw(in: breadthRect)
        let croppedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return croppedImage
    }
    
    func resize(to newSize: CGSize) -> UIImage {
        UIGraphicsBeginImageContextWithOptions(CGSize(width: newSize.width, height: newSize.height), true, 1.0)
        self.draw(in: CGRect(x: 0, y: 0, width: newSize.width, height: newSize.height))
        let resizedImage = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        
        return resizedImage
    }
    
    func cropToSquare() -> UIImage? {
        guard let cgImage = self.cgImage else {
            return nil
        }
        var imageHeight = self.size.height
        var imageWidth = self.size.width
        
        if imageHeight > imageWidth {
            imageHeight = imageWidth
        }
        else {
            imageWidth = imageHeight
        }
        
        let size = CGSize(width: imageWidth, height: imageHeight)
        
        let x = ((CGFloat(cgImage.width) - size.width) / 2).rounded()
        let y = ((CGFloat(cgImage.height) - size.height) / 2).rounded()
        
        let cropRect = CGRect(x: x, y: y, width: size.height, height: size.width)
        if let croppedCgImage = cgImage.cropping(to: cropRect) {
            return UIImage(cgImage: croppedCgImage, scale: 0, orientation: self.imageOrientation)
        }
        
        return nil
    }
    
    func pixelBuffer() -> CVPixelBuffer? {
        let width = self.size.width
        let height = self.size.height
        let attrs = [kCVPixelBufferCGImageCompatibilityKey: kCFBooleanTrue,
                     kCVPixelBufferCGBitmapContextCompatibilityKey: kCFBooleanTrue] as CFDictionary
        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(kCFAllocatorDefault,
                                         Int(width),
                                         Int(height),
                                         kCVPixelFormatType_32ARGB,
                                         attrs,
                                         &pixelBuffer)
        
        guard let resultPixelBuffer = pixelBuffer, status == kCVReturnSuccess else {
            return nil
        }
        
        CVPixelBufferLockBaseAddress(resultPixelBuffer, CVPixelBufferLockFlags(rawValue: 0))
        let pixelData = CVPixelBufferGetBaseAddress(resultPixelBuffer)
        
        let rgbColorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(data: pixelData,
                                      width: Int(width),
                                      height: Int(height),
                                      bitsPerComponent: 8,
                                      bytesPerRow: CVPixelBufferGetBytesPerRow(resultPixelBuffer),
                                      space: rgbColorSpace,
                                      bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue) else {
            return nil
        }
        
        context.translateBy(x: 0, y: height)
        context.scaleBy(x: 1.0, y: -1.0)
        
        UIGraphicsPushContext(context)
        self.draw(in: CGRect(x: 0, y: 0, width: width, height: height))
        UIGraphicsPopContext()
        CVPixelBufferUnlockBaseAddress(resultPixelBuffer, CVPixelBufferLockFlags(rawValue: 0))
        
        return resultPixelBuffer
    }
}

// MARK: Data extensions
extension Data {
    /// Creates a new buffer by copying the buffer pointer of the given array.
    ///
    /// - Warning: The given array's element type `T` must be trivial in that it can be copied bit
    ///     for bit with no indirection or reference-counting operations; otherwise, reinterpreting
    ///     data from the resulting buffer has undefined behavior.
    /// - Parameter array: An array with elements of type `T`.
    init<T>(copyingBufferOf array: [T]) {
        self = array.withUnsafeBufferPointer(Data.init)
    }
    
    /// Convert a Data instance to Array representation.
    func toArray<T>(type: T.Type) -> [T] where T: ExpressibleByIntegerLiteral {
        var array = [T](repeating: 0, count: self.count/MemoryLayout<T>.stride)
        _ = array.withUnsafeMutableBytes { copyBytes(to: $0) }
        return array
    }
}

// MARK: UIColor extensions
extension UIColor {
    
    // Check if the color is light or dark, as defined by the injected lightness threshold.
    // A nil value is returned if the lightness couldn't be determined.
    func isLight(threshold: Float = 0.5) -> Bool? {
        let originalCGColor = self.cgColor
        
        // Convert the color to the RGB colorspace as some color such as UIColor.white and .black
        // are grayscale.
        let RGBCGColor = originalCGColor.converted(
            to: CGColorSpaceCreateDeviceRGB(), intent: .defaultIntent, options: nil)
        
        guard let components = RGBCGColor?.components else { return nil }
        guard components.count >= 3 else { return nil }
        
        // Calculate color brightness according to Digital ITU BT.601.
        let brightness = Float(
            ((components[0] * 299) + (components[1] * 587) + (components[2] * 114)) / 1000
        )
        
        return (brightness > threshold)
    }
}

// MARK: - Constants

private enum Constant {
    static let jpegCompressionQuality: CGFloat = 0.8
    static let alphaComponent = (baseOffset: 4, moduloRemainder: 3)
    static let imageMean: Float32 = 127.5
    static let imageStd: Float32 = 127.5
}
//
//  Extensions.swift
//  Segmentation-CoreML
//
//  Created by Sheryl Tay on 13/4/21.
//

import Foundation
