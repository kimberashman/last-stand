import Foundation
import HealthKit
import Combine
import CoreMotion

class HealthKitManager: ObservableObject {
    let healthStore = HKHealthStore()
    private let motionManager = CMMotionActivityManager()
    
    @Published var lastStandTime: Date?
    @Published var timeSinceLastStand: TimeInterval = 0
    @Published var isAuthorized = false
    @Published var recentlyWalked: Bool = false
    
    private var timer: Timer?
    private var fetchTimer: Timer?
    
    init() {
        requestAuthorization()
        startTimer()
        startFetchTimer()
    }
    
    func requestAuthorization() {
        let stepType = HKObjectType.quantityType(forIdentifier: .stepCount)!
        let typesToRead: Set<HKObjectType> = [stepType]
        
        healthStore.requestAuthorization(toShare: nil, read: typesToRead) { success, error in
            DispatchQueue.main.async {
                self.isAuthorized = success
                if success {
                    self.evaluateRecentStepIntervals()
                    // self.startMotionUpdates()
                }
            }
        }
    }
    
    func fetchLastStandTime() {
        let now = Date()
        let startOfDay = Calendar.current.startOfDay(for: now)
        let stepType = HKObjectType.quantityType(forIdentifier: .stepCount)!
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: now, options: .strictStartDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)

