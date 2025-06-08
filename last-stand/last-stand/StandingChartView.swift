import SwiftUI
import Charts
import HealthKit

struct StandingData: Identifiable {
    let id = UUID()
    let hour: Int
    let didStand: Bool
    let date: Date
}

struct StandingChartView: View {
    @EnvironmentObject private var healthKitManager: HealthKitManager
    @State private var standingData: [StandingData] = []
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Today's Standing Activity")
                .font(.title2)
                .bold()
            
            if standingData.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: 200)
            } else {
                Chart {
                    ForEach(standingData) { data in
                        BarMark(
                            x: .value("Hour", data.hour),
                            y: .value("Standing", data.didStand ? 1 : 0)
                        )
                        .foregroundStyle(data.didStand ? Color.green : Color.gray.opacity(0.3))
                    }
                }
                .frame(height: 200)
                .chartXAxis {
                    AxisMarks(values: .automatic) { value in
                        AxisGridLine()
                        AxisValueLabel {
                            if let hour = value.as(Int.self) {
                                Text("\(hour):00")
                                    .font(.caption)
                            }
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks(values: [0, 1]) { value in
                        AxisValueLabel {
                            if let standing = value.as(Int.self) {
                                Text(standing == 1 ? "Standing" : "Sitting")
                                    .font(.caption)
                            }
                        }
                    }
                }
            }
        }
        .padding()
        .onAppear {
            fetchStandingData()
        }
    }
    
    private func fetchStandingData() {
        // Get today's date
        let calendar = Calendar.current
        let now = Date()
        let startOfDay = calendar.startOfDay(for: now)
        
        // Create a predicate for today's data
        let predicate = HKQuery.predicateForSamples(
            withStart: startOfDay,
            end: now,
            options: .strictStartDate
        )
        
        // Create the query
        let query = HKSampleQuery(
            sampleType: HKObjectType.categoryType(forIdentifier: .appleStandHour)!,
            predicate: predicate,
            limit: HKObjectQueryNoLimit,
            sortDescriptors: nil
        ) { _, samples, error in
            guard let samples = samples as? [HKCategorySample], error == nil else {
                return
            }
            
            // Process the samples
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

#Preview {
    StandingChartView()
        .environmentObject(HealthKitManager())
} 