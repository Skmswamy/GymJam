# GymJam — Design & Architecture Spec

_A consolidated deliverable produced collaboratively by the PM, UX, Database Architect,
Software Engineer, and QA personas defined in `/Agents`._

---

## 1. PM — Product Alignment & Clarifications

**TL;DR:** GymJam is an offline-first, no-account iOS app that turns a pasted WhatsApp
workout message into a clean, date-organized, distraction-free workout experience with
one-tap YouTube tutorials. No AI, no tracking, no cloud. Deterministic parsing only.

**Resolved decisions (assumptions where the PRD was silent, confirmed with the user):**

| # | Question | Decision |
|---|----------|----------|
| 1 | Persistence stack | SwiftData (iOS 17+) — least boilerplate, matches "minimal" brief |
| 2 | Tutorial browser | `SFSafariViewController` — in-app, preserves workout position |
| 3 | Reps/Sets typing | Stored as **String**, not Int — coaches write `8-12`, `AMRAP`, `8/side` |
| 4 | Day→date mapping | First parsed day = Start Date; each following day advances to the next matching weekday |
| 5 | Import replacement | New import **archives** the current active cycle (moves it to History), never destructive |
| 6 | Storage banner | Implemented + wired, but text-only data means it effectively never fires (per PRD note) |

**Success = MVP definition (PRD §22):** paste → import → open today → follow in order →
watch tutorial in-app → complete → offline throughout.

---

## 2. UX — Experience Direction

**Experience principles:** (1) Zero cognitive overhead — two primary actions: *see today*,
*import*. (2) Content is the coach's words, verbatim. (3) Progressive disclosure — only show
fields that have values. (4) Calm, minimal, high-contrast, large tap targets. (5) Never lose
coach information.

**Information architecture (bottom tab bar):**

```
Home   |   History   |   Import
```

**Screen hierarchy & states**

- **Home** — chronological workout cards. Ordering priority: *Today → Future → Past → Expired*.
  Empty state when nothing imported. Past dates render date in red + reduced opacity. Each card
  has a separate `Complete Workout` CTA (confirm dialog) distinct from tap-to-open.
- **Workout Detail** — segments in coach order (never sorted), exercise cards showing only
  populated fields, `Watch Tutorial` opens in-app browser. Rest days show a friendly recovery card.
- **Import** — Start/End native date pickers (End ≥ Start), large multiline paste field,
  Submit disabled until valid. On success: parse → save → return Home.
- **History** — read-only archive grouped Month → Week → Day (newest first), with completion %.

**Visual system:** system font + Dynamic Type, single accent color, generous vertical rhythm,
rounded cards, subtle separators. No custom chrome, no gradients, no marketing flourish.

---

## 3. Database Architect — Local Data Model (SwiftData)

Offline, single-device, no PII, no account. One **active** cycle at a time; older cycles are
archived (kept, hidden from Home, surfaced in History). Cascade delete from cycle → day →
segment → exercise. Ordering is explicit via `displayOrder` because SwiftData relationship
arrays are unordered.

```
WorkoutCycle
  id: UUID
  startDate: Date
  endDate: Date
  weekNumber: Int?
  dateImported: Date
  isActive: Bool                 // exactly one true at a time
  days: [WorkoutDay]             // cascade

WorkoutDay
  id: UUID
  date: Date
  dayName: String
  isCompleted: Bool
  isRestDay: Bool
  displayOrder: Int
  segments: [Segment]           // cascade
  cycle: WorkoutCycle?          // inverse

Segment
  id: UUID
  name: String
  displayOrder: Int
  exercises: [Exercise]         // cascade
  day: WorkoutDay?              // inverse

Exercise
  id: UUID
  name: String                  // verbatim coach text
  sets: String?
  reps: String?
  duration: String?
  rounds: String?
  coachNotes: String?
  displayOrder: Int
  segment: Segment?             // inverse
```

**Consistency rules:** import runs in one transaction; on parse failure nothing is saved
(PRD §11). Setting a new cycle active flips the previous cycle's `isActive` to false in the
same save. Completion toggles only the single `WorkoutDay.isCompleted`.

**Analytics:** local-only event log (`AnalyticsService`), no network. Events: workout_imported,
workout_opened, tutorial_opened, workout_completed, import_failed, parser_failed.

---

## 4. SE — Engineering Approach

- **Pattern:** SwiftUI + SwiftData, MV(Store) — views bind to `@Query`/`@Environment(\.modelContext)`;
  a thin `WorkoutStore` owns import/complete/archive transactions; a pure `WorkoutParser`
  (no framework deps → fully unit-testable) does text→struct conversion.
- **Separation of concerns:** `Models/` (persistence), `Parsing/` (pure logic),
  `Services/` (store, analytics, storage estimator), `Views/` (UI), `Theme/` (tokens).
- **Performance:** parser is single-pass O(n) over lines; targets < 1s for 300 exercises.
  Lists use `List`/`LazyVStack` for 60fps. App launch is a plain SwiftUI `App`.
- **Accessibility:** Dynamic Type throughout, VoiceOver labels on cards/CTAs, ≥44pt targets,
  system colors for contrast.

---

## 5. QA — Validation Strategy

- **Unit tests** (`GymJamTests/WorkoutParserTests.swift`): week/day/segment/exercise detection,
  inline `3x8`, keyword lines, rest days, unnumbered exercises, "General" segment fallback,
  empty input, notes preservation, date mapping.
- **Structural validation:** `project.pbxproj` parsed as a plist to confirm integrity.
- **Manual QA matrix** documented in README (import happy path, empty/invalid dates,
  parser failure copy, expired styling, completion removal, history read-only).

Priority risk areas: parser tolerance (highest), date mapping across weekday gaps, and
archive-on-reimport not destroying history.
