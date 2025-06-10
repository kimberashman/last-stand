import SwiftUI
import HealthKit

let ringActiveColor = Color(red: 0.95, green: 0.27, blue: 0.49)    // pink/magenta
let ringPartialColor = Color(red: 1.0, green: 0.5, blue: 0.3)      // coral/orange
let ringInactiveColor = Color(red: 0.22, green: 0.39, blue: 0.44)  // teal-grey
let backgroundColor = Color(.systemBackground)
let textColor = Color.white

struct StandingClockView: View {
    @EnvironmentObject private var healthKitManager: HealthKitManager
    @State private var standingData: [StandingData] = []
    
    let mainHours = [0, 3, 6, 9, 12, 15, 18, 21]
    let mainLabels = ["12am", "3am", "6am", "9am", "12pm", "3pm", "6pm", "9pm"]
    let clockSize: CGFloat = 260
    let ringWidth: CGFloat = 24
    var labelRadiusOffset: CGFloat {
        ringWidth / 2 + 14
    }
    var dotRadiusOffset: CGFloat {
        ringWidth / 2 + 14
    }
    
    var body: some View {
        GeometryReader { geometry in
            let labelPadding: CGFloat = 48
            let totalDiameter = clockSize + 2 * labelPadding

            ZStack {
                Color(backgroundColor)

                // Centered container for ring + labels using Spacer-based centering
                VStack {
                    Spacer().frame(minHeight: 110)
                    ZStack {
                        // Background ring
                        Circle()
                            .stroke(ringInactiveColor, lineWidth: ringWidth)
                            .frame(width: clockSize, height: clockSize)
                            .position(x: totalDiameter / 2, y: totalDiameter / 2)

                        // Major hour labels (outside the ring)
                        ForEach(Array(mainHours.enumerated()), id: \.offset) { idx, hour in
                            HourLabel(
                                label: mainLabels[idx],
                                hour: hour,
                                clockSize: clockSize,
                                ringWidth: ringWidth,
                                labelRadiusOffset: labelRadiusOffset,
                                adaptiveText: textColor,
                                containerSize: totalDiameter
                            )
                        }
                        // Dots for every hour except main label hours, outside the ring
                        ForEach(0..<24) { hour in
                            if !mainHours.contains(hour) {
                                MinorHourDot(
                                    hour: hour,
                                    clockSize: clockSize,
                                    ringWidth: ringWidth,
                                    dotRadiusOffset: dotRadiusOffset,
                                    adaptiveText: textColor,
                                    containerSize: totalDiameter
                                )
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
                                    lightGrey: ringInactiveColor,
                                    darkGrey: ringPartialColor
                                )
                                .frame(width: clockSize, height: clockSize)
                                .position(x: totalDiameter / 2, y: totalDiameter / 2)
                            } else {
                                StandingArcSegment(
                                    hour: hour,
                                    didStand: false,
                                    hasData: false,
                                    ringWidth: ringWidth,
                                    clockSize: clockSize,
                                    lightGrey: ringInactiveColor,
                                    darkGrey: ringPartialColor
                                )
                                .frame(width: clockSize, height: clockSize)
                                .position(x: totalDiameter / 2, y: totalDiameter / 2)
                            }
                        }
                        // Center text showing current time
                        VStack {
                            Text(timeString)
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                                .monospacedDigit()
                                .foregroundColor(textColor)
                            Text("since last stand")
                                .font(.caption)
                                .foregroundColor(textColor.opacity(0.6))
                        }
                        .position(x: totalDiameter / 2, y: totalDiameter / 2)
                    }
                    .frame(width: totalDiameter, height: totalDiameter)
                    Spacer().frame(minHeight: 110)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                // Title at the top (overlay, not affecting centering)
                VStack {
                    Text("Today's Standing Activity")
                        .font(.title2)
                        .bold()
                        .multilineTextAlignment(.center)
                        .foregroundColor(textColor)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 40)
                        .padding(.bottom, 20)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

                // Legend at the bottom (overlay, not affecting centering)
                VStack {
                    Spacer()
                    HStack(spacing: 30) {
                        LegendItem(color: ringActiveColor, label: "Standing")
                        LegendItem(color: ringPartialColor, label: "Sitting")
                        LegendItem(color: ringInactiveColor, label: "No Data")
                    }
                    .multilineTextAlignment(.center)
                    .foregroundColor(textColor)
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 32)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            }
            .ignoresSafeArea()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()
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
                let hourStart = calendar.date(byAdding: .hour, value: hour, to: startOfDay)!
                let hourEnd = calendar.date(byAdding: .hour, value: hour + 1, to: startOfDay)!
                let didStand = samples.contains { sample in
                    sample.startDate >= hourStart &&
                    sample.startDate < hourEnd &&
                    sample.value == HKCategoryValueAppleStandHour.stood.rawValue
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
    let containerSize: CGFloat

    var body: some View {
        Text(label)
            .font(.system(size: 12, weight: .medium))
            .fixedSize()
            .multilineTextAlignment(.center)
            .lineLimit(1)
            .foregroundColor(adaptiveText)
            .shadow(color: Color(.systemBackground).opacity(0.2), radius: 1, x: 0, y: 1)
            .frame(width: 40)
            .allowsTightening(true)
            .position(labelPosition(radius: clockSize / 2 + labelRadiusOffset))
    }

    private func labelPosition(radius: CGFloat) -> CGPoint {
        let angle = Double(hour) * 15 - 90
        let rad = angle * .pi / 180
        let x = cos(rad) * Double(radius) + Double(containerSize / 2)
        let y = sin(rad) * Double(radius) + Double(containerSize / 2)
        return CGPoint(x: x, y: y)
    }
}

struct MinorHourDot: View {
    let hour: Int
    let clockSize: CGFloat
    let ringWidth: CGFloat
    let dotRadiusOffset: CGFloat
    let adaptiveText: Color
    let containerSize: CGFloat

    var body: some View {
        Circle()
            .fill(adaptiveText)
            .frame(width: 5, height: 5)
            .position(dotPosition(radius: clockSize / 2 + dotRadiusOffset))
    }

    private func dotPosition(radius: CGFloat) -> CGPoint {
        let angle = Double(hour) * 15 - 90
        let rad = angle * .pi / 180
        let x = cos(rad) * Double(radius) + Double(containerSize / 2)
        let y = sin(rad) * Double(radius) + Double(containerSize / 2)
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
            return ringInactiveColor
        } else if didStand {
            return ringActiveColor
        } else {
            return ringPartialColor
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
