import Foundation
import HealthKit
import Combine
import CoreMotion

class HealthKitManager: ObservableObject {
    let healthStore = HKHealthStore()
    private let standHourType = HKObjectType.categoryType(forIdentifier: .appleStandHour)!
    private let motionManager = CMMotionActivityManager()
    
    @Published var lastStandTime: Date?
    @Published var timeSinceLastStand: TimeInterval = 0
    @Published var isAuthorized = false
    
    private var timer: Timer?
    private var fetchTimer: Timer?
    
    init() {
        requestAuthorization()
        startTimer()
        startFetchTimer()
    }
    
    func requestAuthorization() {
        let typesToRead: Set<HKObjectType> = [standHourType]
        
        healthStore.requestAuthorization(toShare: nil, read: typesToRead) { success, error in
            DispatchQueue.main.async {
                self.isAuthorized = success
                if success {
                    self.fetchLastStandTime()
                    self.startMotionUpdates()
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
                    self.lastStandTime = stepSample.startDate
                    self.updateTimeSinceLastStand()
                }
            } else {
                DispatchQueue.main.async {
                    self.lastStandTime = nil
                    self.updateTimeSinceLastStand()
                }
            }
        }
        healthStore.execute(query)
    }
    
    public func forceRefresh(completion: @escaping () -> Void = {}) {
        let now = Date()
        let startOfDay = Calendar.current.startOfDay(for: now)

        let standPredicate = HKQuery.predicateForSamples(withStart: startOfDay, end: now, options: .strictStartDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)

        let query = HKSampleQuery(sampleType: standHourType, predicate: standPredicate, limit: 10, sortDescriptors: [sortDescriptor]) { [weak self] _, samples, error in
            guard let self = self, error == nil else {
                DispatchQueue.main.async { completion() }
                return
            }

            let standSample = samples?
                .compactMap { $0 as? HKCategorySample }
                .first(where: { $0.value == HKCategoryValueAppleStandHour.stood.rawValue })

            var lastStandDate: Date? = nil
            if let standSample = standSample {
                if standSample.endDate > now {
                    lastStandDate = standSample.startDate
                } else {
                    lastStandDate = standSample.endDate
                }
            }

            let stepType = HKObjectType.quantityType(forIdentifier: .stepCount)!
            let fifteenMinutesAgo = now.addingTimeInterval(-900)
            let stepsPredicate = HKQuery.predicateForSamples(withStart: fifteenMinutesAgo, end: now, options: .strictStartDate)

            let stepQuery = HKSampleQuery(sampleType: stepType, predicate: stepsPredicate, limit: 1, sortDescriptors: [sortDescriptor]) { [weak self] _, stepSamples, _ in
                guard let self = self else {
                    DispatchQueue.main.async { completion() }
                    return
                }
                if let stepSample = stepSamples?.first as? HKQuantitySample {
                    let mostRecent = [lastStandDate, stepSample.startDate].compactMap { $0 }.max()
                    DispatchQueue.main.async {
                        self.lastStandTime = mostRecent
                        self.updateTimeSinceLastStand()
                        completion()
                    }
                } else {
                    DispatchQueue.main.async {
                        self.lastStandTime = lastStandDate
                        self.updateTimeSinceLastStand()
                        completion()
                    }
                }
            }
            self.healthStore.execute(stepQuery)
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
            self?.fetchLastStandTime()
        }
    }
    
    private func updateTimeSinceLastStand() {
        guard let lastStand = lastStandTime else {
            timeSinceLastStand = 0
            return
        }
        
        timeSinceLastStand = Date().timeIntervalSince(lastStand)
    }
    
    private func startMotionUpdates() {
        guard CMMotionActivityManager.isActivityAvailable() else { return }

        motionManager.startActivityUpdates(to: OperationQueue.main) { [weak self] activity in
            guard let self = self, let activity = activity else { return }

            // Trigger only on walking or running with confidence level medium or high
            if (activity.walking || activity.running),
               activity.confidence != .low {
                // Always update last stand time to now
                let now = Date()
                print("Motion update: walking/running at \(now)")
                self.lastStandTime = now
                self.updateTimeSinceLastStand()
            }
        }
    }
    
    deinit {
        timer?.invalidate()
        fetchTimer?.invalidate()
        motionManager.stopActivityUpdates()
    }
}
