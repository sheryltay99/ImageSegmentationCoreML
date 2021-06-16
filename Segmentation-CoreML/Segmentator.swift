//
//  Segmentator.swift
//  Segmentation-CoreML
//
//  Created by Sheryl Tay on 22/3/21.
//

import UIKit
import Vision

class Segmentator {
    
    private var segmentationModel: mobileunet_model
    private var request: VNCoreMLRequest?
    private var visionModel: VNCoreMLModel?
    
    private var multiArrayResult: SegmentationMultiArrayResult? = nil
    private var outputImageWidth: Int = 0
    private var outputImageHeight: Int = 0
    private var outputClassCount: Int = 0
    
    static func getInstance() -> Segmentator? {
        
        let segmentationModel: mobileunet_model
        do {
            segmentationModel = try mobileunet_model(configuration: MLModelConfiguration())
        } catch {
            print("Failed to initialise deeplab model.")
            fatalError()
        }
        
        return Segmentator(segmentationModel: segmentationModel)
    }
    
    private init(segmentationModel: mobileunet_model) {
        self.segmentationModel = segmentationModel
        
        setUpModel()
    }
    
// MARK: Vision model functions
    private func setUpModel() {
        let model = segmentationModel.model
        do {
            self.visionModel = try VNCoreMLModel(for: model)
        } catch let error {
            print("Failed to convert to VNCoreMLModel with error: \(error)")
        }
        
        if let visionModel = self.visionModel {
            self.request = VNCoreMLRequest(model: visionModel, completionHandler: visionRequestDidComplete)
            request?.imageCropAndScaleOption = .scaleFill
        }
    }
    
    func visionRequestDidComplete(request: VNRequest, error: Error?) {
        // using feature value
        if let observations = request.results as? [VNCoreMLFeatureValueObservation],
           let segmentationMap = observations.first?.featureValue.multiArrayValue {
            self.multiArrayResult = SegmentationMultiArrayResult(mlMultiArray: segmentationMap)
//            print(segmentationMap.shape)
        }
    }
    
    func setWoundImage(image: UIImage) {
        if let pngImage = image.pngData() {
            let imageSrc = UIImage(data: pngImage)
            guard let cgImage = imageSrc?.cgImage else { return }
            
            guard let request = request else { fatalError() }
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            try? handler.perform([request])
        }
    }
    
// MARK: Segmentator functions
    // running segmentation to get default mask and confidence mask
    func runSegmentation(image: UIImage, completion: @escaping (Result<SegmentationResults, SegmentationError>) -> Void) {
        setWoundImage(image: image)
        
        // Waiting until we get back results from the model before proceeding.
        while self.multiArrayResult == nil {}
        guard let multiArrayResult = self.multiArrayResult else {
            print("Unable to get MlMultiArray result from model")
            return
        }
        
        self.outputImageWidth = multiArrayResult.segmentationMapWidthSize
        self.outputImageHeight = multiArrayResult.segmentationMapHeightSize
        self.outputClassCount = multiArrayResult.classes
        
//        let parsedOutput = parseOutput(multiArray: multiArrayResult)
        var parsedOutput = SegmentationMap(multiArray: multiArrayResult)
        
        // Generating default segmentation and overlay images.
//        guard let segmentationImage = imageFromSRGBColorArray(pixels: parsedOutput.segmentationPixelColour, width: outputImageWidth, height: outputImageHeight),
//              let overlayImage = image.overlayWithImage(image: segmentationImage, alpha: 0.5)
//        else {
//            completion(.failure(.invalidPixelData))
//            print("Failed to convert pixel data to image")
//            return
//        }
//        let colourLegend = classListToColorLegend(classList: parsedOutput.classList,
//                                                  labelList: labelList,
//                                                  confidenceLabelList: confidenceLabelList,
//                                                  isConfidence: false)
//
//        // Generating confidence segmentation and overlay images.
//        guard let confidenceSegmentationImage = imageFromSRGBColorArray(pixels: parsedOutput.confidenceSegmentationPixelColour,
//                                                                                  width: outputImageWidth,
//                                                                                  height: outputImageHeight),
//              let confidenceOverlayImage = image.overlayWithImage(image: confidenceSegmentationImage, alpha: 0.5)
//        else {
//            completion(.failure(.invalidPixelData))
//            print("invalid pixel data")
//            return
//        }
//        let confidenceColourLegend = classListToColorLegend(classList: parsedOutput.confidenceClassList,
//                                                            labelList: self.labelList,
//                                                            confidenceLabelList: confidenceLabelList,
//                                                            isConfidence: true)
        
        parsedOutput.generateOutput(originalImage: image)
        guard let segmentationImage = parsedOutput.segmentedImage,
              let overlayImage = parsedOutput.overlayImage,
              let colorLegend = parsedOutput.colorLegend,
              let confidenceSegmentationImage = parsedOutput.confidenceSegmentedImage,
              let confidenceOverlayImage = parsedOutput.confidenceOverlayImage,
              let confidenceColorLegend = parsedOutput.confidenceColorLegend
        else {
            completion(.failure(.invalidPixelData))
            print("Failed to convert pixel data to image")
            return
        }
        
        completion(.success(SegmentationResults(originalImage: image,
                                                segmentedImage: segmentationImage,
                                                overlayImage: overlayImage,
                                                colourLegend: colorLegend,
                                                confidenceSegmentedImage: confidenceSegmentationImage,
                                                confidenceColourLegend: confidenceColorLegend,
                                                confidenceOverlayImage: confidenceOverlayImage)))
    }
    
