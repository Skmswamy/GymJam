# GymJam

GymJam is a lightweight, **offline-first** iOS workout companion. It converts a long,
unstructured workout message from a coach (typically pasted from WhatsApp) into a clean,
date-organized, distraction-free workout experience with one-tap in-app YouTube tutorials.

No account. No cloud. No tracking. No AI. All data stays on the device.

> This repository contains a **functional SwiftUI prototype** with a runnable Xcode project.
> It was produced collaboratively by the persona specs in [`/Agents`](./Agents) — Product
> Manager, UX Designer, Database Architect, Software Engineer, and QA — following the PRD in
> [`/Rec/Dev.md`](./Rec/Dev.md). The consolidated design/spec is in [`DESIGN.md`](./DESIGN.md).

---

## Quick start

**Requirements:** macOS with **Xcode 16 or newer** (uses SwiftData, Swift Testing, and
Xcode-16 synchronized project groups). Target OS: **iOS 17+**.

1. Open `GymJam.xcodeproj` in Xcode.
2. Select the **GymJam** scheme and an iOS 17+ simulator (e.g. iPhone 15).
3. Press **⌘R** to run.
4. Press **⌘U** to run the unit tests (`GymJamTests`).

No packages, pods, or network setup required — the app has zero third-party dependencies.

### Try it
Go to the **Import** tab, pick a start/end date, paste the sample below, and tap
**Import Workout**:

```
Week 14

Monday
A- Strength
1- DB Push Press 3x8 use straps, pause 3 seconds
2- Back Squat 4x5 tempo 3s down
B- Conditioning
1- Row 500m 3 rounds 30s

Tuesday
A- Power
1- Box Jumps 4x3
2- Kettlebell Swings 3x12

Wednesday
Rest Day
```

---

## Architecture

Pattern: **SwiftUI + SwiftData**, with a thin transactional store and a pure, testable parser.

```
GymJam/
├── GymJamApp.swift            App entry + local SwiftData ModelContainer
├── Models/
│   └── Models.swift           WorkoutCycle · WorkoutDay · Segment · Exercise (@Model)
├── Parsing/
│   └── WorkoutParser.swift    Deterministic text → struct parser (NO framework deps)
├── Services/
│   ├── WorkoutStore.swift     Atomic import / complete / archive transactions
│   ├── AnalyticsService.swift Local-only, in-memory event log
│   └── StorageEstimator.swift On-device storage estimate + 1 GB banner logic
├── Theme/
│   └── Theme.swift            Minimal design tokens + Card container
├── Views/
│   ├── RootView.swift         Bottom tabs: Home · History · Import
│   ├── Home/                  HomeView, WorkoutCardView
│   ├── Detail/                WorkoutDetailView, SegmentSectionView, ExerciseCardView
│   ├── History/               HistoryView (read-only archive)
│   ├── Import/                ImportView
│   └── Common/                SafariView (in-app browser), EmptyStateView
└── Preview/
    └── PreviewData.swift      In-memory seeded container for SwiftUI previews

GymJamTests/
└── WorkoutParserTests.swift   Risk-based parser coverage (Swift Testing)
```

**Data model (cascade delete Cycle → Day → Segment → Exercise).** SwiftData relationship
arrays are unordered, so every level stores an explicit `displayOrder` and is sorted at read
time via `orderedDays` / `orderedSegments` / `orderedExercises`.

---

## ⭐ Important developer notes

1. **Xcode 16 required — synchronized project groups.** `project.pbxproj` uses
   `objectVersion = 77` with `PBXFileSystemSynchronizedRootGroup`. This means **new source
   files added inside `GymJam/` or `GymJamTests/` are auto-included** in the target — no need
   to register each file in the project. Opening in an older Xcode will fail to parse the project.

2. **The parser is intentionally framework-free.** `WorkoutParser` imports only `Foundation`
   (no SwiftData/SwiftUI) so it is fully unit-testable and portable. Keep it that way — map its
   `Parsed*` value types to `@Model` objects only inside `WorkoutStore`.

