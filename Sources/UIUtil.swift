//
//  UIUtil.swift
//  Fusuma
//
//  Created by Markus Wu on 8/2/17.
//  Copyright © 2017 ytakzk. All rights reserved.
//

import UIKit

class UIUtil {
    static func hide(_ hide: Bool, view: UIView) {
        if hide {
            if view.alpha == 0.0 {
                return
            }
            
            UIView.animate(withDuration: 0.3, animations: {
                view.alpha = 0.0
            })
            
        } else {
            if view.alpha == 1.0 {
                return
            }
            
            UIView.animate(withDuration: 0.3, animations: {
                view.alpha = 1.0
            })
        }
    }
}