    /// Generating segmentation output
//    private func parseOutput(multiArray: SegmentationMultiArrayResult) -> (segmentationMap: [[Int]],
//                                                       segmentationPixelColour: [UInt32],
//                                                       classList: Set<Int>,
//                                                       confidenceSegmentationMap: [[Int]],
//                                                       confidenceSegmentationPixelColour: [UInt32],
//                                                       confidenceClassList: Set<Int>) {
//        // initialising data structures
//        var segmentationMap = [[Int]](repeating: [Int](repeating: 0, count: self.outputImageWidth),
//                                    count: self.outputImageHeight)
//        var segmentationImagePixels = [UInt32](
//            repeating: 0, count: self.outputImageHeight * self.outputImageWidth)
//        var classList = Set<Int>()
//        var confidenceSegmentationMap = [[Int]](repeating: [Int](repeating: 0, count: outputImageHeight),
//                                    count: outputImageWidth)
//        var confidenceSegmentationImagePixels = [UInt32](
//            repeating: 0, count: outputImageHeight * outputImageWidth)
//        var confidenceClassList = Set<Int>()
//
//        var maxVal: Float32 = 0.0
//        var maxIndex: Int = 0
//
//        for i in 0..<outputImageHeight {
//            for j in 0..<outputImageWidth {
//                maxIndex = 0
//                maxVal = 0
//
//                for x in 0..<outputClassCount {
//                    let value = multiArray[i, j, x].floatValue
//                    if value > maxVal {
//                        maxVal = value
//                        maxIndex = x
//                    }
//                }
//
//                segmentationMap[i][j] = maxIndex
//                classList.insert(maxIndex)
//                let color = labelList[maxIndex].colorAsUint
//                segmentationImagePixels[i * outputImageHeight + j] = color
//
//                let confidenceIndex: Int
//                switch maxVal {
//                case 0.91...1.0:
//                    confidenceIndex = 0
//                case 0.81...0.90:
//                    confidenceIndex = 1
//                case 0.71...0.80:
//                    confidenceIndex = 2
//                case 0.61...0.70:
//                    confidenceIndex = 3
//                case 0.51...0.60:
//                    confidenceIndex = 4
//                case 0.41...0.50:
//                    confidenceIndex = 5
//                case 0.31...0.40:
//                    confidenceIndex = 6
//                case 0.21...0.30:
//                    confidenceIndex = 7
//                case 0.11...0.20:
//                    confidenceIndex = 8
//                case 0.01...0.10:
//                    confidenceIndex = 9
//                default:
//                    confidenceIndex = 0
//                }
//
//                confidenceSegmentationMap[i][j] = confidenceIndex
//                confidenceClassList.insert(confidenceIndex)
//                let confidenceColour = confidenceLabelList[confidenceIndex].colorAsUint
//                confidenceSegmentationImagePixels[i * outputImageHeight + j] = confidenceColour
//
//            }
//        }
//
//        return (segmentationMap,
//                segmentationImagePixels,
//                classList,
//                confidenceSegmentationMap,
//                confidenceSegmentationImagePixels,
//                confidenceClassList)
//    }
    
// MARK: Utility functions
    /// Load label list from file.
    private static func loadLabelList() -> [String]? {
        guard
            let labelListPath = Bundle.main.path(
                forResource: Constants.labelsFileName,
                ofType: Constants.labelsFileExtension
            )
        else {
            return nil
        }
        
        // Parse label list file as JSON.
        do {
            let data = try Data(contentsOf: URL(fileURLWithPath: labelListPath), options: .mappedIfSafe)
            let jsonResult = try JSONSerialization.jsonObject(with: data, options: .mutableLeaves)
            if let labelList = jsonResult as? [String] { return labelList } else { return nil }
        } catch {
            print("Error parsing label list file as JSON.")
            return nil
        }
    }
    
    /// Convert 3-dimension index (image_width x image_height x class_count) to 1-dimension index
    private func coordinateToIndex(x: Int, y: Int, z: Int) -> Int {
        return x * outputImageHeight * outputClassCount + y * outputClassCount + z
    }
    
