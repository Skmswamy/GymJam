SwiftUI iOS app targeting iOS 17+. Local persistence via SwiftData. Regex-based parser for coach's message format. YouTube search opened in-app via WKWebView interstitial. No backend, no API keys, no third-party SDKs.
Architecture
[SwiftUI Views]
     │
     ├── ViewModels (MVVM)
     │
     ├── ParserService         ── regex + heuristics
     ├── PlanStore             ── SwiftData (Plan, WOD, Segment, Exercise)
     └── YouTubeSearchWebView  ── WKWebView (search + playback in interstitial)


Parser Requirements
Input: Raw pasted text (multiline).
Output: [WOD] mapped to date range.
Detection rules (regex + heuristics):
| Token    | Pattern (example)                                                                                                           |
| -------- | --------------------------------------------------------------------------------------------------------------------------- |
| Week     | `Week\s*#?\s*(\d+)`                                                                                                         |
| Day      | `(Mon\|Tue\|Wed\|Thu\|Fri\|Sat\|Sun)[a-z]*`                                                                                 |
| Segment  | Line matches known list: `Conditioning\|Strength\|Mobility\|Warm-?up\|Cool-?down\|WOD\|Skill\|Accessory` (case-insensitive) |
| Exercise | Line with pattern `<name>\s*[—\-–:]\s*(\d+)\s*[xX×]\s*(\d+\+?\|AMRAP\|max)` OR bullet `- <name> 3x10`                       |


Mapping logic:

Extract startDate and endDate from Update screen.
Group lines by Week → Day.
Assign each Day to a calendar date: startDate + offset(dayOfWeek).
If multiple weeks, increment week offset by 7 days.
Days without exercises → mark as Rest.

Fallback:

Any unparsed block → surface in preview UI with editable text field.
Save rawText always so user can re-parse.

YouTube Search Interstitial
Component: YouTubeSearchWebView (SwiftUI wrapper around WKWebView).
URL construction: https://www.youtube.com/results?search_query=<url-encoded exercise name>+tutorial

URL-encode via addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed).
Append +tutorial to bias toward instructional content.
No API keys, no tokens.

WKWebView configuration:
| Setting                                    | Value          | Reason                                 |
| ------------------------------------------ | -------------- | -------------------------------------- |
| `allowsInlineMediaPlayback`                | `true`         | Play video without leaving webview     |
| `mediaTypesRequiringUserActionForPlayback` | `[]`           | Standard tap-to-play                   |
| `websiteDataStore`                         | `.default()`   | Persist login/cookies if user signs in |
| `navigationDelegate`                       | custom         | Handle errors, external links          |
| User agent                                 | default mobile | Serve mobile YouTube UI                |


Presentation:

Present as full-screen sheet (.fullScreenCover in SwiftUI).
Dismiss via close button or interactive swipe.
Release webview on dismiss to avoid memory leaks.

Navigation delegate rules:

Allow: youtube.com, youtu.be, google.com (auth), googleusercontent.com, ytimg.com.
Block all other domains.
"Open in YouTube app" → UIApplication.shared.open(URL) with youtube:// scheme; fallback to https.

Functional Requirements
FR1 — Paste & Parse

Text area accepts up to 20,000 chars.
Parse runs on Submit; loading state max 2s.
Preview screen lets user edit before saving.

FR2 — Date Range

Native DatePicker (graphical style).
Validation: endDate >= startDate; both required.
Timezone: device local.

FR3 — Home Sorting
sorted = [today] + [upcoming asc] + [past-this-week desc (red)]
Past weeks archived until new Plan submitted.

FR4 — Card Completion

"Complete" CTA on card → confirm dialog → isCompleted = true → remove from Home list (retain in DB).

FR5 — WOD Detail

Grouped by Segment (source order).
Each exercise row renders a YTLogoButton.
Tap → present YouTubeSearchWebView(query: exercise.name).
No pre-fetch, no caching — always live search.

FR6 — Overwrite Handling

New Plan overlapping existing dates → warning modal → user chooses Overwrite / Merge / Cancel.

FR7 — External Handoff (optional)

"Open in YouTube app" in interstitial top bar deep-links to native app if installed; else reload in webview.

