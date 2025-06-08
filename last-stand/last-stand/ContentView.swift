//
//  ContentView.swift
//  last-stand
//
//  Created by Kimberly Ashman on 6/7/25.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var healthKitManager: HealthKitManager
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if !healthKitManager.isAuthorized {
                    authorizationView
                } else {
                    StandingClockView()
                }
            }
            .padding()
        }
    }
    
    private var authorizationView: some View {
        VStack(spacing: 16) {
            Image(systemName: "lock.shield")
                .font(.system(size: 50))
                .foregroundColor(.blue)
            
            Text("Health Access Required")
                .font(.title2)
                .bold()
            
            Text("Last Stand needs access to your stand data to track when you last stood up.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
            
            Button("Grant Access") {
                healthKitManager.requestAuthorization()
            }
            .buttonStyle(.borderedProminent)
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(HealthKitManager())
}
