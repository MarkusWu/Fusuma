//
//  FSConstants.swift
//  Fusuma
//
//  Created by Yuta Akizuki on 2015/08/31.
//  Copyright © 2015年 ytakzk. All rights reserved.
//

import UIKit

// Extension
internal extension UIColor {
    
    class func hex (_ hexStr : NSString, alpha : CGFloat) -> UIColor {
        
        let realHexStr = hexStr.replacingOccurrences(of: "#", with: "")
        let scanner = Scanner(string: realHexStr as String)
        var color: UInt32 = 0
        if scanner.scanHexInt32(&color) {
            let r = CGFloat((color & 0xFF0000) >> 16) / 255.0
            let g = CGFloat((color & 0x00FF00) >> 8) / 255.0
            let b = CGFloat(color & 0x0000FF) / 255.0
            return UIColor(red:r,green:g,blue:b,alpha:alpha)
        } else {
            print("invalid hex string", terminator: "")
            return UIColor.white
        }
    }
}

extension UIView {
    
    /**
     Add bottom border to itself.
     - parameters:
         - color: color of border.
         - width: width of border. For nil, View.frame.width is used.
         - height: height of border.
     */
    func addBottomBorder(_ color: UIColor, width: CGFloat?, height: CGFloat) {
        
        let border = CALayer()
        border.borderColor = color.cgColor
        
        let width = width ?? self.frame.width
        
        border.frame = CGRect(x: 0, y: self.frame.size.height - height, width: width, height: height)
        border.borderWidth = height//width
        self.layer.addSublayer(border)
    }

}