Non-Functional Requirements
| Category          | Target                                                     |
| ----------------- | ---------------------------------------------------------- |
| Cold start        | ≤ 1.5s                                                     |
| Parse time        | ≤ 2s for 5,000-char input                                  |
| Webview cold load | ≤ 2.5s p90 on 4G                                           |
| Offline           | Home + WOD detail work offline; YT button disabled         |
| Storage           | <50MB                                                      |
| Memory            | Release webview on dismiss; nil out delegate               |
| Crash-free        | ≥ 99.5%                                                    |
| Privacy           | No data leaves device except webview's own YouTube traffic |



Edge Cases (must handle)
| Case                                             | Behavior                                                |
| ------------------------------------------------ | ------------------------------------------------------- |
| Empty paste                                      | Submit disabled                                         |
| Start > End                                      | Inline error, block submit                              |
| Same-day plan                                    | Allowed; single WOD                                     |
| Plan spans DST change                            | Use `Calendar.current` day math, not seconds            |
| Duplicate exercise names                         | Allowed; each row independent                           |
| Non-English exercise name                        | URL-encoded; YouTube handles rendering                  |
| Coach message has emojis / stickers              | Strip in preprocessor                                   |
| Coach uses "reps: 10, sets: 3" instead of "3x10" | Parser handles both orders                              |
| Missing day (coach skipped Wed)                  | Mark as Rest                                            |
| Week 2 starts mid-range                          | Compute from Week 1 anchor date                         |
| User completes all WODs before endDate           | Show "Plan complete" state                              |
| Offline                                          | YT button disabled with strikethrough + toast on tap    |
| Webview fails to load                            | Retry + Close in interstitial                           |
| Airplane mode mid-view                           | Show offline state, allow dismiss                       |
| Very long exercise name                          | Truncate query to 100 chars                             |
| Special chars (`½`, `°`, `+`, `&`)               | Fully URL-encode                                        |
| Ambiguous name (e.g., "AMRAP 12")                | Allow search; user refines in webview                   |
| User signed into YouTube in webview              | Persist via `.default()` data store                     |
| EU consent / cookie banner                       | Rendered by YouTube; user handles once, cookies persist |
| User backgrounds app mid-video                   | Webview pauses per YouTube default; resumes on return   |
| Multiple rapid taps on YT button                 | Debounce 500ms to prevent duplicate presentations       |
| Deep link to external app inside webview         | Blocked unless whitelisted                              |
| Timezone changes mid-plan                        | Recompute dates on app foreground                       |


MVP Scope
In: Paste + parse, date range, Home sorting, complete CTA, overwrite handling, WOD detail with YT logo button, in-app YouTube webview interstitial.
Out: Multi-user, cloud sync, notifications, workout timers, exercise history, coach chat, AI parsing (v1.1 candidate), video pre-fetch/caching.

| Risk                                   | Mitigation                                       |
| -------------------------------------- | ------------------------------------------------ |
| Parser fails on 10% variant messages   | Preview + inline edit before save                |
| YouTube changes mobile web layout      | Webview auto-adapts; no parsing dependency       |
| Autoplay blocked                       | Standard tap-to-play; document behavior          |
| WKWebView memory leaks                 | Deallocate on dismiss; nil out delegate          |
| EU consent flow blocks results         | User completes once; cookies persist             |
| Deep link hijack attempts              | Strict domain allowlist in navigation delegate   |
| Wrong search result for ambiguous name | User refines inside webview search bar           |
| DST / timezone bugs                    | Use `Calendar` day arithmetic, never raw seconds |
| Coach changes message format           | v1.1: add AI fallback parser (GPT-4o mini)       |




Update 1:
Updated Parser Requirements (replaces prior spec)
Rule 1 — Segment Detection (broader)
^[A-C]\s*[-–]\s*(.+)$    → Segment header (name = capture group)

