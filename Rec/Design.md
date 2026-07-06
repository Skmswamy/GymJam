Local iOS app that ingests a pasted WhatsApp workout plan, parses it into daily WOD cards, and opens YouTube search results in an in-app webview per exercise. Zero-friction: paste → parse → workout. No login, no backend, no AI in v1 (regex parser + WKWebView).
Assumptions

Single-user, on-device only. No sync, no auth.
iOS 17+ (SwiftUI, native date picker, WKWebView, SwiftData).
Coach messages follow ~90% consistent structure (Week / Day / Segment / Exercise). Remaining 10% handled via manual edit.
YouTube results accessed via public web search in WKWebView — no API key, no quota.
"Segments" = grouping like Conditioning, Strength, Mobility, etc.
Exercise format: Name — Sets x Reps (e.g., Goblet Squat — 3x10).
Dates in device local timezone.

Problem
Athlete receives long WhatsApp workout messages from coach. Every unfamiliar exercise requires leaving the chat, searching YouTube, filtering results — high friction that kills workout motivation.
Target User
Single user (you) — recreational athlete receiving coached programming via WhatsApp.
Job To Be Done

"When I open my workout, show me today's exercises and let me pull up a YouTube tutorial instantly, without leaving the app."

Information Architecture

Tabs (bottom nav): Home · WOD (Update)
Home = list of WOD cards sorted by relevance.
WOD tab = Update screen (paste + date range + submit).
Card tap → WOD Detail (segments → exercises → YouTube logo button).
YT logo tap → full-screen WKWebView interstitial with YouTube search results.

Screen Specs
1. Home Screen
Header: "WODs" (left-aligned, bold).
Card list (vertical scroll):
| Element                      | Detail                                                               |
| ---------------------------- | -------------------------------------------------------------------- |
| Date                         | `MM/DD/YYYY` — top-left of card                                      |
| Segments                     | Comma or line-separated list (e.g., "Conditioning, Strength")        |
| # of workouts                | Total exercise count across all segments for that day, right-aligned |
| Complete CTA                 | Checkmark button, right side; tap → confirm → remove card            |
| State: Today                 | Highlighted (accent border), sorted to top                           |
| State: Upcoming              | Default styling, sorted by ascending date below Today                |
| State: Past (this week)      | Moved to bottom, date shown in **red**, still tappable               |
| State: Past (previous weeks) | Auto-archived after week ends until new update is submitted          |

Sort order (top → bottom):

Today
Upcoming (asc)
Past this week (desc, red date)
Empty state if no active plan → CTA "Add your first workout" → WOD tab.

Edge cases:

Multiple WODs on same date → stack chronologically by segment order in source text.
No workout for today → show "Rest day" placeholder card if plan covers today but has no exercises.
Date range ended → prompt banner "Plan ended. Add new workout."

2. WOD Detail Screen
Header: Back · MM/DD/YYYY
Body (grouped by Segment):
Segment Name: Conditioning
  ┌──────────────────────────────────────┐
  │ Workout Name                         │
  │ Sets   Reps               [ ▶ YT ]   │
  │  X      Y                            │
  └──────────────────────────────────────┘

YouTube logo button (right side of exercise row):

Official YouTube "play" mark, min 44×44 tap target.
VoiceOver label: "Search YouTube for {exercise name}".
States: default, pressed, disabled (offline).



On tap → YouTube Interstitial (full-screen sheet):

Top bar: Close (X) left · Exercise name center · Open in YouTube app right (optional external handoff).
Body: WKWebView loaded with YouTube search results URL for the exercise name.
Behavior: User scrolls, taps a result, video plays inside the same webview. Back gesture returns to results list within the interstitial.
Dismiss: Tap X or swipe down → returns to WOD Detail.

Interstitial states:
| State           | UI                                      |
| --------------- | --------------------------------------- |
| Loading         | Skeleton + spinner over webview         |
| Offline         | "No internet. Try again." + Retry       |
| Load error      | "Couldn't load YouTube. Retry / Close." |
| Slow load (>5s) | Keep spinner; do not block dismiss      |

Edge cases:

Ambiguous exercise name (e.g., "AMRAP 12") → YT button still works; user can refine search inside webview.
Very long name → truncate in query to 100 chars.

3. Update Screen (WOD tab)
Header: "Select dates and paste workout to continue."
Fields:

Dates: Two pill inputs Start — End. Tap opens native UIDatePicker (graphical). End ≥ Start.
Paste text area: Multi-line, expandable, placeholder "Paste text here". Supports clipboard paste.
Submit button: Bottom center. Disabled until Start, End, and text field all filled. Filled black when active.

On Submit:

Parse text → preview screen shows detected Weeks/Days/Segments/Exercises.
User confirms → data saved locally, navigate to Home.
Parse failure → highlight unparsed lines, allow inline edit.

Edge cases:

Overlapping plan dates → warn "This overwrites Days X–Y from current plan. Continue?"
Text too short (<20 chars) → disable submit + hint.
Paste contains emojis / non-ASCII → strip and continue.
Date range shorter than plan content → warn and truncate.
Date range longer than plan content → allow, fill missing days as "Rest".

Design System

Style: Minimal, high-contrast, black/white base + 1 accent (suggest energetic red-orange).
Typography: SF Pro; Title 20, Body 16, Caption 13.
Radius: 16pt cards, 12pt buttons.
States: Default, Pressed, Disabled, Loading, Error, Empty defined for every interactive element.
Motion: Card tap scale 0.98; sheet slide-up 250ms.

