//
//  last_standApp.swift
//  last-stand
//
//  Created by Kimberly Ashman on 6/7/25.
//

import SwiftUI

@main
struct last_standApp: App {
    @StateObject private var healthKitManager = HealthKitManager()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(healthKitManager)
        }
    }
}
