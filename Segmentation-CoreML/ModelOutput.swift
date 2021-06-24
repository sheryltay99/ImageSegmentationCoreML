//
//  ModelOutput.swift
//  Segmentation-CoreML
//
//  Created by Sheryl Tay on 22/6/21.
//

import UIKit

protocol ModelOutput {
    var firstIter: Int { get }
    var secondIter: Int { get }
    func getValue(firstIterIndex: Int, secondIterIndex: Int, classIndex: Int) -> Float32?
}
