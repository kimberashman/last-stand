//
//  last_standApp.swift
//  last-stand
//
//  Created by Kimberly Ashman on 6/7/25.
//

import SwiftUI
import UIKit

@main
struct last_standApp: App {
    @StateObject private var healthKitManager = HealthKitManager()
    
    init() {
        // Lock orientation to portrait
        AppDelegate.orientationLock = .portrait
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(healthKitManager)
        }
    }
}

// Add AppDelegate to handle orientation lock
class AppDelegate: NSObject {
    static var orientationLock = UIInterfaceOrientationMask.portrait {
        didSet {
            if #available(iOS 16.0, *) {
                UIApplication.shared.connectedScenes.forEach { scene in
                    if let windowScene = scene as? UIWindowScene {
                        windowScene.requestGeometryUpdate(.iOS(interfaceOrientations: orientationLock))
                    }
                }
            }
        }
    }
}
