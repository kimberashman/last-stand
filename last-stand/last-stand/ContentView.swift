//
//  ContentView.swift
//  last-stand
//
//  Created by Kimberly Ashman on 6/7/25.
//

import SwiftUI
import UIKit

// Add this struct to handle orientation lock
struct OrientationLockedView<Content: View>: UIViewControllerRepresentable {
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    func makeUIViewController(context: Context) -> UIHostingController<Content> {
        let controller = UIHostingController(rootView: content)
        controller.view.backgroundColor = .clear
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIHostingController<Content>, context: Context) {
        uiViewController.rootView = content
    }
}

struct ContentView: View {
    @EnvironmentObject private var healthKitManager: HealthKitManager
    
    var body: some View {
        OrientationLockedView {
            StandingClockView()
                .environmentObject(healthKitManager)
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(HealthKitManager())
}
