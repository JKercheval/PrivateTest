import UIKit
import GoogleMaps

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    private let plottingRowManager = PlottingManager()
    private var applicationController : ApplicationControllerProtocol? = nil
    
    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        
        initializeApplicationControllers()
        return true
    }
    
    var plottingManager : PlottingManagerProtocol {
        return plottingRowManager
    }
    
    var appController : ApplicationControllerProtocol? {
        return applicationController
    }
    
}

extension AppDelegate {
    
    func initializeApplicationControllers() {
        let comms : CommunicationsProtocol = CommunicationsController()
        self.applicationController = AppController(commsController: comms)
    }
}
