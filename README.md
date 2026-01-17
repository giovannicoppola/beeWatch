# BeeWatch

An Apple Watch app for tracking and entering data into your Beeminder goals.

**[View Website](https://giovannicoppola.github.io/beeWatch)** | **[Technical Docs](TECHNICAL.md)**

## Features

- **Goal List**: See all your Beeminder goals sorted by urgency (closest to derailing first)
- **Quick Data Entry**: Large buttons for fast data entry, with your most frequent values shown first
- **Recent Entries**: View past entries for easy reference
- **Reminders**: Customizable notifications to remind you to track your goals
- **Complications**: Add a complication to your watch face showing your most urgent goal

## Requirements

- iOS 17.0+
- watchOS 10.0+
- Beeminder account and API key

**For building from source:**
- Xcode 15.0+
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (for project generation)

## Setup

### Option A: TestFlight (Easiest - For End Users)

If you've been invited to test BeeWatch via TestFlight:

1. **Install TestFlight** (if you don't have it):
   - Download [TestFlight](https://apps.apple.com/app/testflight/id899247664) from the App Store

2. **Accept the Invitation**:
   - Check your email for a TestFlight invitation from the developer
   - Tap the invitation link, or open TestFlight and accept the invitation

3. **Install BeeWatch**:
   - In TestFlight, tap **Install** next to BeeWatch
   - Wait for the app to install on your iPhone and Apple Watch
   - Open BeeWatch on your Watch to get started

**Note:** TestFlight builds expire after 90 days. You'll receive notifications when updates are available.

### Option B: Using XcodeGen (For Developers)

1. Install XcodeGen:
   ```bash
   brew install xcodegen
   ```

2. Generate the project:
   ```bash
   cd /path/to/beeWatch
   xcodegen generate
   ```

3. Open in Xcode:
   ```bash
   open beeWatch.xcodeproj
   ```

### Option C: Manual Xcode Setup

1. **Create New Project in Xcode**:
   - File > New > Project
   - Select "watchOS" > "App"
   - Product Name: `beeWatch`
   - Interface: SwiftUI
   - Language: Swift
   - Check "Include Watch App"
   - Uncheck "Include Tests"

2. **Configure Targets**:
   - Set iOS Deployment Target: 17.0
   - Set watchOS Deployment Target: 10.0

3. **Add Shared Files**:
   - Right-click on the project navigator
   - Add Files to "beeWatch"
   - Select the `Shared` folder
   - Check both "beeWatch" and "beeWatch Watch App" targets

4. **Add Watch App Views**:
   - Add files from `beeWatch Watch App/Views/` to the Watch App target
   - Replace the generated ContentView with the Views

5. **Add Widget Extension for Complications**:
   - File > New > Target
   - Select "watchOS" > "Widget Extension"
   - Product Name: `BeeWatchComplications`
   - Uncheck "Include Configuration Intent"
   - Add the Shared folder to this target as well
   - Replace generated files with files from `Complications/`

6. **Configure Signing**:
   - Select your Team for all targets
   - Update Bundle Identifiers as needed

### Build and Run

1. Select the "beeWatch Watch App" scheme
2. Choose a Watch simulator or your connected Apple Watch
3. Press Cmd+R to build and run

## Distribution

### TestFlight Distribution

To distribute BeeWatch to testers via TestFlight:

1. **Prerequisites**:
   - Apple Developer account ($99/year)
   - App created in [App Store Connect](https://appstoreconnect.apple.com)

2. **Quick Steps**:
   - Archive the app in Xcode (Product → Archive)
   - Upload to App Store Connect
   - Configure TestFlight and invite testers

For detailed TestFlight setup instructions, see [TECHNICAL.md](TECHNICAL.md#testflight-distribution).

## Configuration

### Getting Your Beeminder API Key

1. Log in to [Beeminder](https://www.beeminder.com)
2. Go to [Settings > Account](https://www.beeminder.com/settings/account)
3. Find the "Auth Token" section
4. Copy your API key

### Adding API Key in App

1. Open the app (either on Watch or iPhone)
2. Go to Settings (gear icon)
3. Paste your API key
4. Tap "Test Connection" to verify
5. Tap "Save" or "Done"

## Project Structure

```
beeWatch/
├── beeWatch/                    # iOS App (settings companion)
│   ├── beeWatchApp.swift
│   ├── ContentView.swift
│   └── Assets.xcassets
├── beeWatch Watch App/          # watchOS App (main app)
│   ├── beeWatchApp.swift
│   ├── Views/
│   │   ├── GoalListView.swift
│   │   ├── GoalDetailView.swift
│   │   ├── DataEntryView.swift
│   │   ├── SettingsView.swift
│   │   └── ReminderSettingsView.swift
│   ├── Complications/
│   │   ├── BeeWatchComplications.swift
│   │   └── ComplicationBundle.swift
│   └── Assets.xcassets
└── Shared/                      # Shared code
    ├── Models/
    │   ├── Goal.swift
    │   ├── Datapoint.swift
    │   └── UserSettings.swift
    ├── Services/
    │   ├── BeeminderAPI.swift
    │   ├── DataStore.swift
    │   └── NotificationManager.swift
    └── Extensions/
        └── Date+Extensions.swift
```

## Beeminder API

The app uses the [Beeminder API](https://api.beeminder.com/) to:
- Fetch goals: `GET /users/me/goals.json`
- Fetch datapoints: `GET /users/me/goals/{slug}/datapoints.json`
- Create datapoints: `POST /users/me/goals/{slug}/datapoints.json`

## License

MIT License
