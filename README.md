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

### The Thread (v2 design)
- One conversation per baby: every feed, sleep, diaper and note is a message bubble
- Your entries sit on the right (plum), your partner's on the left, with an unread marker after a handoff
- A totals strip (feeds · slept · diapers · next feed) above the conversation
- Leona speaks in the thread: predicts the next feed, offers to log it, can be snoozed or muted
- Composer chips for Bottle / Breast / Sleep / Diaper / Solid with an inline logging tray
- Live sleep and breastfeeding sessions as full-screen dark scenes with per-side timers
- Sub-screens: Trends · Growth · Health hub, Profile, Sharing, Search, Record detail
- Night theme (manual or automatic at dusk), haptics, confetti on monthly milestones

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
├── ContentView.swift            # Root: thread + navigation stack + live sessions
├── Theme/
│   ├── LeonaTheme.swift         # Palette tokens (light/dark), typography, shapes
│   └── LeonaComponents.swift    # Cards, pills, toggles, headers, bar chart, toast
├── Models/
│   ├── Baby.swift               # Baby profile model
│   ├── Activity.swift           # Activity model (with author stamping)
│   ├── GrowthRecord.swift       # Growth measurement model
│   ├── HealthRecord.swift       # Health/illness model
│   ├── AppSettings.swift        # UserDefaults settings
│   ├── ThreadModel.swift        # Thread rows, totals, Leona's suggestion
│   └── MealForecast.swift       # Forecast data models
├── Views/
│   ├── Welcome/                 # First run, inside the thread
│   ├── Thread/                  # The conversation, tray, Leona card
│   ├── Sleep/                   # Live sleep session
│   ├── Feeding/                 # Live breastfeeding session
│   ├── Insights/                # Trends + hub (Trends · Growth · Health)
│   ├── Growth/                  # WHO chart, measurements
│   ├── Health/                  # Records, vaccination card
│   ├── Profile/                 # Baby profile, preferences, the record
│   ├── Sharing/                 # Partner sharing
│   ├── Search/                  # Search every entry
│   ├── Record/                  # Entry detail and editor
│   └── Components/              # Confetti
├── Services/
│   ├── ActivityLogger.swift     # Every write to the thread
│   ├── CloudKitManager.swift    # iCloud sync
│   ├── SharingManager.swift     # CloudKit sharing
│   ├── SyncEngine.swift         # Shared-record sync
│   ├── NotificationManager.swift # Reminders
│   ├── StatisticsEngine.swift   # Stats calculations
│   ├── MealForecastEngine.swift # Meal predictions
│   ├── WHODataService.swift     # WHO percentile data
│   ├── ExportService.swift      # CSV/XML/report text
│   └── ReportExporter.swift     # PDF and CSV files for sharing
├── Extensions/
│   ├── Date+Extensions.swift    # Date formatting
│   ├── UnitConversion.swift     # Metric/imperial
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

Leona follows the "Thread v2" design: the app is a conversation, not a dashboard.

- **Five colours with fixed meanings**: plum for structure and your own bubbles, vermilion (`#E24E2B`) for action and for Leona, lilac for sleep only, moss for diapers only, on a warm canvas — no system blue, no rainbow
- **A real night theme** (`#191223` canvas) toggled from the thread header or automatically at dusk
- **Message bubbles instead of cards**, with a coloured tick per entry type and a "who · when" meta line
- **One-tap logging** from the composer chips; a bottom tray for amounts, sides and times
- **Generous spacing and large targets** for one-handed use while holding a baby
- **System font** stands in for the design's Instrument Sans; sizes, weights and tracking follow the design
- **Dynamic Type** support for accessibility

## License

GNU General Public License v3.0
