import SwiftUI
import HealthKit

struct StepHour: Identifiable {
    let id = UUID()
    var hour: Int
    var activeMinutes: Int
    var totalMinutes: Int

    var activityRatio: Double {
        guard totalMinutes > 0 else { return 0 }
        return Double(activeMinutes) / Double(totalMinutes)
    }
}

class HourStepModel: ObservableObject {
    @Published var steps: [StepHour] = []
}

struct MovementSummaryView: View {
    @EnvironmentObject private var HealthKitManager: HealthKitManager
    @StateObject private var hourStepModel = HourStepModel()
    @State private var longestSedentaryStreak: Int = 0

    let workHours = 9...17
    let stepThreshold = 8

    var body: some View {
        VStack(spacing: 20) {
            Text("Today’s Activity")
                .font(.title2)
                .bold()

            HStack(spacing: 10) {
                ForEach(hourStepModel.steps) { hour in
                    VStack {
                        Circle()
                            .fill(fillColor(for: hour.hour))
                            .frame(width: 24, height: 24)
                        Text(hourLabel(for: hour.hour))
                            .font(.caption2)
                            .foregroundColor(textColor)
                    }
                }
            }

            Text("Active Hours: \(hourStepModel.steps.filter { $0.activityRatio > 0 }.count)/\(hourStepModel.steps.count)")
                .foregroundColor(textColor)
            Text("Longest Sedentary Period: \(longestSedentaryStreak) min")
                .foregroundColor(textColor.opacity(0.8))

            Spacer()
        }
        .padding()
        .background(backgroundColor)
        .onAppear {
            loadHourlySteps()
        }
    }

    private func loadHourlySteps() {
        HealthKitManager.fetchStepCountsByInterval { stepCounts in
            let calendar = Calendar.current
            let now = Date()
            let startOfDay = calendar.startOfDay(for: now)
            var results: [StepHour] = []
            for hour in workHours {
                let date = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: startOfDay)!
                var activeMinutes = 0
                var totalMinutes = 0

                for minute in 0..<60 {
                    let t = calendar.date(byAdding: .minute, value: minute, to: date)!
                    if let steps = stepCounts[t], steps > 0 {
                        activeMinutes += 1
                    }
                    totalMinutes += 1
                }

                results.append(StepHour(hour: hour, activeMinutes: activeMinutes, totalMinutes: totalMinutes))
            }

            // Compute the longest sedentary streak using minute-level stepCounts
            var currentStreak = 0
            var maxStreak = 0

            print("🕵️ Starting sedentary streak analysis for \(60 * 24) minutes")

            for minuteOffset in 0..<(60 * 24) {
                let minute = calendar.date(byAdding: .minute, value: minuteOffset, to: startOfDay)!
                let hourComponent = calendar.component(.hour, from: minute)
                guard workHours.contains(hourComponent) else { continue }
                guard let stepCount = stepCounts[minute] else {
                    print("⏱️ \(minute): no data")
                    currentStreak += 1
                    maxStreak = max(maxStreak, currentStreak)
                    continue
                }

                let steps = Int(stepCount)
                if steps == 0 {
                    currentStreak += 1
                    maxStreak = max(maxStreak, currentStreak)
                    print("😴 \(minute): \(steps) steps — currentStreak: \(currentStreak), maxStreak: \(maxStreak)")
                } else {
                    if currentStreak > 0 {
                        print("🚶‍♂️ \(minute): \(steps) steps — streak broken at \(currentStreak) min")
                    }
                    currentStreak = 0
                }
            }

            print("✅ Longest sedentary streak detected: \(maxStreak) min")

            DispatchQueue.main.async {
                self.hourStepModel.steps = results
                self.longestSedentaryStreak = maxStreak
            }
        }
    }
    
    private func hourLabel(for hour: Int) -> String {
        if hour == 12 {
            return "12pm"
        } else if hour > 12 {
            return "\(hour - 12)pm"
        } else {
            return "\(hour)am"
        }
    }

    // Helper to select fill color for the hour dot
    private func fillColor(for hour: Int) -> Color {
        guard let stepHour = hourStepModel.steps.first(where: { $0.hour == hour }) else {
            return ringInactiveColor
        }
        let ratio = stepHour.activityRatio
        let start = ringPartialColor.components
        let end = ringActiveColor.components
        let r = start.red + (end.red - start.red) * ratio
        let g = start.green + (end.green - start.green) * ratio
        let b = start.blue + (end.blue - start.blue) * ratio
        return Color(red: r, green: g, blue: b)
    }
}

extension Color {
    var components: (red: Double, green: Double, blue: Double) {
        #if os(iOS)
        typealias NativeColor = UIColor
        #else
        typealias NativeColor = NSColor
        #endif
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0
        NativeColor(self).getRed(&red, green: &green, blue: &blue, alpha: nil)
        return (Double(red), Double(green), Double(blue))
    }
}
