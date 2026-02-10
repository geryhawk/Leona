# Leona - Baby Tracking App for iOS

A beautiful, native iOS app for tracking your baby's daily activities, growth, and health. Built with SwiftUI, SwiftData, and CloudKit for seamless iCloud synchronization between parents.

## Features

### Daily Activity Tracking
- **Breastfeeding** - Timer with left/right breast selection, session slots (morning/day/evening/night), automatic side suggestion
- **Formula** - Volume tracking with slider and quick-select buttons, smart volume suggestions based on history
- **Mom's Milk** - Expressed milk volume tracking
- **Solid Food** - Food name, quantity, unit selection with common baby food quick-picks
- **Sleep** - Start/stop timer with day/night visual themes, manual entry support
- **Diaper** - Quick logging for pee, poop, or both
- **Notes** - Timestamped notes for any observation

### Multi-Baby Support
- Create and manage multiple baby profiles
- Quick switching between babies
- Profile photos via camera or photo library
- Baby information: name, date of birth, gender, blood type

### iCloud Sync
- Automatic data synchronization via CloudKit
- All data shared across devices with the same Apple ID
- Real-time sync status indicator
- Works offline with automatic sync when back online

### Growth Tracking
- Weight (kg), height (cm), head circumference (cm)
- Interactive growth charts with WHO percentile overlays (P3, P15, P50, P85, P97)
- Gender-specific percentile data
- Real-time percentile calculation for new measurements

### Health Records
- 10 illness types: Cold, Flu, Fever, Ear Infection, Stomach Bug, Rash, Teething, Allergy, Vaccination, Other
- Temperature tracking with color-coded severity
- Symptom logging with severity levels (Mild/Moderate/Severe)
- Medication tracking with dosage and administration time
- Active vs. resolved health issues

### Statistics & Charts (Swift Charts)
- **Feeding charts** - Formula volume, breastfeeding frequency, solid food, mom's milk
- **Sleep charts** - Day vs. night sleep distribution
- **Diaper charts** - Pee and poop frequency
- Time period selection: Today, 3 days, 7 days, 30 days, 6 months, 12 months

### Meal Forecast
- AI-powered next meal prediction based on feeding patterns
- Estimated volume with and without breastfeeding
- Average interval calculation
- Maximum delay warning
- Confidence level indicator

### Notifications
- Feeding reminders (configurable interval: 2-4 hours)
- Breastfeeding session reminders
- Sleep duration check reminders
- Milestone celebrations
- Snooze and dismiss actions

### Multilingual
- English
- French (Français)
- Finnish (Suomi)

### Beautiful UI/UX
- Apple Human Interface Guidelines compliance
- SF Symbols throughout
- Dynamic backgrounds (day/night themes for sleep)
- Haptic feedback on interactions
- Confetti celebrations for birthdays and milestones
- Smooth animations and transitions
- Pull-to-refresh
- Swipe-to-delete on activity cards
- Dark mode support

### Data Export
- CSV export for activities
- XML export for activities
- Full text report generation
- Growth data CSV export

## Technical Architecture

### Stack
| Component | Technology |
|-----------|------------|
| UI Framework | SwiftUI |
| Data Persistence | SwiftData |
| Cloud Sync | CloudKit |
| Charts | Swift Charts |
| Notifications | UserNotifications |
| Photos | PhotosUI |
| Architecture | MVVM |
| Min iOS | 17.0 |
| Language | Swift 5.9 |

### Project Structure
```
Leona/
├── LeonaApp.swift              # App entry point
├── ContentView.swift            # Root tab navigation
├── Models/
│   ├── Baby.swift               # Baby profile model
│   ├── Activity.swift           # Activity tracking model
│   ├── GrowthRecord.swift       # Growth measurement model
│   ├── HealthRecord.swift       # Health/illness model
│   ├── AppSettings.swift        # UserDefaults settings
│   └── MealForecast.swift       # Forecast data models
├── Views/
│   ├── Onboarding/              # First-launch setup
│   ├── Dashboard/               # Main tracking screen
│   ├── Feeding/                 # All feeding views
│   ├── Sleep/                   # Sleep tracking
│   ├── Diaper/                  # Diaper logging
│   ├── Growth/                  # Growth charts
│   ├── Health/                  # Health records
│   ├── Stats/                   # Statistics & charts
│   ├── Profile/                 # Baby profile management
│   ├── Settings/                # App settings
│   └── Components/              # Reusable components
├── Services/
│   ├── CloudKitManager.swift    # iCloud sync
│   ├── NotificationManager.swift # Push notifications
│   ├── StatisticsEngine.swift   # Stats calculations
│   ├── MealForecastEngine.swift # Meal predictions
│   ├── WHODataService.swift     # WHO percentile data
│   └── ExportService.swift      # Data export
├── Extensions/
│   ├── Color+Theme.swift        # App color theme
│   ├── Date+Extensions.swift    # Date formatting
│   └── View+Extensions.swift    # View modifiers
├── Localization/
│   ├── en.lproj/                # English
│   ├── fr.lproj/                # French
│   └── fi.lproj/                # Finnish
└── Resources/
    ├── Assets.xcassets/         # App icons, colors
    └── WHO/                     # WHO growth data
```

## Setup Instructions

### Prerequisites
- Xcode 15.0 or later
- iOS 17.0+ device or simulator
- Apple Developer account (for iCloud features)

### Building

1. **Using XcodeGen** (recommended):
   ```bash
   brew install xcodegen
   cd Leona
   xcodegen generate
   open Leona.xcodeproj
   ```

2. **Manual Xcode project**:
   - Open Xcode → Create new project → iOS App
   - Select SwiftUI interface, SwiftData storage
   - Copy all source files from `Leona/` into the project
   - Add resources (Assets, Localization, WHO data)
   - Configure entitlements for iCloud/CloudKit

### iCloud Setup
1. In Xcode, select your target → Signing & Capabilities
2. Add "iCloud" capability
3. Enable "CloudKit"
4. Add container: `iCloud.com.leona.app`
5. Add "Background Modes" → Remote notifications

### Running
1. Select an iOS 17+ simulator or device
2. Build and run (⌘R)
3. Complete the onboarding flow
4. Start tracking!

## Design Philosophy

Leona follows Apple's Human Interface Guidelines with a warm, nurturing aesthetic:

- **Soft pink accent** (`#DC84A3`) with complementary blues and purples
- **Material backgrounds** for depth and hierarchy
- **Generous spacing** for easy one-handed use while holding a baby
- **Large touch targets** (44pt minimum)
- **Contextual animations** (pulsing heart for breastfeeding, day/night for sleep)
- **SF Symbols** for consistent, scalable iconography
- **Dynamic Type** support for accessibility

## License

GNU General Public License v3.0