        let query = HKSampleQuery(sampleType: stepType, predicate: predicate, limit: 1, sortDescriptors: [sortDescriptor]) { [weak self] _, samples, error in
            guard let self = self else { return }
            if let stepSample = samples?.first as? HKQuantitySample {
                DispatchQueue.main.async {
                    let freshnessThreshold: TimeInterval = 5 * 60 // 5 minutes
                    let now = Date()
                    let stepCount = stepSample.quantity.doubleValue(for: .count())
                    // Ignore step samples from the future
                    if stepSample.endDate > now {
                        print("Ignoring future-dated step sample:", stepSample.endDate)
                        return
                    }
                    print("Step sample start:", stepSample.startDate)
                    print("Step sample end:", stepSample.endDate)
                    print("Step count:", stepCount)
                    print("recentlyWalked:", self.recentlyWalked)
                    print("Time since sample:", now.timeIntervalSince(stepSample.endDate))
                    
                    if stepCount >= 30 && (self.lastStandTime == nil || stepSample.endDate > self.lastStandTime!) && now.timeIntervalSince(stepSample.endDate) <= freshnessThreshold {
                        self.lastStandTime = stepSample.endDate
                        print("✅ Updated lastStandTime to:", self.lastStandTime!)
                        self.updateTimeSinceLastStand()
                    }
                }
            } else {
                DispatchQueue.main.async {
                    self.updateTimeSinceLastStand()
                }
            }
        }
        healthStore.execute(query)
    }
    
    public func forceRefresh(completion: @escaping () -> Void = {}) {
        let now = Date()
        let startOfDay = Calendar.current.startOfDay(for: now)
        let stepType = HKObjectType.quantityType(forIdentifier: .stepCount)!
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: now, options: .strictStartDate)

        let query = HKSampleQuery(sampleType: stepType, predicate: predicate, limit: 1, sortDescriptors: [sortDescriptor]) { [weak self] _, samples, _ in
            guard let self = self else {
                DispatchQueue.main.async { completion() }
                return
            }
            DispatchQueue.main.async {
                self.evaluateRecentStepIntervals()
                completion()
            }
        }
        healthStore.execute(query)
    }
    
    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateTimeSinceLastStand()
        }
    }
    
    private func startFetchTimer() {
        fetchTimer = Timer.scheduledTimer(withTimeInterval: 300.0, repeats: true) { [weak self] _ in
            self?.evaluateRecentStepIntervals()
        }
    }
    
    private func updateTimeSinceLastStand() {
        guard let lastStand = lastStandTime else {
            timeSinceLastStand = 0
            return
        }
        
        timeSinceLastStand = Date().timeIntervalSince(lastStand)
    }
    
    /// Fetch step counts for each hour of the current day, and classify each hour as standing, sitting, or no data.
    /// Calls completion with an array of tuples: (hour: Int, didStand: Bool, hasData: Bool, date: Date)
    func fetchStandingDataForToday(completion: @escaping ([(hour: Int, didStand: Bool, hasData: Bool, date: Date)]) -> Void) {
        let calendar = Calendar.current
        let now = Date()
        let startOfDay = calendar.startOfDay(for: now)
        let stepType = HKObjectType.quantityType(forIdentifier: .stepCount)!
        var results: [(hour: Int, didStand: Bool, hasData: Bool, date: Date)] = []
        let group = DispatchGroup()
        for hour in 0..<24 {
            let hourDate = calendar.date(byAdding: .hour, value: hour, to: startOfDay)!
            let nextHourDate = calendar.date(byAdding: .hour, value: hour + 1, to: startOfDay)!
            // Don't request data for hours after now
            if hourDate > now { continue }
            group.enter()
            let hourPredicate = HKQuery.predicateForSamples(withStart: hourDate, end: nextHourDate, options: .strictStartDate)
            let stepQuery = HKStatisticsQuery(quantityType: stepType, quantitySamplePredicate: hourPredicate, options: .cumulativeSum) { _, result, _ in
                // If result is nil, treat as no data (e.g., HealthKit returned no stats for this hour)
                if let result = result {
                    let rawStepCount = result.sumQuantity()?.doubleValue(for: .count())
                    let stepCount = rawStepCount ?? 0
                    let didStand = stepCount >= 20
                    let hasData = rawStepCount != nil // Only treat as no data if truly no quantity at all
                    results.append((hour, didStand, hasData, hourDate))
                } else {
                    // No data returned at all for this hour (e.g., device off, HealthKit error)
                    results.append((hour, false, false, hourDate))
                }
                group.leave()
            }
            healthStore.execute(stepQuery)
        }
        group.notify(queue: .main) {
            // Sort by hour
            let sorted = results.sorted { $0.hour < $1.hour }
            completion(sorted)
        }
    }
    
    func fetchStepCountsByInterval(intervalMinutes: Int = 5, completion: @escaping ([Date: Double]) -> Void) {
        let calendar = Calendar.current
        let now = Date()
        let startOfDay = calendar.startOfDay(for: now)
        let stepType = HKObjectType.quantityType(forIdentifier: .stepCount)!
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: now, options: .strictStartDate)
        let interval = DateComponents(minute: intervalMinutes)
        let query = HKStatisticsCollectionQuery(quantityType: stepType, quantitySamplePredicate: predicate, options: .cumulativeSum, anchorDate: startOfDay, intervalComponents: interval)
        
        print("🔍 Fetching step data from \(startOfDay) to \(now)")
        
        query.initialResultsHandler = { _, results, error in
            if let error = error {
                print("❌ Error fetching step data:", error)
                DispatchQueue.main.async { completion([:]) }
                return
            }
            
            guard let results = results else {
                print("❌ No results returned from HealthKit")
                DispatchQueue.main.async { completion([:]) }
                return
            }
            
            var stepCounts: [Date: Double] = [:]
            results.enumerateStatistics(from: startOfDay, to: now) { statistics, _ in
                let startDate = statistics.startDate
                guard startDate <= Date() else { return } // skip future samples
                if let sum = statistics.sumQuantity() {
                    let steps = sum.doubleValue(for: .count())
                    stepCounts[startDate] = steps
                    print("📈 Interval at \(startDate): \(steps) steps")
                } else {
                    stepCounts[startDate] = 0.0 // Explicitly mark as "inactive" if no data
                    print("📉 Interval at \(startDate): no data")
                }
            }
            
            print("📊 Total intervals processed: \(stepCounts.count)")
            DispatchQueue.main.async { completion(stepCounts) }
        }
        healthStore.execute(query)
    }
    
    func evaluateRecentStepIntervals() {
        fetchStepCountsByInterval(intervalMinutes: 5) { intervalSteps in
            let sortedIntervals = intervalSteps.sorted(by: { $0.key > $1.key }) // latest first
            let now = Date()
            let freshnessThreshold: TimeInterval = 5 * 60 // 15 minutes (increased from 5)
            let stepThreshold = 20.0 // reduced from 30

            print("📊 Total intervals to check: \(sortedIntervals.count)")
            
            for (intervalStart, stepCount) in sortedIntervals {
                let intervalEnd = intervalStart.addingTimeInterval(5 * 60)
                let isRecent = now.timeIntervalSince(intervalEnd) <= freshnessThreshold
                let isValid = stepCount >= stepThreshold && isRecent

                print("🔍 Checking interval at \(intervalStart): \(stepCount) steps, recent: \(isRecent) → valid: \(isValid)")

                if isValid {
                    self.lastStandTime = intervalEnd
                    print("✅ Updated lastStandTime to:", self.lastStandTime!)
                    self.updateTimeSinceLastStand()
                    break
                }
            }
            
            // If we haven't found any valid intervals, log that
            if self.lastStandTime == nil {
                print("❌ No valid standing intervals found in the last \(freshnessThreshold/60) minutes")
            }
        }
    }
    
    private func startMotionUpdates() {
        guard CMMotionActivityManager.isActivityAvailable() else { return }

        motionManager.startActivityUpdates(to: OperationQueue.main) { [weak self] activity in
            guard let self = self, let activity = activity else { return }

            // Trigger only on walking or running with confidence level medium or high
            if (activity.walking || activity.running),
               activity.confidence != .low {
                self.recentlyWalked = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 300) {
                    self.recentlyWalked = false // reset after 5 minutes
                }
            }
        }
    }

    deinit {
        timer?.invalidate()
        fetchTimer?.invalidate()
        motionManager.stopActivityUpdates()
    }
}
