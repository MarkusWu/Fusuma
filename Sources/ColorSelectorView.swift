//
//  ColorSelectorView.swift
//  Fusuma
//
//  Created by Markus Wu on 7/25/17.
//  Copyright © 2017 ytakzk. All rights reserved.
//

import UIKit

protocol ColorSelectorViewDelegate: class {
    func colorSelectorView(_ v: ColorSelectorView, didSelectColor color: UIColor)
}

class ColorSelectorView: UIView {
    
    weak var delegate: ColorSelectorViewDelegate?
    
    private(set) var colorButtons: [RoundedButton] = []
    
    private(set) var colorButtonWidth: CGFloat = 20.0
    
    @IBOutlet private weak var scrollView: UIScrollView!
    
    var hasFadingEdge = true
    
    var selectedColorButton: RoundedButton! {
        willSet {
            if self.selectedColorButton != nil {
                
                let center = self.selectedColorButton.center
                
                UIView.animate(withDuration: 0.3, animations: {
                    self.selectedColorButton.cornerRadius = self.colorButtonWidth / 2.0
                  self.selectedColorButton.frame.size = CGSize(width: self.colorButtonWidth, height: self.colorButtonWidth)
                    self.selectedColorButton.center = center
                })
            }
        }
        
        didSet {
            if self.selectedColorButton != nil {
                let width = colorButtonWidth + 6
                
                let center = self.selectedColorButton.center
                
                UIView.animate(withDuration: 0.3, animations: {
                    self.selectedColorButton.frame.size = CGSize(width: width, height: width)
                    
                    self.selectedColorButton.cornerRadius = width / 2.0
                    
                    self.selectedColorButton.center = center
                }, completion: nil)
            }
        }
    }

    static func instance() -> ColorSelectorView {
        return UINib(nibName: "ColorSelectorView", bundle: Bundle(for: self.classForCoder())).instantiate(withOwner: self, options: nil)[0] as! ColorSelectorView
    }
    
    func initialize(frame: CGRect, colors: [UIColor], selectedIndex: Int = 0,  colorButtonWidth: CGFloat = 20.0) {
        
        guard self.colorButtons.isEmpty else {
            return
        }
        
        guard !colors.isEmpty else {
            return
        }
        
        self.frame = frame
        
        self.colorButtonWidth = colorButtonWidth
        
        var interval = frame.width / CGFloat(colors.count)
        
        let minInterval = colorButtonWidth + 6
        
        if interval < minInterval {
            let maxItems = Int(frame.width / CGFloat(minInterval))
            
            let numberOfItems = CGFloat(maxItems) - 0.5
            
            interval = frame.width / numberOfItems
            
            self.scrollView.alwaysBounceHorizontal = true
            self.hasFadingEdge = true
        } else {
            self.scrollView.alwaysBounceHorizontal = false
            self.hasFadingEdge = false
        }
        
        for i in 0..<colors.count {
            
            let color = colors[i]
            var center = CGPoint.zero
            center.x = interval / CGFloat(2) + interval * CGFloat(i)
            center.y = frame.height / 2
            
            let button = RoundedButton(frame: CGRect(x: 0, y: 0, width: colorButtonWidth, height: colorButtonWidth))
            
            button.backgroundColor = color
            button.cornerRadius = colorButtonWidth / 2.0
            button.borderColor = UIColor.white
            button.borderWidth = 1.8
            button.center = center
            
            button.addTarget(self, action: #selector(self.colorButtonTapped(_:)), for: .touchUpInside)
            
            self.scrollView.addSubview(button)
            self.colorButtons.append(button)
        }
        
        let width = interval * CGFloat(colors.count)
        
        self.scrollView.contentSize = CGSize(width: width, height: self.frame.height)
        
        self.selectColorAt(selectedIndex)
    }
    
    func colorButtonTapped(_ sender: RoundedButton) {
        
        if self.selectedColorButton === sender {
            return
        }
        
        debugPrint("color button is tapped: \(sender.backgroundColor!)")
        if let color = sender.backgroundColor {
            self.selectedColorButton = sender
            self.delegate?.colorSelectorView(self, didSelectColor: color)
        }
    }
    
    func selectColorAt(_ index: Int) {
        guard self.colorButtons.indices.contains(index) else {
            return
        }
        
        self.colorButtonTapped(self.colorButtons[index])
    }
    
    let fadeLength: CGFloat = 8.0
    
    override func layoutSubviews() {
        
        super.layoutSubviews()
        
        if self.hasFadingEdge {
            let transparent = UIColor.clear.cgColor
            let opaque = UIColor.white.cgColor
            
            let maskLayer = CALayer()
            maskLayer.frame = self.bounds
            
            let gradientLayer = CAGradientLayer()
            gradientLayer.frame = CGRect(x: self.bounds.origin.x, y: 0, width: self.bounds.size.width, height: self.bounds.size.height)
            gradientLayer.colors = [transparent, opaque, opaque, transparent]
            
            gradientLayer.startPoint = CGPoint(x: 0, y: 0.5)
            gradientLayer.endPoint = CGPoint(x: 1, y: 0.5)
            
            // fading top and bottom, if startPoint and endPoint specified. Otherwise, left and right.
            
            let fadePercentage = Double(self.fadeLength / self.frame.width)
            
            gradientLayer.locations = [
                0,
                NSNumber(floatLiteral: fadePercentage),
                NSNumber(floatLiteral: 1 - fadePercentage),
                1
            ]
            
            
            maskLayer.addSublayer(gradientLayer)
            self.layer.mask = maskLayer
        }
        }
}
