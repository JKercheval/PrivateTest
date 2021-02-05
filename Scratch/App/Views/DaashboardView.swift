//
//  DaashboardView.swift
//  Scratch
//
//  Created by Jeremy Kercheval on 2/4/21.
//

import UIKit
import PureLayout

extension DashboardView: NameDescribable {}
class DashboardView: UIView {

    @objc var viewModel : DashboardViewModel!
    var valueLabel : UILabel!
    var titleLabel : UILabel!
    var uomLabel : UILabel!
    
    var observation: NSKeyValueObservation?

    override init(frame: CGRect) {
        super.init(frame: frame)
    }
    
    convenience init(model : DashboardViewModel) {
        self.init(frame: CGRect.zero)
        self.viewModel = model
        self.backgroundColor = UIColor.cyan.withAlphaComponent(0.6)
        self.layer.borderWidth = 2
        self.layer.borderColor = UIColor.red.cgColor
        
        createSubViews()
        self.titleLabel.text = model.title
        self.uomLabel.text = model.unitOfMeasure
        
        setNeedsUpdateConstraints()
        self.viewModel.delegate = self
    }
    
    func createSubViews() {
        self.valueLabel = UILabel(forAutoLayout: ())
        self.valueLabel.textColor = UIColor.black
        self.valueLabel.textAlignment = .center
        self.valueLabel.backgroundColor = UIColor.red.withAlphaComponent(0.5)
        self.addSubview(valueLabel)
        valueLabel.autoMatch(.width, to: .width, of: self, withMultiplier: 0.5)
        valueLabel.autoMatch(.height, to: .height, of: self, withMultiplier: 0.5)
        valueLabel.autoCenterInSuperview()
        
        self.titleLabel = UILabel(forAutoLayout: ())
        self.titleLabel.textColor = UIColor.black
        self.titleLabel.textAlignment = .center
        self.addSubview(self.titleLabel)
        self.titleLabel.autoPinEdgesToSuperviewEdges(with: UIEdgeInsets(top: 5, left: 5, bottom: 5, right: 5), excludingEdge: .bottom)
        self.titleLabel.autoSetDimension(.height, toSize: 30, relation: .equal)

        self.uomLabel = UILabel(forAutoLayout: ())
        self.uomLabel.textColor = UIColor.black
        self.uomLabel.textAlignment = .center
        self.addSubview(self.uomLabel)
        self.uomLabel.autoPinEdgesToSuperviewEdges(with: UIEdgeInsets(top: 5, left: 5, bottom: 5, right: 5), excludingEdge: .top)
        self.uomLabel.autoSetDimension(.height, toSize: 30, relation: .equal)

        self.setNeedsLayout()
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

extension DashboardView : DashboardViewModelProtocolDelegate {
    func valueChanged(_ value: String) {
        self.valueLabel.text = value
    }
    
}
