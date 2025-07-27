# StillTime – Apple Watch Stand Tracker

**StillTime** is a lightweight Apple Watch companion app that helps you visualize how long you've been sedentary and prompts you to move throughout the day. Unlike Apple’s built-in stand reminders, StillTime offers more precise, minute-level tracking based on actual step counts from HealthKit.

## Features

- Circular "clock view" with hour segments representing stand activity
- Summary view with dot indicators showing movement during work hours (9am–5pm)
- Real-time sedentary timer
- Longest sedentary period calculation
- Minimal UI focused on glanceability
- HealthKit integration for step count data

## How It Works

The app retrieves step counts using `HKQuantityTypeIdentifier.stepCount` and infers sedentary periods based on minute-level intervals. Movement is credited for any minute with at least a small number of steps (default threshold: 10). This avoids relying solely on Apple’s binary `appleStandHour` flag.

- **Clock View**: Displays a ring with segments for each hour of the day, color-coded by standing activity.
- **Summary View**: Shows per-hour movement dots during work hours and reports total active hours and the longest continuous sedentary period.

## Architecture

- `HealthKitManager.swift`: Handles all HealthKit data fetching and permissions
- `ContentView.swift`: Swipable view container for main app screens
- `ClockView.swift`: Displays circular activity ring
- `MovementSummaryView.swift`: Displays per-hour activity dots and stats
- `StepHour`: Model for hour-by-hour step analysis
- Uses `ObservableObject` and `@Published` properties for reactive updates

## Development Notes

- HealthKit data is not available in the simulator. Test on a physical device with Health permissions granted.
- The app uses a 60-second timer to refresh step data regularly.
- Requires explicit HealthKit authorization to read step count data.
- Movement is defined as ≥10 steps per minute; this can be adjusted in `HealthKitManager.swift`.

## Requirements

- iOS 17+
- watchOS 10+
- Xcode 15+
- SwiftUI

## Setup

1. Clone the repo:
   ```bash
   git clone https://github.com/kimberashman/last-stand.git
   cd last-stand
   ```

2.	Open in Xcode:
    ```bash
    open StillTime.xcodeproj    
    ```

3.	Ensure you:
- Enable HealthKit capabilities
- Run on a physical device with step data
- Grant Health permissions when prompted


## License

MIT © Kimber Ashman