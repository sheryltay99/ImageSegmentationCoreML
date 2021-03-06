//
//  Segmentator.swift
//  Segmentation-CoreML
//
//  Created by Sheryl Tay on 22/3/21.
//

import UIKit
import Vision

class Segmentator {
    private let labelList: [String]
    
    private var segmentationModel: deeplab
    private var request: VNCoreMLRequest?
    private var visionModel: VNCoreMLModel?
    
    private var multiArrayResult: SegmentationMultiArrayResult? = nil
    private var outputImageWidth: Int = 0
    private var outputImageHeight: Int = 0
    private var outputClassCount: Int = 0
    
    static public func getInstance() -> Segmentator? {
        guard let labelList = loadLabelList() else {
            print("Failed to load label list")
            return nil
        }
        
        let segmentationModel: deeplab
        do {
            segmentationModel = try deeplab(configuration: MLModelConfiguration())
        } catch {
            print("Failed to initialise deeplab model.")
            fatalError()
        }
        
        return Segmentator(labelList: labelList, segmentationModel: segmentationModel)
    }
    
    private init(labelList: [String], segmentationModel: deeplab) {
        self.labelList = labelList
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
    public func runSegmentation(image: UIImage, completion: @escaping (Result<SegmentationResults, SegmentationError>) -> Void) {
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
        
        let parsedOutput = parseOutput(multiArray: multiArrayResult)
        
        // Generating default segmentation and overlay images.
        guard let segmentationImage = imageFromSRGBColorArray(pixels: parsedOutput.segmentationPixelColour, width: outputImageWidth, height: outputImageHeight),
              let overlayImage = image.overlayWithImage(image: segmentationImage, alpha: 0.5)
        else {
            completion(.failure(.invalidPixelData))
            print("Failed to convert pixel data to image")
            return
        }
        let colourLegend = classListToColorLegend(classList: parsedOutput.classList)
        
        completion(.success(SegmentationResults(originalImage: image,
                                                segmentedImage: segmentationImage,
                                                overlayImage: overlayImage,
                                                colourLegend: colourLegend)))
    }
    
    /// Generating segmentation output
    private func parseOutput(multiArray: SegmentationMultiArrayResult) -> (segmentationMap: [[Int]],
                                                       segmentationPixelColour: [UInt32],
                                                       classList: Set<Int>) {
        // initialising data structures
        var segmentationMap = [[Int]](repeating: [Int](repeating: 0, count: self.outputImageWidth),
                                    count: self.outputImageHeight)
        var segmentationImagePixels = [UInt32](
            repeating: 0, count: self.outputImageHeight * self.outputImageWidth)
        var classList = Set<Int>()
        
        var maxVal: Float32 = 0.0
        var maxIndex: Int = 0
        
        for i in 0..<outputImageHeight {
            for j in 0..<outputImageWidth {
                maxIndex = 0
                maxVal = 0
                
                
                var labels = [Float32]()
                for x in 0..<outputClassCount {
                    let value = multiArray[i, j, x].floatValue
                    labels.append(value)
                }
//                    print(Constants.softmax(z: labels))
                labels = Constants.softmax(z: labels)
                
                for label in 0..<outputClassCount {
                    if labels[label] > maxVal {
                        maxVal = labels[label]
                        maxIndex = label
                    }
                }

                
                segmentationMap[i][j] = maxIndex
                classList.insert(maxIndex)
                let color = Constants.legendColorList[maxIndex % Constants.legendColorList.count]
                segmentationImagePixels[i * outputImageHeight + j] = color
                
            }
        }
        
        return (segmentationMap,
                segmentationImagePixels,
                classList)
    }
    
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
    private func imageFromSRGBColorArray(pixels: [UInt32], width: Int, height: Int) -> UIImage?
    {
        guard width > 0 && height > 0 else { return nil }
        guard pixels.count == width * height else { return nil }
        
        // Make a mutable copy
        var data = pixels
        
        // Convert array of pixels to a CGImage instance.
        let cgImage = data.withUnsafeMutableBytes { (ptr) -> CGImage in
            let ctx = CGContext(
                data: ptr.baseAddress,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: MemoryLayout<UInt32>.size * width,
                space: CGColorSpace(name: CGColorSpace.sRGB)!,
                bitmapInfo: CGBitmapInfo.byteOrder32Little.rawValue
                    + CGImageAlphaInfo.premultipliedFirst.rawValue
            )!
            return ctx.makeImage()!
        }
        
        // Convert the CGImage instance to an UIImage instance.
        return UIImage(cgImage: cgImage)
    }
    
    /// Look up the colors used to visualize the classes found in the image.
    private func classListToColorLegend(classList: Set<Int>) -> [String: UIColor] {
        var colorLegend: [String: UIColor] = [:]
        let sortedClassIndexList = classList.sorted()
        sortedClassIndexList.forEach { classIndex in
            // Look up the color legend for the class.
            // Using modulo to reuse colors on segmentation model with large number of classes.
            let color = Constants.legendColorList[classIndex % Constants.legendColorList.count]
            
            // Convert the color from sRGB UInt32 representation to UIColor.
            let a = CGFloat((color & 0xFF00_0000) >> 24) / 255.0
            let r = CGFloat((color & 0x00FF_0000) >> 16) / 255.0
            let g = CGFloat((color & 0x0000_FF00) >> 8) / 255.0
            let b = CGFloat(color & 0x0000_00FF) / 255.0
            colorLegend[labelList[classIndex]] = UIColor(red: r, green: g, blue: b, alpha: a)
        }
        return colorLegend
    }
}

// MARK: Segmentation Results and Error Structs
// segmentation results for default mask and confidence mask
struct SegmentationResults {
    var originalImage: UIImage
    var segmentedImage: UIImage
    var overlayImage: UIImage
    var colourLegend: [String: UIColor]
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
    
    static let legendColorList: [UInt32] = [
        0xFF80_8080, // Gray
        0xFFFF_0000, // Red
        0xFFFF_1493, // Pink
        0xFFFF_7F50, // Orange
        0xFF1E_90FF, // Blue
        0xFFAA_6E28, // Brown
        0xFFFF_FF00 // Yellow
    ]
    
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