Not a fixed allowlist. Any A-, B-, C- line is a segment. Name is free text.
Rule 2 — Exercise Line (multi-pattern)
Try in order, first match wins:
| Priority | Pattern                                                                               | Captures                    |
| -------- | ------------------------------------------------------------------------------------- | --------------------------- |
| P1       | `(.+?)\s*(\d+)\s*(?:reps?)?\s*(es)?\s*\*\s*(\d+)\s*(?:sets?)?`                        | name, reps, each-side, sets |
| P2       | `(.+?)\s*\*\s*(\d+)\s*sets?` (reps missing)                                           | name, sets                  |
| P3       | `(\d+)\s*(?:secs?)\s*(?:on)?\s*(\d+)?\s*(?:secs?)?\s*(?:off)?\s*\*\s*(\d+)\s*rounds?` | interval work               |
| P4       | `(\d+)\s*(?:secs?)\s+(.+)`                                                            | timed hold                  |
| P5       | `Build to\s+(.+?)\s+(\d+)\s*reps?\s*max`                                              | build-to-max                |
| P6       | Line starts with number/dash and has letters                                          | name-only exercise          |


Rule 3 — Compound Sets
If line contains + between two exercise-like fragments, split into two Exercise records with shared supersetId.
Rule 4 — Block Formats (EMOTM / TABATA / AMRAP)
Detect header keywords: EMOTM, TABATA, AMRAP, EMOM, Every \d+ min.
Treat entire block as a single BlockExercise with:

type: emotm / tabata / amrap
duration: parsed from header
movements: list of child lines (Min-1 X, Min-2 Y, or just numbered items)

Rule 5 — Day Detection
^(Monday|Tuesday|Wednesday|Thursday|Friday|Saturday|Sunday)\s*$
Case-insensitive. Trailing spaces tolerated.

Rule 6 — Week Detection
^Week[-\s]*(\d+)

Rule 7 — Ignore Numbering
Never trust 1-, 2- prefixes. Use line order within a segment as source of truth (numbering skips and duplicates in real data).

Updated Data Model:
Exercise {
  id: UUID
  name: String
  sets: Int?
  reps: String?           // "10", "10-12", "AMRAP", "max"
  eachSide: Bool          // "es" flag
  durationSec: Int?       // for timed holds
  intervalWork: Int?      // secs on
  intervalRest: Int?      // secs off
  rounds: Int?            // total rounds
  supersetId: UUID?       // links compound "+" pairs
  buildToMax: Bool
  notes: String?          // parenthetical text
  rawLine: String
  parsedConfidence: Float // 0.0–1.0
}

BlockExercise {          // NEW: EMOTM / TABATA / AMRAP wrappers
  id: UUID
  type: BlockType         // .emotm, .tabata, .amrap
  totalDurationMin: Int?
  movements: [Exercise]
}

Segment {
  id: UUID
  prefix: String?         // "A", "B", "C"
  name: String            // "Workout of the day", "Lactate Pump", free text
  order: Int
  exercises: [Exercise]
  blocks: [BlockExercise]
}



Update 2:
SwiftUI iOS 17+. SwiftData persistence. Multi-priority regex parser with confidence scoring. WKWebView interstitial for YouTube. No backend, no API keys, no LLM, no third-party SDKs.

Update 3:
Resolved platform discrepancy: SwiftData is retained, so the implementation target is iOS 17+ rather than iOS 16+. This matches Apple's SwiftData availability and keeps the app local-only without introducing a custom persistence layer.

Architecture
[SwiftUI Views]
     │
     ├── ViewModels (MVVM)
     │
     ├── ParserService        ── multi-pattern regex + block detector
     ├── PreviewViewModel     ── confidence scoring + edit ops
     ├── PlanStore            ── SwiftData
     └── YouTubeSearchWebView ── WKWebView (search + playback in interstitial)


Tech Stack
| Layer       | Choice                             |
| ----------- | ---------------------------------- |
| UI          | SwiftUI, iOS 16+                   |
| State       | MVVM + `@Observable`               |
| Persistence | SwiftData                          |
| Networking  | None (webview only)                |
| Video       | WKWebView → `youtube.com/results`  |
| Date UI     | Native `DatePicker` (`.graphical`) |
| Analytics   | None (local console log for debug) |


Data Model
Plan {
  id: UUID
  startDate: Date
  endDate: Date
  rawText: String
  createdAt: Date
}

WOD {
  id: UUID
  planId: UUID
  date: Date
  weekNumber: Int?
  dayOfWeek: String?
  isCompleted: Bool
  segments: [Segment]
}

