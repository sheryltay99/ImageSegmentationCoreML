//  SegmentationMap.swift
//  TissueAI
//
//  Copyright © 2021 Tetsuyu Healthcare. All rights reserved.
//

import UIKit

struct SegmentationMap {
    var segmentationMap: [[Int]]
    var segmentationPixelColor: [UInt32]
    var classList: Set<Int>
    var confidenceSegmentationMap: [[Int]]
    var confidenceSegmentationPixelColor: [UInt32]
    var confidenceClassList: Set<Int>
    
    var multiArray: SegmentationMultiArrayResult?
    
    let outputImageWidth: Int
    let outputImageHeight: Int
    let outputClassCount: Int
    
    let labelList = TissueLabelType.allCases
    let confidenceLabelList = ConfidenceLabelType.allCases
    
    var segmentedImage: UIImage?
    var overlayImage: UIImage?
    var colorLegend: [String: UIColor]?
    var confidenceSegmentedImage: UIImage?
    var confidenceOverlayImage: UIImage?
    var confidenceColorLegend: [String: UIColor]?
    
    // Initialise segmentation map with optional parameters depending on use of tflite or coreml model

    
    // Init for CoreML model.
    init(multiArray: SegmentationMultiArrayResult) {
        self.multiArray = multiArray
        self.outputImageWidth = multiArray.segmentationMapWidthSize
        self.outputImageHeight = multiArray.segmentationMapHeightSize
        self.outputClassCount = multiArray.classes
        
        self.segmentationMap = [[Int]](repeating: [Int](repeating: 0, count: outputImageHeight),
                                    count: outputImageWidth)
        self.segmentationPixelColor = [UInt32](
            repeating: 0, count: outputImageHeight * outputImageWidth)
        self.classList = Set<Int>()
        self.confidenceSegmentationMap = [[Int]](repeating: [Int](repeating: 0, count: outputImageHeight),
                                    count: outputImageWidth)
        self.confidenceSegmentationPixelColor = [UInt32](
            repeating: 0, count: outputImageHeight * outputImageWidth)
        self.confidenceClassList = Set<Int>()
        
        parseModelOutput(firstIter: outputImageHeight, secondIter: outputImageWidth)
    }
    
//    private init(segmentationMap: [[Int]],
//                 segmentationImagePixels: [UInt32],
//                 classList: Set<Int>,
//                 confidenceSegmentationMap: [[Int]],
//                 confidenceSegmentationImagePixels: [UInt32],
//                 confidenceClassList: Set<Int>,
//                 outputImageWidth: Int,
//                 outputImageHeight: Int,
//                 labelList: [TissueLabelType],
//                 confidenceLabelList: [ConfidenceLabelType]) {
//        self.segmentationMap = segmentationMap
//        self.segmentationPixelColor = segmentationImagePixels
//        self.classList = classList
//        self.confidenceSegmentationMap = confidenceSegmentationMap
//        self.confidenceSegmentationPixelColor = confidenceSegmentationImagePixels
//        self.confidenceClassList = confidenceClassList
//
//        self.outputImageWidth = outputImageWidth
//        self.outputImageHeight = outputImageHeight
//        self.labelList = labelList
//        self.confidenceLabelList = confidenceLabelList
//    }
    
    private func generateConfidenceIndex(maxVal: Float32) -> Int {
        let confidenceIndex: Int
        switch maxVal {
        case 0.91...1.0:
            confidenceIndex = 0
        case 0.81...0.90:
            confidenceIndex = 1
        case 0.71...0.80:
            confidenceIndex = 2
        case 0.61...0.70:
            confidenceIndex = 3
        case 0.51...0.60:
            confidenceIndex = 4
        case 0.41...0.50:
            confidenceIndex = 5
        case 0.31...0.40:
            confidenceIndex = 6
        case 0.21...0.30:
            confidenceIndex = 7
        case 0.11...0.20:
            confidenceIndex = 8
        case 0.01...0.10:
            confidenceIndex = 9
        default:
            confidenceIndex = 0
        }
        return confidenceIndex
    }
    
    private mutating func parseModelOutput(firstIter: Int, secondIter: Int) {
//        let outputArray = outputTensor?.data.toArray(type: Float32.self)
        
        var maxVal: Float32 = 0.0
        var val: Float32 = 0.0
        var maxIndex: Int = 0
        
        for x in 0..<firstIter {
            for y in 0..<secondIter {
                maxIndex = 0
                maxVal = 0.0
                // find label with highest confidence level for that pixel
                for z in 0..<outputClassCount {
                    if let coremlArr = multiArray {
                        val = coremlArr[x, y, z].floatValue
                    }
                    if val > maxVal {
                        maxVal = val
                        maxIndex = z
                    }
                }
                // Creating default segmentation map.
                segmentationMap[x][y] = maxIndex
                classList.insert(maxIndex)
                
                // Lookup the color legend for the class.
                let legendColor = labelList[maxIndex].colorAsUint
                segmentationPixelColor[x * outputImageHeight + y] = legendColor
                
                // Creating confidence segmentation map.
                let confidenceIndex = generateConfidenceIndex(maxVal: maxVal)
                confidenceSegmentationMap[x][y] = confidenceIndex
                confidenceClassList.insert(confidenceIndex)
                
                // Lookup color legend for confidence.
                let confidenceColor = confidenceLabelList[confidenceIndex].colorAsUint
                confidenceSegmentationPixelColor[x * outputImageHeight + y] = confidenceColor
            }
        }
    }
    