Accessibility

Dynamic Type support (including inside webview via native rendering).
VoiceOver: card announces "Date, N workouts, segments X and Y".
YT button announces exercise name + action.
Min tap target 44x44.
Red past-date accompanied by "Past" label (not color-only).
Close button in interstitial always reachable.

Success Metrics (Design)

Time from app open → YouTube results for today's first exercise ≤ 10s.
Paste-to-parsed WODs success ≥ 90% first attempt.
Zero taps to reach today's WOD from Home.


Update to align with Update 2 on Dev.md:
Local iOS app. Paste WhatsApp workout → regex parser extracts what it can → preview screen for quick edits → daily WOD cards. Each exercise has a YouTube logo button that opens in-app WKWebView search. No backend, no API keys, no LLM, no third-party SDKs.

Assumptions

Single-user, on-device only.
iOS 17+ (SwiftUI, DatePicker, WKWebView, SwiftData).
Coach message structure varies — parser handles the common ~65%, preview handles the rest.
YouTube results via public web search in WKWebView (no API key).
Dates in device local timezone.

Problem
Coach sends multi-week workout blocks via WhatsApp. Looking up each unfamiliar exercise on YouTube kills momentum. Need a local app that renders the plan and gives one-tap access to a tutorial.
Target User
Single user (you) — recreational athlete on coached programming.
Job To Be Done

"Open my workout, see today's exercises, tap a YouTube icon to find a tutorial, without leaving the app."

Information Architecture

Tabs: Home · WOD (Update)
Home = daily WOD cards sorted by date relevance
WOD tab = paste + date range + submit → Preview → save
Card tap → WOD Detail (segments → exercises → YT button)
YT tap → full-screen WKWebView interstitial

Screen Specs
1. Home Screen
Header: "WODs"
Card:
| Element       | Detail                                            |
| ------------- | ------------------------------------------------- |
| Date          | `MM/DD/YYYY` top-left                             |
| Segments      | Comma-separated (e.g., "A: WOD, B: Lactate Pump") |
| # of workouts | Total exercise count, top-right                   |
| Complete CTA  | Checkmark right-side; confirm → remove from Home  |


Sort order: Today (highlighted) → Upcoming asc → Past-this-week desc (red date + "Past" label) → archived after week ends.
Edge cases:

Rest day → placeholder "Rest" card.
Plan ended → banner "Plan ended. Add new workout."
No plan → empty state → CTA to WOD tab.

2. WOD Detail Screen
Header: Back · MM/DD/YYYY
Grouped by Segment:
A: Workout of the day
  ┌──────────────────────────────────────┐
  │ Weighted GHD back extension          │
  │ 3 sets × 15 reps          [ ▶ YT ]   │
  │ Notes: Glute bias                    │
  └──────────────────────────────────────┘

Row variants (parser output determines layout):
| Type                 | Display                                              |
| -------------------- | ---------------------------------------------------- |
| Standard             | `N sets × N reps`                                    |
| Each-side            | `N sets × N reps each side`                          |
| Timed hold           | `N sets × N sec hold`                                |
| Interval             | `N rounds · N sec on / N sec off`                    |
| Superset             | Two rows joined by left bracket `[` + "SUPERSET" tag |
| Block (EMOTM/TABATA) | Collapsible card listing child movements             |
| Build to max         | "Build to N-rep max" pill                            |
| Name only            | Name + "No sets/reps" caption                        |


YouTube logo button on every row (44×44 min).
Tap → full-screen sheet with WKWebView loading youtube.com/results?search_query=<name>+tutorial.

3. Update Screen

Start / End date pills → native DatePicker (graphical).
Multi-line paste text area.
Submit disabled until both dates + text present.

4. Preview Screen (mandatory, promoted from optional)
Header: "Review your workout" · Save (top-right)
Layout:

Grouped: Day → Segment → Exercise rows.
Each row shows parsed fields + confidence badge:

🟢 High — full match
🟡 Medium — partial (missing sets or reps)
🔴 Low / Unparsed — raw line preserved, inline text field to edit



Actions per row:

Tap → inline edit (name, sets, reps, duration, each-side toggle, notes).
Swipe left → delete.
Long-press → reassign to different segment/day.

"Needs Review" bucket: unparsed lines shown at bottom of each day. User can:

Convert to exercise (fill fields).
Merge with previous row (compound set).
Delete.
Leave as-is (saved as name-only with rawLine preserved).

Save button: always enabled. Unresolved rows saved as-is; user owns the tradeoff.
Edit later: every exercise remains editable from WOD Detail (pencil icon).
Design System

Minimal, high-contrast, B&W + 1 accent.
SF Pro; Title 20 / Body 16 / Caption 13.
16pt card radius, 12pt button radius.
Motion: 0.98 card press scale, 250ms sheet slide.

Accessibility

Dynamic Type.
VoiceOver: card announces "Date, N workouts, segments X, Y".
YT button: "Search YouTube for {name}".
Red past-date always paired with "Past" text label.
44×44 min tap targets.

Success Metrics

Paste → preview → save in ≤ 60s for a full week.
≥65% of exercise lines parse to 🟢 High confidence.
0 taps between Home and today's first YT tutorial (aside from card + row + YT logo).



