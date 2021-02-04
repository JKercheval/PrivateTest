//
//  DashboardViewController.swift
//  Scratch
//
//  Created by Jeremy Kercheval on 1/7/21.
//

import UIKit
import PureLayout

class DashboardViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        debugPrint("\(self):\(#function)")

        // Do any additional setup after loading the view.
        createDashboardView(dashboardViewContainer: self.view)
    }
    
    private func createDashboardView(dashboardViewContainer : UIView) {
        // Get the number of types so that we can use that when setting up constraints.
        let numDashboards = DashboardType.allCases.count
        var dashboard = [UIView]()
        
        // Loop through each, create a view
        for dashboardTypes in DashboardType.allCases {
            let model = DashboardViewModel(type: dashboardTypes)
            let dashView = DashboardView(model: model)
            dashboardViewContainer.addSubview(dashView)
            dashboard.append(dashView)
            dashView.autoPinEdge(toSuperviewEdge: .top)
            dashView.autoPinEdge(toSuperviewEdge: .bottom)
        }
        
        let dashboardArray : NSArray = dashboard as NSArray
        dashboardArray.autoDistributeViews(along: .horizontal, alignedTo: .horizontal, withFixedSpacing: 0)
    }


    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

}