    /// Construct an UIImage from a list of sRGB pixels.
//    private func imageFromSRGBColorArray(pixels: [UInt32], width: Int, height: Int) -> UIImage?
//    {
//        guard width > 0 && height > 0 else { return nil }
//        guard pixels.count == width * height else { return nil }
//
//        // Make a mutable copy
//        var data = pixels
//
//        // Convert array of pixels to a CGImage instance.
//        let cgImage = data.withUnsafeMutableBytes { (ptr) -> CGImage in
//            let ctx = CGContext(
//                data: ptr.baseAddress,
//                width: width,
//                height: height,
//                bitsPerComponent: 8,
//                bytesPerRow: MemoryLayout<UInt32>.size * width,
//                space: CGColorSpace(name: CGColorSpace.sRGB)!,
//                bitmapInfo: CGBitmapInfo.byteOrder32Little.rawValue
//                    + CGImageAlphaInfo.premultipliedFirst.rawValue
//            )!
//            return ctx.makeImage()!
//        }
//
//        // Convert the CGImage instance to an UIImage instance.
//        return UIImage(cgImage: cgImage)
//    }
    
//    /// Look up the colors used to visualize the classes found in the image.
//    private func classListToColorLegend(classList: Set<Int>) -> [String: UIColor] {
//        var colorLegend: [String: UIColor] = [:]
//        let sortedClassIndexList = classList.sorted()
//        sortedClassIndexList.forEach { classIndex in
//            // Look up the color legend for the class.
//            // Using modulo to reuse colors on segmentation model with large number of classes.
//            let color: UIColor
//            let label: String
//            color = labelList[classIndex].color
//            label = labelList[classIndex].rawValue
//
//            // Convert the color from sRGB UInt32 representation to UIColor.
////            let a = CGFloat((color & 0xFF00_0000) >> 24) / 255.0
////            let r = CGFloat((color & 0x00FF_0000) >> 16) / 255.0
////            let g = CGFloat((color & 0x0000_FF00) >> 8) / 255.0
////            let b = CGFloat(color & 0x0000_00FF) / 255.0
//
////            colorLegend[label] = UIColor(red: r, green: g, blue: b, alpha: a)
//            colorLegend[label] = color
//        }
//        return colorLegend
//    }
    /// Look up the colors used to visualize the classes found in the image.
//    func classListToColorLegend(classList: Set<Int>,
//                                       labelList: [TissueLabelType],
//                                       confidenceLabelList: [ConfidenceLabelType],
//                                       isConfidence: Bool) -> [String: UIColor] {
//        var colorLegend: [String: UIColor] = [:]
//        let sortedClassIndexList = classList.sorted()
//        sortedClassIndexList.forEach { classIndex in
//            // Look up the color legend for the class.
//            // Using modulo to reuse colors on segmentation model with large number of classes.
//            let color: UIColor
//            let label: String
//            if isConfidence {
////                color = Constants.confidenceColorList[classIndex % Constants.confidenceColorList.count]
////                label = Constants.confidenceLabels[classIndex]
//                color = confidenceLabelList[classIndex].color
//                label = confidenceLabelList[classIndex].rawValue
//            } else {
//                color = labelList[classIndex].color
//                label = labelList[classIndex].rawValue
//            }
//
//            // Convert the color from sRGB UInt32 representation to UIColor.
////            let a = CGFloat((color & 0xFF00_0000) >> 24) / 255.0
////            let r = CGFloat((color & 0x00FF_0000) >> 16) / 255.0
////            let g = CGFloat((color & 0x0000_FF00) >> 8) / 255.0
////            let b = CGFloat(color & 0x0000_00FF) / 255.0
//
////            colorLegend[label] = UIColor(red: r, green: g, blue: b, alpha: a)
//            colorLegend[label] = color
//        }
//        return colorLegend
//    }
}

// MARK: Segmentation Results and Error Structs
// segmentation results for default mask and confidence mask
struct SegmentationResults {
    var originalImage: UIImage
    var segmentedImage: UIImage
    var overlayImage: UIImage
    var colourLegend: [String: UIColor]
    var confidenceSegmentedImage: UIImage
    var confidenceColourLegend: [String: UIColor]
    var confidenceOverlayImage: UIImage
}

enum SegmentationError: Error {
    case invalidImage
    case invalidPixelData
    case internalError(Error)
}

// MARK: Constants
struct Constants {
    static let labelsFileName = "deeplab"
    static let labelsFileExtension = "json"
    
//    static let legendColorList: [UInt32] = [
//        0xFF80_8080, // Gray
//        0xFFFF_0000, // Red
//        0xFFFF_1493, // Pink
//        0xFFFF_7F50, // Orange
//        0xFF1E_90FF, // Blue
//        0xFFAA_6E28, // Brown
//        0xFFFF_FF00 // Yellow
//    ]
    
    /** Softmax function.
      - Parameter z: A vector z.
      - Returns: A vector y = (e^z / sum(e^z))
    */
    static func softmax(z: [Float32]) -> [Float32] {
        let expArr = z.map { exp($0) }
        let sum = expArr.reduce(0, +)
        var final = [Float32]()
        
        for element in z {
            let new_val = exp(element) / sum
            final.append(new_val)
        }
        
        return final
    }
}
