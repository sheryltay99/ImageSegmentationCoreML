//
//  TissueLabelType.swift
//  TissueAI
//
//  Copyright © 2021 Tetsuyu Healthcare. All rights reserved.
//

import Foundation
import UIKit

/// Tissue Label
enum TissueLabelType: String, CaseIterable {
//    ["Skin", "Healthy Granulation", "Epithelizing", "Unhealthy Granulation", "Others", "Necrosis", "Slough"]
    /// Unhealthy Skin in wound
    case skin = "Skin"
    
    /// Healthy Granulation in wound
    case healthyGranulation = "Healthy Granulation"
    
    /// Epithelising tissue in the wound
    case epithelising = "Epithelising"
    
    /// Unhealthy Granulation in wound
    case unhealthyGranulation = "Unhealthy Granulation"
    
    /// Other (undefined tissues) in the wound bed
    case others = "Others"
    
    /// Necrosis tissue in wound
    case necrosis = "Necrosis"
    
    /// Slough tissue in wound
    case slough = "Slough"

    /// Annotation or Reference Color
    var color: UIColor {
        switch self {
        case .skin:
            return #colorLiteral(red: 0.1176470588, green: 0.2862745098, blue: 0.1568627451, alpha: 1)
            
        case .epithelising:
            return #colorLiteral(red: 1, green: 0.07843137255, blue: 0.5764705882, alpha: 1)
            
        case .healthyGranulation:
            return #colorLiteral(red: 0, green: 0.968627451, blue: 0.4470588235, alpha: 1)
            
        case .unhealthyGranulation:
            return #colorLiteral(red: 0.05098039216, green: 0.8784313725, blue: 0.8980392157, alpha: 1)
            
        case .slough:
            return #colorLiteral(red: 1, green: 1, blue: 0, alpha: 1)
        
        case .necrosis:
            return #colorLiteral(red: 0.6666666667, green: 0.431372549, blue: 0.1568627451, alpha: 1)
            
        case .others:
            return #colorLiteral(red: 0.1176470588, green: 0.5647058824, blue: 1, alpha: 1)
        }
    }
    
    var colorAsUint: UInt32 {
        switch self {
        case .skin:
            return 0xFF1E_4928
            
        case .epithelising:
            return 0xFFFF_1493
            
        case .healthyGranulation:
            return 0xFF00_F772
            
        case .unhealthyGranulation:
            return 0xFF0D_E0E5
            
        case .slough:
            return 0xFFFF_FF00
        
        case .necrosis:
            return 0xFFAA_6E28
            
        case .others:
            return 0xFF1E_90FF
        }
    }
    
    /// Localised String of Tissue Labels
    var localisedText: String {
        return NSLocalizedString(self.rawValue, comment: "")
    }
}
