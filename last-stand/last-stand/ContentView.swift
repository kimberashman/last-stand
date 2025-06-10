//
//  ContentView.swift
//  last-stand
//
//  Created by Kimberly Ashman on 6/7/25.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var healthKitManager: HealthKitManager
    @State private var isRefreshing = false
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color(uiColor: .systemBackground).ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 20) {
                    if !healthKitManager.isAuthorized {
                        authorizationView
                    } else {
                        StandingClockView()
                    }
                }
                .padding()
                .frame(maxWidth: .infinity)
            }

            if healthKitManager.isAuthorized {
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.6)) {
                        isRefreshing = true
                    }
                        DispatchQueue.main.async {
                            isRefreshing = false
                        }
                    
                }) {
                    Image(systemName: "arrow.clockwise")
                        .rotationEffect(isRefreshing ? .degrees(360) : .degrees(0))
                        .animation(isRefreshing ? .easeInOut(duration: 1).repeatCount(1, autoreverses: false) : .default, value: isRefreshing)
                        .imageScale(.large)
                }
                .padding()
                .accessibilityHint("Immediately re-checks your stand data")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
            .accessibilityHint("Grants permission to access your Health data")
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(HealthKitManager())
}
