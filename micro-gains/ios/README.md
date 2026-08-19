# Micro Gains, iOS

UIKit app, iOS 17+, no storyboards and no SwiftUI. `project.yml` is the source of
truth; `MicroGains.xcodeproj` is generated and is not committed.

## Commands

```sh
brew install xcodegen                 # once
cd ios
xcodegen generate                     # after adding or removing any file

# build
xcodebuild -project MicroGains.xcodeproj -scheme MicroGains \
  -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath build build

# test (104 unit tests)
xcodebuild -project MicroGains.xcodeproj -scheme MicroGains \
  -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath build test

# run in the simulator
xcrun simctl boot 'iPhone 17'
xcrun simctl install booted build/Build/Products/Debug-iphonesimulator/MicroGains.app
xcrun simctl launch booted com.zackbart.microgains

# regenerate the app icon
swift scripts/make-icon.swift MicroGains/Resources/Assets.xcassets/AppIcon.appiconset/icon-1024.png
```

Debug builds accept launch arguments for manual QA: `-mgScreen home|set|set-timed|settings|settings-bottom|history`
skips onboarding and opens that screen, `-mgSeed` fills three weeks of sample
sets, `-mgAskPermission` requests notification authorization at launch, and
`-mgSimulateAction done|skip|snooze` runs the real notification action handler
against the next pending slot. All of it is behind `#if DEBUG`.

## Architecture

One module, four folders.

- `App/` holds `AppDelegate` (notification delegate, `MICRO_SET` category, `BGTaskScheduler`), `SceneDelegate` (window and root swap) and `Router` (notification tap to Set screen).
- `Core/Scheduler.swift` is pure: settings plus catalog plus a clock in, `[Slot]` out. No UIKit, no UserNotifications, no singletons, which is what makes the DST and determinism tests possible.
- `Core/NotificationPlanner.swift` turns slots into `UNNotificationRequest`s and diffs them against the pending queue by identifier.
- `Core/SetStore.swift` is an actor over one atomically written JSON file in Application Support. The app and the notification action path share it, so writes serialize.
- `Core/APIClient.swift` is a URLSession wrapper; `SyncCoordinator` pushes settings, flushes the set outbox and refreshes the catalog.
- `Core/Catalog.swift` loads the bundled `catalog.json` and caches the server copy; `SettingsStore` keeps settings in UserDefaults; `DeviceID` keeps the device UUID in the Keychain.
- `Core/AppCore.swift` is the one place that knows how those pieces fit together. Screens and the action handler both go through it.
- `Screens/` has the four view controllers plus `Controls` and `Theme` for shared pieces.
- `Resources/` has `catalog.json`, the asset catalog and the partial `Info.plist`.

## Where the API URL is set

`project.yml` sets `MICRO_GAINS_API_URL` per configuration. Debug points at
`http://127.0.0.1:8788`, release at `https://micro-gains.onemany.workers.dev`. That setting is substituted into
`MicroGains/Resources/Info.plist` and read once by `APIClient.baseURL`. Nothing
else in the app hardcodes a host.

## Notifications and scheduling

`Scheduler.plan` walks forward from now, day by day, building slots every
`interval_minutes` inside the active window on active days, and stops at 60 slots
or 14 days. Each slot is shifted by a deterministic offset in [-5, +5] minutes
derived from `SHA256(device_id, unjittered time)`, and its exercise comes from the
same seed run through the pattern filters in SPEC rule 4. The request identifier
is `slot-<unjittered time in UTC>` and the set id is a UUID v5 of that, so the
same slot always maps to the same log entry. `NotificationPlanner.apply` fetches
the pending queue, removes identifiers that are no longer wanted and adds the
missing ones, which is why reopening the app never disturbs a queued reminder.
Done, Skip and Snooze are handled in `AppDelegate.handle(action:...)` inside a
background task, and the first terminal write to a slot wins.

## Screenshots

`screenshots/` has the four onboarding pages, Home, Set for reps and for a
seconds exercise with the countdown ring running, Settings top and bottom, and
History. All captured on an iPhone 17 simulator.
