import SwiftUI
import HealthKit

struct StandingClockView: View {
    @EnvironmentObject private var healthKitManager: HealthKitManager
    @State private var standingData: [StandingData] = []
    
    let mainHours = [0, 3, 6, 9, 12, 15, 18, 21]
    let mainLabels = ["12am", "3am", "6am", "9am", "12pm", "3pm", "6pm", "9pm"]
    let clockSize: CGFloat = 300
    let ringWidth: CGFloat = 24
    let labelRadiusOffset: CGFloat = 24 // Closer to the ring
    let dotRadiusOffset: CGFloat = 24   // Dots outside the ring, aligned with labels
    
    var body: some View {
        GeometryReader { geometry in
            let screenHeight = geometry.size.height
            let ringTotalHeight = clockSize
            let centerY = screenHeight / 2
            let adaptiveLightGrey = Color(UIColor.systemGray5)
            let adaptiveDarkGrey = Color(UIColor.systemGray)
            let adaptiveBackground = Color(.systemBackground)
            let adaptiveText = Color.primary
            
            ZStack {
                adaptiveBackground.ignoresSafeArea()
                
                // Ring and labels centered at screen center
                VStack(spacing: 0) {
                    Spacer()
                        .frame(height: centerY - ringTotalHeight / 2 - 40) // 40 for title spacing
                    // Title above ring
                    Text("Today's Standing Activity")
                        .font(.title2)
                        .bold()
                        .multilineTextAlignment(.center)
                        .foregroundColor(adaptiveText)
                        .frame(maxWidth: .infinity)
                        .padding(.bottom, 60) // Padding between title and ring
                    // Ring
                    ZStack {
                        // Background ring
                        Circle()
                            .stroke(adaptiveLightGrey, lineWidth: ringWidth)
                            .frame(width: clockSize, height: clockSize)
                        // Major hour labels (outside the ring)
                        ForEach(Array(mainHours.enumerated()), id: \ .offset) { idx, hour in
                            HourLabel(label: mainLabels[idx], hour: hour, clockSize: clockSize, ringWidth: ringWidth, labelRadiusOffset: labelRadiusOffset, adaptiveText: adaptiveText)
                        }
                        // Dots for every hour except main label hours, outside the ring
                        ForEach(0..<24) { hour in
                            if !mainHours.contains(hour) {
                                MinorHourDot(hour: hour, clockSize: clockSize, ringWidth: ringWidth, dotRadiusOffset: dotRadiusOffset, adaptiveText: adaptiveText)
                            }
                        }
                        // Activity arc (thick)
                        ForEach(0..<24) { hour in
                            if let data = standingData.first(where: { $0.hour == hour }) {
                                StandingArcSegment(
                                    hour: hour,
                                    didStand: data.didStand,
                                    hasData: true,
                                    ringWidth: ringWidth,
                                    clockSize: clockSize,
                                    lightGrey: adaptiveLightGrey,
                                    darkGrey: adaptiveDarkGrey
                                )
                            } else {
                                StandingArcSegment(
                                    hour: hour,
                                    didStand: false,
                                    hasData: false,
                                    ringWidth: ringWidth,
                                    clockSize: clockSize,
                                    lightGrey: adaptiveLightGrey,
                                    darkGrey: adaptiveDarkGrey
                                )
                            }
                        }
                        // Center text showing current time
                        VStack {
                            Text(timeString)
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                                .monospacedDigit()
                                .foregroundColor(adaptiveText)
                            Text("since last stand")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .frame(width: clockSize, height: clockSize)
                    .padding(.bottom, 60) // Padding between ring and legend
                    // Legend below ring
                    HStack(spacing: 20) {
                        LegendItem(color: .green, label: "Standing")
                        LegendItem(color: adaptiveDarkGrey, label: "Sitting")
                        LegendItem(color: adaptiveLightGrey, label: "No Data")
                    }
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)
                    .padding(.top, 0)
                    .foregroundColor(adaptiveText)
                    Spacer()
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
            }
        }
        .onAppear {
            fetchStandingData()
        }
    }
    
    private var timeString: String {
        let hours = Int(healthKitManager.timeSinceLastStand) / 3600
        let minutes = Int(healthKitManager.timeSinceLastStand) / 60 % 60
        return String(format: "%02d:%02d", hours, minutes)
    }
    
    private func fetchStandingData() {
        let calendar = Calendar.current
        let now = Date()
        let startOfDay = calendar.startOfDay(for: now)
        
        let predicate = HKQuery.predicateForSamples(
            withStart: startOfDay,
            end: now,
            options: .strictStartDate
        )
        
        let query = HKSampleQuery(
            sampleType: HKObjectType.categoryType(forIdentifier: .appleStandHour)!,
            predicate: predicate,
            limit: HKObjectQueryNoLimit,
            sortDescriptors: nil
        ) { _, samples, error in
            guard let samples = samples as? [HKCategorySample], error == nil else {
                return
            }
            
            var data: [StandingData] = []
            for hour in 0..<24 {
                let hourDate = calendar.date(byAdding: .hour, value: hour, to: startOfDay)!
                let didStand = samples.contains { sample in
                    calendar.component(.hour, from: sample.startDate) == hour
                }
                data.append(StandingData(hour: hour, didStand: didStand, date: hourDate))
            }
            
            DispatchQueue.main.async {
                self.standingData = data
            }
        }
        
        healthKitManager.healthStore.execute(query)
    }
}

struct HourLabel: View {
    let label: String
    let hour: Int
    let clockSize: CGFloat
    let ringWidth: CGFloat
    let labelRadiusOffset: CGFloat
    let adaptiveText: Color
    
    var body: some View {
        Text(label)
            .font(.system(size: 13, weight: .bold))
            .foregroundColor(adaptiveText)
            .shadow(color: Color(.systemBackground).opacity(0.2), radius: 1, x: 0, y: 1)
            .position(labelPosition(radius: clockSize / 2 + ringWidth / 2 + labelRadiusOffset))
    }
    
    private func labelPosition(radius: CGFloat) -> CGPoint {
        let angle = Double(hour) * 15 - 90
        let rad = angle * .pi / 180
        let x = cos(rad) * Double(radius) + Double(clockSize / 2)
        let y = sin(rad) * Double(radius) + Double(clockSize / 2)
        return CGPoint(x: x, y: y)
    }
}

struct MinorHourDot: View {
    let hour: Int
    let clockSize: CGFloat
    let ringWidth: CGFloat
    let dotRadiusOffset: CGFloat
    let adaptiveText: Color
    
    var body: some View {
        Circle()
            .fill(adaptiveText)
            .frame(width: 5, height: 5)
            .position(dotPosition(radius: clockSize / 2 + ringWidth / 2 + dotRadiusOffset))
    }
    
    private func dotPosition(radius: CGFloat) -> CGPoint {
        let angle = Double(hour) * 15 - 90
        let rad = angle * .pi / 180
        let x = cos(rad) * Double(radius) + Double(clockSize / 2)
        let y = sin(rad) * Double(radius) + Double(clockSize / 2)
        return CGPoint(x: x, y: y)
    }
}

struct StandingArcSegment: View {
    let hour: Int
    let didStand: Bool
    let hasData: Bool
    let ringWidth: CGFloat
    let clockSize: CGFloat
    let lightGrey: Color
    let darkGrey: Color
    
    var body: some View {
        Circle()
            .trim(from: startAngle, to: endAngle)
            .stroke(segmentColor, lineWidth: ringWidth)
            .frame(width: clockSize, height: clockSize)
            .rotationEffect(.degrees(-90))
    }
    
    private var segmentColor: Color {
        if !hasData {
            return lightGrey
        } else if didStand {
            return .green
        } else {
            return darkGrey
        }
    }
    
    private var startAngle: Double {
        Double(hour) / 24.0
    }
    
    private var endAngle: Double {
        Double(hour + 1) / 24.0
    }
}

struct LegendItem: View {
    let color: Color
    let label: String
    
    var body: some View {
        HStack {
            Circle()
                .fill(color)
                .frame(width: 12, height: 12)
            Text(label)
                .font(.caption)
        }
    }
}

#Preview {
    StandingClockView()
        .environmentObject(HealthKitManager())
} 