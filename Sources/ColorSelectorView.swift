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
    
    func initialize(frame: CGRect, colors: [UIColor], colorButtonWidth: CGFloat = 20.0) {
        
        guard self.colorButtons.isEmpty else {
            return
        }
        
        guard !colors.isEmpty else {
            return
        }
        
        self.frame = frame
        
        self.colorButtonWidth = colorButtonWidth
        
        let interval = max(frame.width / CGFloat(colors.count), colorButtonWidth)
        
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
            
            self.addSubview(button)
            self.colorButtons.append(button)
        }
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
}