Segment {
  id: UUID
  prefix: String?         // "A", "B", "C"
  name: String            // "Workout of the day", free text
  order: Int
  exercises: [Exercise]
  blocks: [BlockExercise]
}

Exercise {
  id: UUID
  name: String
  sets: Int?
  reps: String?           // "10", "10-12", "AMRAP", "max"
  eachSide: Bool
  durationSec: Int?
  intervalWork: Int?
  intervalRest: Int?
  rounds: Int?
  supersetId: UUID?
  buildToMax: Bool
  notes: String?
  rawLine: String
  parsedConfidence: Float // 0.0–1.0
  userEdited: Bool
}

BlockExercise {
  id: UUID
  type: BlockType         // .emotm, .tabata, .amrap, .rounds
  totalDurationMin: Int?
  workSec: Int?
  restSec: Int?
  rounds: Int?
  movements: [Exercise]
}

Parser Requirements
Preprocessing

Normalize whitespace, strip emojis/stickers.
Fix common typos in known tokens (Barbel → Barbell, Palloff → keep verbatim but store normalized name for search).
Collapse multiple spaces around *, x, ×.

Detection Rules
| Rule                | Pattern                                                                     | Priority        |
| ------------------- | --------------------------------------------------------------------------- | --------------- |
| Week                | `^Week[-\s]*(\d+)`                                                          | 1               |
| Day                 | `^(Mon\|Tue\|Wed\|Thu\|Fri\|Sat\|Sun)[a-z]*\s*$` (case-insensitive)         | 1               |
| Segment             | `^[A-C]\s*[-–]\s*(.+)$` (free-text name)                                    | 2               |
| Block header        | `EMOTM\|EMOM\|TABATA\|AMRAP\|Every\s+\d+\s+min`                             | 3 (block start) |
| Interval            | `(\d+)\s*secs?\s*on\s*(\d+)\s*secs?\s*off\s*[\*×x]\s*(\d+)\s*rounds?`       | 4               |
| Timed hold          | `(\d+)\s*secs?\s+(.+)`                                                      | 5               |
| Build to max        | `Build\s+to\s+.*?(\d+)\s*reps?\s*max`                                       | 6               |
| Standard            | `(.+?)\s+(\d+)\s*(reps?)?\s*(es)?\s*[\*×x]\s*(\d+)\s*(sets?)?`              | 7               |
| Reversed            | `(.+?)\s+(\d+)\s*(?:sets?)\s*[\*×x]\s*(\d+)\s*(?:reps?)?`                   | 7               |
| Compact             | `(.+?)\s+(\d+)(es)?\s*\*\s*(\d+)sets?`                                      | 7               |
| Compound (superset) | Line contains `+` between two exercise patterns → split, share `supersetId` | 8               |
| Name-only           | Line has letters, no numeric structure → save as name only, confidence 0.4  | 9               |


Confidence Scoring
1.0  = all fields captured (name, sets, reps)
0.8  = name + sets OR name + reps
0.6  = timed/interval/block match
0.4  = name only
0.2  = unmatched, saved as rawLine

Line-Order Rule
Ignore numeric prefixes (1-, 2-, 3-). Line order within a segment is the source of truth. Real data skips and duplicates numbers.
Block Parsing
When a block header is detected:

Consume header line → create BlockExercise with type + duration.
Consume child lines until next segment/day/blank → parse each as movement (may be Min-N X reps or plain numbered).
Attach movements to BlockExercise.movements.

Day → Date Mapping

Anchor Week 1 first day = startDate.
For each subsequent Day, compute date = startDate + (weekOffset × 7) + dayOfWeekOffset.
Days without exercises = Rest.
If mapped date > endDate → warn in preview, do not save.

Functional Requirements
FR1 — Paste & Parse

Text area max 20,000 chars.
Parse on Submit; loading state max 2s.
Always route to Preview screen (no direct save).

FR2 — Date Range

Native DatePicker graphical.
Validation: endDate >= startDate.
Device local timezone.

FR3 — Preview & Edit

Grouped list: Day → Segment → Exercise.
Row edit sheet: name, sets, reps, duration, each-side, notes.
Swipe delete, long-press reassign.
"Needs Review" bucket per day for unparsed lines.
Save always enabled.