    /// Construct an UIImage from a list of sRGB pixels.
    private func imageFromSRGBColorArray(pixels: [UInt32]) -> UIImage?
    {
        guard outputImageWidth > 0 && outputImageHeight > 0 else { return nil }
        guard pixels.count == outputImageWidth * outputImageHeight else { return nil }
        
        // Make a mutable copy
        var data = pixels
        
        // Convert array of pixels to a CGImage instance.
        let cgImage = data.withUnsafeMutableBytes { (ptr) -> CGImage in
            let ctx = CGContext(
                data: ptr.baseAddress,
                width: outputImageWidth,
                height: outputImageHeight,
                bitsPerComponent: 8,
                bytesPerRow: MemoryLayout<UInt32>.size * outputImageWidth,
                space: CGColorSpace(name: CGColorSpace.sRGB)!,
                bitmapInfo: CGBitmapInfo.byteOrder32Little.rawValue
                    + CGImageAlphaInfo.premultipliedFirst.rawValue
            )!
            return ctx.makeImage()!
        }
        
        // Convert the CGImage instance to an UIImage instance.
        return UIImage(cgImage: cgImage)
    }
    
//    /// Look up the colors used to visualize the classes found in the image.
//    private func classListToColorLegend(classList: Set<Int>,
//                                       isConfidence: Bool) -> [String: UIColor] {
//        var colorLegend: [String: UIColor] = [:]
//        let sortedClassIndexList = classList.sorted()
//        sortedClassIndexList.forEach { classIndex in
//            // Look up the color legend for the class.
//            let color: UIColor
//            let label: String
//            if isConfidence {
//                color = confidenceLabelList[classIndex].color
//                label = confidenceLabelList[classIndex].rawValue
//            } else {
//                color = labelList[classIndex].color
//                label = labelList[classIndex].rawValue
//            }
//
//            colorLegend[label] = color
//        }
//        return colorLegend
//    }
    private func classListToColorLegend(classList: Set<Int>) -> [String: UIColor] {
        let sortedClassIndexList = classList.sorted()
        let colors = sortedClassIndexList.map{labelList[$0].color}
        let labels = sortedClassIndexList.map{labelList[$0].rawValue}
        let colorLegend = Dictionary(uniqueKeysWithValues: zip(labels, colors))
        return colorLegend
    }
    
    private func classListToConfidenceColorLegend(classList: Set<Int>) -> [String: UIColor] {
        let sortedClassIndexList = classList.sorted()
        let colors = sortedClassIndexList.map{confidenceLabelList[$0].color}
        let labels = sortedClassIndexList.map{confidenceLabelList[$0].rawValue}
        let colorLegend = Dictionary(uniqueKeysWithValues: zip(labels, colors))
        return colorLegend
    }
    
    //create function to generate segmented and overlay image
    mutating func generateOutput(originalImage: UIImage) {
        generateSegmentedAndOverlay(originalImage: originalImage)
        generateColorLegend()
    }
    
    mutating private func generateSegmentedAndOverlay(originalImage: UIImage) {
        let segmentationImage = imageFromSRGBColorArray(pixels: segmentationPixelColor)
        let confidenceSegmentationImage = imageFromSRGBColorArray(pixels: confidenceSegmentationPixelColor)
        var overlayImage: UIImage? = nil
        var confidenceOverlayImage: UIImage? = nil
        if let image = segmentationImage,
           let confidenceImage = confidenceSegmentationImage {
            overlayImage = originalImage.overlayWithImage(image: image, alpha: 0.5)
            confidenceOverlayImage = originalImage.overlayWithImage(image: confidenceImage, alpha: 0.5)
        }
        self.segmentedImage = segmentationImage
        self.confidenceSegmentedImage = confidenceSegmentationImage
        self.overlayImage = overlayImage
        self.confidenceOverlayImage = confidenceOverlayImage
    }
    
    mutating private func generateColorLegend() {
        let colorLegend = classListToColorLegend(classList: classList)
        let confidenceColorLegend = classListToConfidenceColorLegend(classList: confidenceClassList)
        self.colorLegend = colorLegend
        self.confidenceColorLegend = confidenceColorLegend
    }
}
