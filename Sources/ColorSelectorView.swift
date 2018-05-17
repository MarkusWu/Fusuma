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
    func colorSelectorView(_ v: ColorSelectorView, diSelectAtIndex index: Int)
    func colorSelectorView(_ v: ColorSelectorView, didLongPressSelectedColor gr: UILongPressGestureRecognizer)
}

class ColorSelectorView: UIView, UIScrollViewDelegate {
    
    weak var delegate: ColorSelectorViewDelegate?
    
    private(set) var colorButtons: [RoundedButton] = []
    
    private(set) var colorButtonWidth: CGFloat = 20.0
    
    var fadeLength: CGFloat = 8.0
    
    @IBOutlet private(set) weak var scrollView: UIScrollView!
    
    var colorAlpha: CGFloat = 1.0 {
        didSet {
            for b in self.colorButtons {
                if let color = b.backgroundColor {
                    b.backgroundColor = color.withAlphaComponent(self.colorAlpha)
                }
            }
        }
    }
    
    var selectedColorButton: RoundedButton! {
        willSet {
            if self.selectedColorButton != nil {
                
                let center = self.selectedColorButton.center
                
                self.selectedColorButton.borderColor = UIColor.white
                self.selectedColorButton.borderWidth = 1.5
                
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
                
                self.selectedColorButton.borderColor = UIColor.white
                self.selectedColorButton.borderWidth = 3.0
                
                UIView.animate(withDuration: 0.3, animations: {
                    self.selectedColorButton.frame.size = CGSize(width: width, height: width)
                    
                    self.selectedColorButton.cornerRadius = width / 2.0
                    
                    self.selectedColorButton.center = center
                }, completion: nil)
            }
        }
    }
    
    override func layoutSubviews() {
        
        super.layoutSubviews()
        
        let maskLayer = CALayer()
        maskLayer.frame = self.bounds
        
        let transparent = UIColor.clear.cgColor
        let opaque = UIColor.black.cgColor
        
        let gradientLayer = CAGradientLayer()
        gradientLayer.frame = CGRect(x: self.bounds.origin.x, y: 0, width: self.bounds.size.width, height: self.bounds.size.height)
        gradientLayer.colors = [transparent, opaque, opaque, transparent]
        
        //If startPoint and endPoint specified, fade left right. Otherwise, top bottom.
        gradientLayer.startPoint = CGPoint(x: 0, y: 0.5)
        gradientLayer.endPoint = CGPoint(x: 1, y: 0.5)
        
        var locations: [NSNumber] = []
        
        let fadePercentage = Double(fadeLength / self.frame.width)
        
        let xOffset = self.scrollView.contentOffset.x
        
        locations.append(0)
        
        if xOffset > 0 {
            locations.append(NSNumber(floatLiteral: fadePercentage))
        } else {
            locations.append(0)
        }
        
        if xOffset + self.frame.width < self.scrollView.contentSize.width {
            locations.append(NSNumber(floatLiteral: 1 - fadePercentage))
        } else {
            locations.append(1)
        }
        
        locations.append(1)
        
        gradientLayer.locations = locations
        
        maskLayer.addSublayer(gradientLayer)
        self.layer.mask = maskLayer
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
        
        self.scrollView.delegate = self
        
        self.colorButtonWidth = colorButtonWidth
        
        var interval = frame.width / CGFloat(colors.count)
        
        let minInterval = colorButtonWidth + 10
        
        if interval < minInterval {
            let maxItems = Int(frame.width / CGFloat(minInterval))
            
            let numberOfItems = CGFloat(maxItems) - 0.5
            
            interval = frame.width / numberOfItems
            
            self.scrollView.alwaysBounceHorizontal = true
        } else {
            self.scrollView.alwaysBounceHorizontal = false
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
            button.borderWidth = 1.5
            button.center = center
            button.tag = i
            
            let longPress = UILongPressGestureRecognizer(target: self, action: #selector(self.selectedColorButtonLongPressed(_:)))
            button.addGestureRecognizer(longPress)
            
            button.addTarget(self, action: #selector(self.colorButtonTapped(_:)), for: .touchUpInside)
            
            self.scrollView.addSubview(button)
            self.colorButtons.append(button)
        }
        
        let width = interval * CGFloat(colors.count)
        
        self.scrollView.contentSize = CGSize(width: width, height: self.frame.height)
        
        self.selectColorAt(selectedIndex)
    }
    
    // MARK: - Utilities
    
    func makeSelectedColorVisible() {
        if let b = self.selectedColorButton {
            let xOffset = self.scrollView.contentOffset.x
            let diff = b.frame.maxX - self.frame.width
            
            if diff > xOffset {
                self.scrollView.setContentOffset(CGPoint(x: diff, y: 0), animated: false)
            }
        }
    }
    
    // MARK: - User interactions
    
    @objc func selectedColorButtonLongPressed(_ gr: UILongPressGestureRecognizer) {
        guard let button = gr.view as? RoundedButton else {
            return
        }
        
        if button === self.selectedColorButton {
        } else {
            if gr.state == .began {
                self.colorButtonTapped(button)
            }
        }
        
        self.delegate?.colorSelectorView(self, didLongPressSelectedColor: gr)
    }
    
    @objc func colorButtonTapped(_ sender: RoundedButton) {
        
        if self.selectedColorButton !== sender {
            self.selectedColorButton = sender
        }
        
        if let color = sender.backgroundColor {
            self.delegate?.colorSelectorView(self, didSelectColor: color)
            self.delegate?.colorSelectorView(self, diSelectAtIndex: sender.tag)
        }
    }
    
    func selectColorAt(_ index: Int) {
        guard self.colorButtons.indices.contains(index) else {
            return
        }
        
        self.colorButtonTapped(self.colorButtons[index])
    }
    
    // MARK: - Scroll view delegate
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if scrollView == self.scrollView {
            self.layoutSubviews()
        }
    }
}
