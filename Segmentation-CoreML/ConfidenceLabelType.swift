//
//  ConfidenceLabelType.swift
//  TissueAI
//
//  Copyright © 2021 Tetsuyu Healthcare. All rights reserved.
//

import UIKit

/// Confidence label
enum ConfidenceLabelType: String, CaseIterable {
    
    /// 91% to 100% confidence
    case ninetyOneToHundred = "91%-100%"
    
    /// 81% to 90% confidence
    case eightyOneToNinety = "81%-90%"
    
    /// 71% to 80% confidence
    case seventyOneToEighty = "71%-80%"
    
    /// 91% to 100% confidence
    case sixtyOneToSeventy = "61%-70%"
    
    /// 91% to 100% confidence
    case fiftyOneToSixty = "51%-60%"
    
    /// 91% to 100% confidence
    case fortyOneToFifty = "41%-50%"
    
    /// 91% to 100% confidence
    case thirtyOneToForty = "31%-40%"
    
    /// 91% to 100% confidence
    case twentyOneToThirty = "21%-30%"
    
    /// 91% to 100% confidence
    case elevenToTwenty = "11%-20%"
    
    /// 91% to 100% confidence
    case oneToTen = "1%-10%"
    
    /// Annotation or Reference Color
    var color: UIColor {
        switch self {
        case .ninetyOneToHundred:
            return #colorLiteral(red: 0.1411764706, green: 0.3960784314, blue: 0.5647058824, alpha: 1)
            
        case .eightyOneToNinety:
            return #colorLiteral(red: 0.1411764706, green: 0.3960784314, blue: 0.5647058824, alpha: 1)
            
        case .seventyOneToEighty:
            return #colorLiteral(red: 0.1411764706, green: 0.3960784314, blue: 0.5647058824, alpha: 1)
            
        case .sixtyOneToSeventy:
            return #colorLiteral(red: 0.2392156863, green: 0.6745098039, blue: 0.968627451, alpha: 1)
            
        case .fiftyOneToSixty:
            return #colorLiteral(red: 0.4745098039, green: 0.8392156863, blue: 0.9764705882, alpha: 1)
            
        case .fortyOneToFifty:
            return #colorLiteral(red: 0.9098039216, green: 0.4784313725, blue: 0.6431372549, alpha: 1)
            
        case .thirtyOneToForty:
            return #colorLiteral(red: 0.9764705882, green: 0.8509803922, blue: 0.5490196078, alpha: 1)
            
        case .twentyOneToThirty:
            return #colorLiteral(red: 0.7215686275, green: 0.8862745098, blue: 0.2, alpha: 1)
            
        case .elevenToTwenty:
            return #colorLiteral(red: 0.7215686275, green: 0.8862745098, blue: 0.2, alpha: 1)
            
        case .oneToTen:
            return #colorLiteral(red: 0.7215686275, green: 0.8862745098, blue: 0.2, alpha: 1)
        }
    }
    
    /// Annotation or Reference Color as UInt32
//    var colorAsUint: UInt32 {
//        switch self {
//        case .ninetyOneToHundred:
//            return 0xFF24_6590
//
//        case .eightyOneToNinety:
//            return 0xFF24_6590
//
//        case .seventyOneToEighty:
//            return 0xFF24_6590
//
//        case .sixtyOneToSeventy:
//            return 0xFF3D_ACF7
//
//        case .fiftyOneToSixty:
//            return 0xFF79_D6F9
//
//        case .fortyOneToFifty:
//            return 0xFFE8_7AA4
//
//        case .thirtyOneToForty:
//            return 0xFFF9_D98C
//
//        case .twentyOneToThirty:
//            return 0xFFB8_E233
//
//        case .elevenToTwenty:
//            return 0xFFB8_E233
//
//        case .oneToTen:
//            return 0xFFB8_E233
//        }
//    }
    var colorAsUint: UInt32 {
        return self.color.asUInt32
    }
    
    /// Localised String of Tissue Labels
    var localisedText: String {
        return NSLocalizedString(self.rawValue, comment: "")
    }
}