FR4 — Home Sorting
sorted = [today] + [upcoming asc] + [past-this-week desc (red)]
Past weeks archived until new Plan submitted.

FR5 — Card Completion

Complete CTA → confirm → isCompleted = true → hidden from Home, retained in DB.

FR6 — WOD Detail

Grouped by Segment, source order.
Row layout adapts to exercise type (standard / timed / interval / superset / block / name-only).
Pencil icon on each row → inline edit post-save.
YT logo button on every row.

FR7 — YouTube Interstitial

Full-screen .fullScreenCover.
WKWebView loads https://www.youtube.com/results?search_query=<url-encoded name>+tutorial.
URL-encode via .urlQueryAllowed; truncate query to 100 chars.
Config:

allowsInlineMediaPlayback = true
mediaTypesRequiringUserActionForPlayback = []
websiteDataStore = .default()


Domain allowlist: youtube.com, youtu.be, google.com, googleusercontent.com, ytimg.com. Block all others.
"Open in YouTube app" → youtube:// scheme, fallback to https.
Release webview on dismiss.

FR8 — Overwrite Handling

New Plan with overlapping dates → modal: Overwrite / Merge / Cancel.

Non-Functional Requirements
| Category          | Target                                                     |
| ----------------- | ---------------------------------------------------------- |
| Cold start        | ≤ 1.5s                                                     |
| Parse time        | ≤ 2s for 5,000 chars                                       |
| Webview cold load | ≤ 2.5s p90 on 4G                                           |
| Offline           | Home + Detail work; YT button disabled                     |
| Storage           | <50MB                                                      |
| Memory            | Webview released on dismiss                                |
| Crash-free        | ≥ 99.5%                                                    |
| Privacy           | No data leaves device except webview's own YouTube traffic |

Edge Cases
| Case                               | Behavior                                                  |
| ---------------------------------- | --------------------------------------------------------- |
| Empty paste                        | Submit disabled                                           |
| Start > End                        | Inline error                                              |
| Same-day plan                      | Allowed                                                   |
| DST change mid-plan                | Use `Calendar` day math, not seconds                      |
| Duplicate exercise names           | Independent rows                                          |
| Non-English name                   | URL-encoded, passed to YouTube                            |
| Emojis/stickers in paste           | Stripped in preprocessor                                  |
| Reversed sets/reps order           | Parser rule 7 (reversed)                                  |
| Missing day                        | Rest card                                                 |
| Week 2 starts mid-range            | Anchor from Week 1 first day                              |
| Plan complete before endDate       | "Plan complete" state                                     |
| Offline                            | YT button disabled with strikethrough                     |
| Webview fails                      | Retry + Close                                             |
| Long name                          | Truncate query to 100 chars                               |
| Special chars (`½`, `°`, `+`, `&`) | URL-encoded                                               |
| Ambiguous name                     | User refines in webview search bar                        |
| EU consent banner                  | User handles once; cookies persist via `.default()` store |
| Rapid YT taps                      | Debounce 500ms                                            |
| Deep-link hijack attempt           | Blocked by allowlist                                      |
| Timezone change mid-plan           | Recompute on foreground                                   |
| EMOTM/TABATA block                 | Parsed to `BlockExercise`, shown collapsible              |
| Superset `+`                       | Split, share `supersetId`, bracket visual                 |
| Build-to-max                       | Pill display, no sets field required                      |
| Numbering skips/duplicates         | Ignored, line order used                                  |
| Two segments same prefix (`B-`)    | Both kept, distinguished by order                         |
| Parenthetical notes                | Extracted to `notes` field                                |

Risks & Mitigations
| Risk                                 | Mitigation                                                    |
| ------------------------------------ | ------------------------------------------------------------- |
| Parser misses 30–40% of lines        | Fast preview + edit; confidence badges; "Needs Review" bucket |
| Coach changes format                 | Parser is line-order based, tolerant to numbering changes     |
| WKWebView memory leaks               | Release on dismiss, nil delegate                              |
| EU consent flow                      | Cookies persist across sessions                               |
| DST/timezone bugs                    | Calendar day arithmetic                                       |
| Deep-link hijack                     | Domain allowlist                                              |
| User frustration from manual cleanup | Make preview edit fast (inline, swipe, long-press)            |





