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
            visionModel = try VNCoreMLModel(for: model)
        } catch let error {
            print("Failed to convert to VNCoreMLModel with error: \(error)")
        }
        
        if let visionModel = self.visionModel {
            request = VNCoreMLRequest(model: visionModel, completionHandler: visionRequestDidComplete)
            request?.imageCropAndScaleOption = .scaleFill
        }
    }
    
    private func visionRequestDidComplete(request: VNRequest, error: Error?) {
        // using feature value
        if let observations = request.results as? [VNCoreMLFeatureValueObservation],
           let segmentationMap = observations.first?.featureValue.multiArrayValue {
            multiArrayResult = SegmentationMultiArrayResult(mlMultiArray: segmentationMap)
//            print(segmentationMap.shape)
        }
    }
    
    private func setWoundImage(image: UIImage) {
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
        while multiArrayResult == nil {}
        guard let multiArrayResult = self.multiArrayResult else {
            print("Unable to get MlMultiArray result from model")
            return
        }
        outputImageWidth = multiArrayResult.segmentationMapWidthSize
        outputImageHeight = multiArrayResult.segmentationMapHeightSize
        outputClassCount = multiArrayResult.classes
        
//        let parsedOutput = parseOutput(multiArray: multiArrayResult)
        var parsedOutput = SegmentationMap(outputImageWidth: multiArrayResult.segmentationMapWidthSize, outputImageHeight: multiArrayResult.segmentationMapHeightSize, outputClassCount: multiArrayResult.classes, modelOutput: self)
        
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

extension Segmentator: ModelOutput {
    var firstIter: Int {
        return outputImageHeight
    }
    
    var secondIter: Int {
        return outputImageWidth
    }
    
    func getValue(firstIterIndex: Int, secondIterIndex: Int, classIndex: Int) -> Float32? {
        guard let multiArrayResult = self.multiArrayResult else {
            print("Unable to get MlMultiArray result from model")
            return nil
        }
        return multiArrayResult[firstIterIndex, secondIterIndex, classIndex].floatValue
    }
}
