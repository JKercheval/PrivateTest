//
//  DaashboardView.swift
//  Scratch
//
//  Created by Jeremy Kercheval on 2/4/21.
//

import UIKit

class DashboardView: UIView {

    var viewModel : DashboardViewModel!
    
    override init(frame: CGRect) {
        super.init(frame: frame)
    }
    
    convenience init(model : DashboardViewModel) {
        self.init(frame: CGRect.zero)
        self.viewModel = model
        self.backgroundColor = UIColor.white
        self.layer.borderWidth = 2
        self.layer.borderColor = UIColor.red.cgColor
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    /*
    // Only override draw() if you perform custom drawing.
    // An empty implementation adversely affects performance during animation.
    override func draw(_ rect: CGRect) {
        // Drawing code
    }
    */

}