3. **Import is atomic (no partial saves).** `WorkoutStore.importWorkout` parses **first**;
   only on success does it archive the current cycle and insert the new graph in one
   `context.save()`. A parse failure surfaces the single PRD copy
   *"Unable to understand workout. Please verify formatting."* and writes nothing.

4. **Reps/Sets are `String?`, not `Int`.** Coaches write `8-12`, `AMRAP`, `8/side`. Never
   coerce to numbers. Coach text (names, notes, tempo) is stored **verbatim** and never
   rewritten — the parser only *extracts* structured hints, it never discards the original.

5. **One active cycle at a time.** `isActive == true` marks the Home cycle. Importing flips the
   previous cycle to `isActive = false` (archived → visible read-only under **History**). Nothing
   is ever deleted, so History is safe by construction.

6. **Date mapping.** The first parsed day maps to the chosen **Start Date**; each subsequent day
   advances to the next occurrence of its weekday (falling back to +1 day if the day label is
   unrecognized). See `WorkoutParser.mappedDates`.

7. **Tutorials open in-app.** `ExerciseCardView` presents `SFSafariViewController`
   (`SafariView`) with a `https://www.youtube.com/results?search_query=<name> Exercise` URL, so
   the user never leaves the app and workout scroll position is preserved. No exercise database
   is maintained (PRD §9).

8. **Storage banner is implemented but effectively dormant.** `StorageEstimator` computes a
   byte estimate and Home shows the 1 GB banner if exceeded. With text-only data this realistically
   never fires; the logic exists for forward-compatibility (future cached media). It never blocks import.

9. **Analytics are local only.** `AnalyticsService` prints in DEBUG and keeps a bounded
   in-memory ring buffer. Nothing leaves the device (PRD §19). Events: `workout_imported`,
   `workout_opened`, `tutorial_opened`, `workout_completed`, `import_failed`, `parser_failed`.

10. **Accessibility.** Dynamic Type throughout, VoiceOver labels on cards/CTAs, ≥44pt tap
    targets, and system colors for automatic dark-mode / high-contrast support.

---

## Parser rules (contract)

| Element      | Recognized                                                        |
|--------------|-------------------------------------------------------------------|
| Week         | `Week 1`, `Week-13`, `Week 20` → cycle week number                |
| Day          | `Monday`…`Sunday` (any case, common abbreviations)                |
| Multi-day    | `Saturday and Sunday` → two days; `Rest`/`Recovery` marks rest    |
| Segment      | `A- Strength`, `B - Power` (single leading letter + separator)    |
| Exercise     | `1- Squat`, `2. Bench`, or any un-numbered non-header line         |
| Sets × Reps  | `3x8`, `4 x 5`                                                     |
| Sets / Reps  | `3 sets`, `8 reps`, `8-12 reps`                                    |
| Rounds       | `3 rounds`, `3 rds`                                                |
| Duration     | `30s`, `45 sec`, `2 min`, `3:00`                                   |
| Keyword lines| `Sets 3`, `Reps 8`, `Rounds 3`, `Duration 30s`, `Notes …`         |
| Rest day     | `Rest`, `Rest Day`, `Recovery`, `Recovery Day`, or an empty day   |
| Fallback     | Un-segmented exercises → **General**; unclassified text → **Notes** |

**Guarantee:** no coach information is silently discarded. Anything the parser cannot classify
is preserved as coach notes.

---

## Known limitations (prototype scope)

- Metric extraction is heuristic; unusual inline formats may land extra text in **Notes** rather
  than a dedicated field (by design — information is preserved, never dropped).
- Distances such as `500m` are not treated as a duration; the app has no distance field in MVP,
  so distance remains in the exercise name/notes.
- App icon is a placeholder color asset (no artwork).
- Everything in [`Dev.md` §21 "Future Enhancements"](./Rec/Dev.md) (history editing, timers,
  progress tracking, OCR/PDF import, notifications, etc.) is intentionally out of scope.

---

## Testing

`GymJamTests/WorkoutParserTests.swift` (Swift Testing) covers the highest-risk component — the
parser: week/day/segment/exercise detection, `3x8`, keyword lines, rest days, the *General*
fallback, inconsistent numbering, notes preservation, and date mapping. Run with **⌘U**.
