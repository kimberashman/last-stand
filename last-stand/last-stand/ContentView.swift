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
        VStack(spacing: 20) {
            if !healthKitManager.isAuthorized {
                authorizationView
            } else {
                mainView
            }
        }
        .padding()
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
    
    private var mainView: some View {
        VStack(spacing: 24) {
            Text("Time Since Last Stand")
                .font(.title2)
                .foregroundColor(.secondary)
            
            Text(timeString)
                .font(.system(size: 60, weight: .bold, design: .rounded))
                .monospacedDigit()
            
            if let lastStand = healthKitManager.lastStandTime {
                Text("Last stood at \(lastStand.formatted(date: .omitted, time: .shortened))")
                    .foregroundColor(.secondary)
            }
            
            Button(action: {
                healthKitManager.fetchLastStandTime()
            }) {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.bordered)
        }
    }
    
    private var timeString: String {
        let hours = Int(healthKitManager.timeSinceLastStand) / 3600
        let minutes = Int(healthKitManager.timeSinceLastStand) / 60 % 60
        let seconds = Int(healthKitManager.timeSinceLastStand) % 60
        
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }
}

#Preview {
    ContentView()
        .environmentObject(HealthKitManager())
}
