# GymJam

GymJam is a small iOS app for turning a pasted coach workout message into daily workout cards. Open today's WOD, scan the exercises, and tap the YouTube button beside any movement to search for a tutorial without leaving the app.

## What It Does

- Paste a WhatsApp-style workout plan.
- Choose a start and end date.
- Review parsed days, segments, exercises, and low-confidence lines before saving.
- See daily WOD cards sorted by today, upcoming, then recent past.
- Mark workouts complete.
- Edit exercise names/details later from the WOD detail screen.
- Open YouTube search results in an in-app `WKWebView`.

## Requirements

- Xcode 26 or newer.
- iOS 17+ simulator or device.
- No backend, API keys, login, third-party SDKs, or LLM service.

`SwiftData` is used for local persistence, so the project targets iOS 17+.

## Run

1. Open `GymJam.xcodeproj` in Xcode.
2. Select an iPhone simulator.
3. Press Run.

You can also build from Terminal:

```sh
xcodebuild -project GymJam.xcodeproj -scheme GymJam -destination 'generic/platform=iOS Simulator' build
```

## Parser Format

The parser is regex-based and intentionally conservative. It supports:

- `Week 1` / `Week-2`
- Full day names like `Monday`
- Free-text segments like `A - Workout of the day`
- Standard exercise lines such as `Goblet squat 10 * 3 sets`
- Timed holds, intervals, build-to-max lines, supersets with `+`, and EMOM/EMOTM/TABATA/AMRAP blocks

Low-confidence lines are preserved for review instead of being discarded.

## Privacy

Workout data stays on device in SwiftData. The only network traffic is the user-initiated YouTube webview search.
