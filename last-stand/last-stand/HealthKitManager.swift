import Foundation
import HealthKit
import Combine

class HealthKitManager: ObservableObject {
    private let healthStore = HKHealthStore()
    private let standHourType = HKObjectType.categoryType(forIdentifier: .appleStandHour)!
    
    @Published var lastStandTime: Date?
    @Published var timeSinceLastStand: TimeInterval = 0
    @Published var isAuthorized = false
    
    private var timer: Timer?
    
    init() {
        requestAuthorization()
        startTimer()
    }
    
    func requestAuthorization() {
        let typesToRead: Set<HKObjectType> = [standHourType]
        
        healthStore.requestAuthorization(toShare: nil, read: typesToRead) { success, error in
            DispatchQueue.main.async {
                self.isAuthorized = success
                if success {
                    self.fetchLastStandTime()
                }
            }
        }
    }
    
    func fetchLastStandTime() {
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        let query = HKSampleQuery(
            sampleType: standHourType,
            predicate: nil,
            limit: 1,
            sortDescriptors: [sortDescriptor]
        ) { [weak self] _, samples, error in
            guard let self = self,
                  let sample = samples?.first as? HKCategorySample,
                  error == nil else { return }
            
            DispatchQueue.main.async {
                self.lastStandTime = sample.endDate
                self.updateTimeSinceLastStand()
            }
        }
        
        healthStore.execute(query)
    }
    
    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateTimeSinceLastStand()
        }
    }
    
    private func updateTimeSinceLastStand() {
        guard let lastStand = lastStandTime else {
            timeSinceLastStand = 0
            return
        }
        
        timeSinceLastStand = Date().timeIntervalSince(lastStand)
    }
    
    deinit {
        timer?.invalidate()
    }
} 