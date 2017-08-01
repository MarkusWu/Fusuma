//
//  PartialTransparentView.swift
//  Fusuma
//
//  Created by Markus Wu on 8/1/17.
//  Copyright © 2017 ytakzk. All rights reserved.
//

import UIKit

class PartialTransparentView: UIView {
    
    var transparentRects: [CGRect] = [] {
        didSet {
            self.setNeedsDisplay()
        }
    }
    
    override func draw(_ rect: CGRect) {
        
        super.draw(rect)
        
        guard let context = UIGraphicsGetCurrentContext() else {
            return
        }
        // Clear any existing drawing on this view
        // Remove this if the hole never changes on redraws of the UIView
        context.clear(self.bounds);

        // Create a path around the entire view
        //let clipPath = [UIBezierPath bezierPathWithRect:self.bounds];
        let clipPath = UIBezierPath(rect: self.bounds)
        
        for holdRect in self.transparentRects {
            
            // Add the transparent window
            
            let path = UIBezierPath(rect: holdRect)
            
            clipPath.append(path)
            
        }
        
        // This sets the algorithm used to determine what gets filled and what doesn't
        clipPath.usesEvenOddFillRule = true
        clipPath.addClip()
        // set your color
        fusumaBackgroundColor.setFill()
        
        clipPath.fill()
    }
}
