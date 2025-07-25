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
    @State private var isRefreshing = false
    @State private var refreshAngle = 0.0
    @State private var currentTab = 0
    
    var body: some View {
        OrientationLockedView {
            VStack {
                TabView(selection: $currentTab) {
                    ZStack(alignment: .topTrailing) {
                        StandingClockView()
                            .environmentObject(healthKitManager)
                        
                        Button(action: {
                            withAnimation {
                                isRefreshing = true
                            }
                            healthKitManager.forceRefresh {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                    withAnimation {
                                        isRefreshing = false
                                    }
                                }
                            }
                        }) {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(.white)
                                .padding(10)
                                .background(Color("RingActive"))
                                .clipShape(Circle())
                                .shadow(color: Color.black.opacity(0.2), radius: 4, x: 0, y: 2)
                        }
                        .padding()
                        .disabled(isRefreshing)
                        .opacity(isRefreshing ? 0.6 : 1.0)
                        
                        if isRefreshing {
                            ZStack {
                                Color.black.opacity(0.2)
                                    .edgesIgnoringSafeArea(.all)
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(1.5)
                            }
                        }
                    }
                    .tag(0)

                    MovementSummaryView()
                        .environmentObject(healthKitManager)
                        .tag(1)
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                
                HStack(spacing: 8) {
                    Circle()
                        .fill(currentTab == 0 ? Color.white : Color.gray.opacity(0.5))
                        .frame(width: 8, height: 8)
                    Circle()
                        .fill(currentTab == 1 ? Color.white : Color.gray.opacity(0.5))
                        .frame(width: 8, height: 8)
                }
                .padding(.bottom, 10)
            }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(HealthKitManager())
}
