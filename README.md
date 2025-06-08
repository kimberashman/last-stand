# 🕒 Last Stand

**Last Stand** is a wellness-focused iOS and Apple Watch app that tracks how long it's been since you last stood up. Designed to help promote healthier daily habits by encouraging movement and reducing prolonged sitting.

---

## 🚀 Features

- ⌚️ Integrates with Apple Watch to detect standing events via HealthKit
- ⏱️ Real-time display of time elapsed since last stand
- 🔔 Optional inactivity reminders after prolonged sitting
- 📊 (Planned) History view of past standing intervals

---

## 📱 Platforms

- iOS 15+
- watchOS 8+
- Built in **Swift** with **SwiftUI** and **HealthKit**

---

## 🔐 Permissions

This app uses Apple HealthKit to read stand hour data. On first launch, the app will request permission to read:

- `HKCategoryTypeIdentifierAppleStandHour`

No personal health data is stored or transmitted externally. All processing happens on-device.

---

## 🧰 Tech Stack

- Swift 5
- SwiftUI
- HealthKit
- Combine
- WatchConnectivity (for syncing iPhone ↔ Apple Watch)
- Local Notifications

---

## 🏗️ Installation

1. Clone this repository:
   ```bash
   git clone https://github.com/yourusername/last-stand.git
   cd last-stand