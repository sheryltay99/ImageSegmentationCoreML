//
//  SegmentationPostProcessor.swift
//  DepthPrediction-CoreML
//
//  Created by Doyoung Gwak on 20/07/2019.
//  Copyright © 2019 Doyoung Gwak. All rights reserved.
//

import CoreML

class SegmentationMultiArrayResult {
    let mlMultiArray: MLMultiArray
    let segmentationMapWidthSize: Int
    let segmentationMapHeightSize: Int
    let classes: Int
    
    init(mlMultiArray: MLMultiArray) {
        self.mlMultiArray = mlMultiArray
        self.segmentationMapHeightSize = mlMultiArray.shape[1].intValue
        self.segmentationMapWidthSize = mlMultiArray.shape[2].intValue
        self.classes = mlMultiArray.shape[3].intValue
    }
    
    subscript(columnIndex: Int, rowIndex: Int, classIndex: Int) -> NSNumber {
        let index = [0, columnIndex, rowIndex, classIndex] as [NSNumber]
        return mlMultiArray[index]
    }
    

}
