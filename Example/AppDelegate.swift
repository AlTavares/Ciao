//
//  AppDelegate.swift
//  Example
//
//  Created by Alexandre Mantovani Tavares on 15/07/19.
//

import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        let window = UIWindow(frame: UIScreen.main.bounds)
        self.window = window
        window.rootViewController = UINavigationController(rootViewController: DomainsViewController(domains: "local", "dns-sd.org"))
        window.makeKeyAndVisible()
        return true
    }
}
