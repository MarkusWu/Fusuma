//
//  MaterialView.swift
//  Fusuma
//
//  Created by Markus Wu on 7/30/17.
//  Copyright © 2017 ytakzk. All rights reserved.
//

import UIKit

class MaterialView: UIView {
    
    @IBInspectable
    var materialCornerRadius: CGFloat = 3.0 {
        
        didSet {
            let tmp = self.materialDesign
            self.materialDesign = tmp
        }
    }
    
    @IBInspectable
    var materialDesign: Bool = true {
        willSet {
            let materialKey = newValue
            if materialKey {
                self.layer.masksToBounds = false
                self.layer.cornerRadius = materialCornerRadius
                self.layer.shadowOpacity = 0.8
                self.layer.shadowRadius = materialCornerRadius
                self.layer.shadowOffset = CGSize(width: 0.0, height: 2.0)
                self.layer.shadowColor = UIColor(red: 157/255, green: 157/255, blue: 157/255, alpha: 1.0).cgColor
            } else {
                self.layer.cornerRadius = 0
                self.layer.shadowOpacity = 0
                self.layer.shadowRadius = 0
                self.layer.shadowColor = nil
            }
        }
    }
}
