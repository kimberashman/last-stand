import SwiftUI
import HealthKit
import Foundation
struct StepInterval {
    let startDate: Date
    let endDate: Date
    let stepCount: Int
}

let ringActiveColor = Color(red: 0.95, green: 0.27, blue: 0.49)    // pink/magenta
let ringPartialColor = Color(red: 1.0, green: 0.5, blue: 0.3)      // coral/orange
let ringInactiveColor = Color(red: 0.22, green: 0.39, blue: 0.44)  // teal-grey
let backgroundColor = Color(.systemBackground)
let textColor = Color.white

struct ActivitySegment: Identifiable {
    let id = UUID()
    let start: Date
    let end: Date
    let isActive: Bool?
}

struct StandingClockView: View {
    @EnvironmentObject private var healthKitManager: HealthKitManager
    @State private var activitySegments: [ActivitySegment] = []
    @State private var lastStandInterval: Date? = nil
    @State private var intervals: [StepInterval] = []
    
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
                        ForEach(Array(mainHours.enumerated()), id: \ .offset) { idx, hour in
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
                        // Fine-grained activity segments (5-min intervals)
                        ForEach(activitySegments.indices, id: \.self) { idx in
                            let segment = activitySegments[idx]
                            let color: Color = {
                                switch segment.isActive {
                                case .some(true):
                                    return ringActiveColor
                                case .some(false):
                                    return ringPartialColor
                                case .none:
                                    return ringInactiveColor
                                }
                            }()

                            FineArcSegment(
                                index: idx,
                                total: activitySegments.count,
                                color: color,
                                ringWidth: ringWidth,
                                clockSize: clockSize
                            )
                            .frame(width: clockSize, height: clockSize)
                            .position(x: totalDiameter / 2, y: totalDiameter / 2)
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
            fetchActivitySegments()
            let manager = healthKitManager
            manager.fetchStepCountsByInterval { stepCounts in
                let mapped = stepCounts.map { (date, steps) in
                    print("🧭 Mapped interval: \(date) → \(steps) steps")
                    return StepInterval(startDate: date, endDate: date.addingTimeInterval(120), stepCount: Int(steps))
                }
                DispatchQueue.main.async {
                    self.intervals = mapped.sorted { $0.startDate < $1.startDate }
                    self.lastStandInterval = computeLastStandInterval(from: self.intervals)
                }
            }
        }
    }
    
    private var timeString: String {
        let now = Date()
        if let lastStand = lastStandInterval {
            let timeSince = now.timeIntervalSince(lastStand)
            let hours = Int(timeSince) / 3600
            let minutes = Int(timeSince) / 60 % 60
            return String(format: "%02d:%02d", hours, minutes)
        } else {
            return "--:--"
        }
    }
    
    private func computeLastStandInterval(from intervals: [StepInterval]) -> Date? {
        let now = Date()
        if let recent = intervals.reversed().first(where: { interval in
            let isRecent = now.timeIntervalSince(interval.startDate) < 15 * 60 // 15 minutes
            let recentEnough = interval.stepCount >= 8 && isRecent // reduced threshold
            print("🔍 Checking interval at \(interval.startDate): \(interval.stepCount) steps, recent: \(isRecent) → valid: \(recentEnough)")
            return recentEnough
        }) {
            print("✅ Found valid standing interval at \(recent.startDate) with \(recent.stepCount) steps")
            return recent.startDate
        } else {
            print("❌ No valid standing intervals found in the last 15 minutes")
            return nil
        }
    }
    
    private func fetchActivitySegments() {
        healthKitManager.fetchStepCountsByInterval { stepCounts in
            let calendar = Calendar.current
            let now = Date()
            let startOfDay = calendar.startOfDay(for: now)
            var segments: [ActivitySegment] = []
            var anchor = startOfDay
            for _ in 0..<288 { // 24*12 = 288 intervals
                let end = calendar.date(byAdding: .minute, value: 5, to: anchor)!
                if let steps = stepCounts[anchor] {
                    print("🪵 Interval starting at \(anchor): Steps = \(steps)")
                    let isActive: Bool?
                    if steps >= 8 { // reduced threshold
                        isActive = true
                    } else if steps == 0 {
                        isActive = false
                    } else {
                        isActive = nil
                    }
                    segments.append(ActivitySegment(start: anchor, end: end, isActive: isActive))
                } else {
                    segments.append(ActivitySegment(start: anchor, end: end, isActive: nil))
                }
                anchor = end
            }
            print("📊 Total intervals processed: \(stepCounts.count)")
            self.activitySegments = segments.sorted { $0.start < $1.start }
        }
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

struct FineArcSegment: View {
    let index: Int
    let total: Int
    let color: Color
    let ringWidth: CGFloat
    let clockSize: CGFloat
    
    var body: some View {
        Circle()
            .trim(from: startAngle, to: endAngle)
            .stroke(color, lineWidth: ringWidth)
            .frame(width: clockSize, height: clockSize)
            .rotationEffect(.degrees(-90))
    }
    
    private var startAngle: Double {
        Double(index) / Double(total)
    }
    
    private var endAngle: Double {
        Double(index + 1) / Double(total)
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
