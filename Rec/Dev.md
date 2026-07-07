# Product Requirements Document (PRD)
# GymJam – Workout Import & Guided Workout Experience (MVP)

**Version:** 1.0  
**Status:** Draft  
**Author:** Product Management  
**Platform:** iOS (SwiftUI)  
**Storage:** Local Device Only  
**Target Audience:** Junior iOS Developer

---

# 1. Overview

## Product Vision

GymJam is a lightweight workout companion that converts a workout program received through messaging applications (primarily WhatsApp) into a clean, structured, and distraction-free workout experience.

The application does **not** replace a coach, generate workouts, or track fitness progress.

Its sole purpose is to eliminate the friction between receiving a workout and performing it.

The application is intentionally offline-first, requires no user account, and stores all information locally on the user's device.

---

# 2. Problem Statement

Many personal trainers send workout plans through WhatsApp as long text messages.

Typical user flow today:

1. Open WhatsApp.
2. Scroll through a large workout message.
3. Read the next exercise.
4. Open YouTube.
5. Search for the exercise.
6. Watch a tutorial.
7. Return to WhatsApp.
8. Find the next exercise.
9. Repeat.

This repetitive context switching creates unnecessary friction before and during every workout.

The goal of GymJam is to remove this friction.

---

# 3. Goals

The application should allow a user to:

- Paste an entire workout message.
- Convert it into structured workout days.
- Display workouts in a clean format.
- Provide one-tap access to exercise tutorials.
- Allow workouts to be completed and removed.
- Automatically organize workouts by date.
- Operate entirely offline after import.

---

# 4. Non Goals

The MVP will NOT include:

- User accounts
- Cloud sync
- Apple Health integration
- Progress tracking
- Weight logging
- Rep logging
- Exercise history
- Workout timers
- Notifications
- AI coaching
- Workout generation
- Exercise recommendations
- Social features

---

# 5. User Persona

## Primary User

Someone working with a personal coach that sends workouts through WhatsApp.

Characteristics:

- Receives new workouts weekly or bi-weekly.
- Often unfamiliar with exercises.
- Needs YouTube demonstrations.
- Wants to start workouts quickly.
- Does not want to manually organize workouts.

---

# 6. User Journey

Receive WhatsApp workout

↓

Copy message

↓

Open GymJam

↓

Import Workout

↓

Select workout dates

↓

Paste workout

↓

Submit

↓

Workout parsed locally

↓

Workout appears on Home

↓

Tap today's workout

↓

Follow workout

↓

Watch YouTube tutorials when needed

↓

Complete workout

↓

Workout removed from Home

---

# 7. Navigation

Bottom Navigation

```
Home
Import
```

Only two tabs exist in MVP.

---

# 8. Screen 1 — Home

## Purpose

Display all imported workout days in chronological order.

---

## Layout

Navigation Title

```
Home
```

Below title

Scrollable list of Workout Cards.

---

## Empty State

If no workout has been imported:

Display

```
No workouts yet.

Import your first workout using the Import tab.
```

---

## Workout Card

Each workout day is represented by one card.

Display:

- Date
- Day Name
- Number of workout segments
- Total number of exercises
- Segment names

Example

```
Monday

July 8

Segments

Power
Strength
Conditioning

14 Exercises
```

---

## Card Ordering

Cards should always appear in the following priority.

Priority 1

Current day

Priority 2

Future workout days

Priority 3

Past workout days

Priority 4

Expired workout cycles

---

## Expired Workout Styling

Past workout dates should remain visible.

Requirements

- Display date in red.
- Reduce card opacity slightly.
- Do NOT delete automatically.

---

## Completed Workout

Each workout card contains a CTA

```
Complete Workout
```

This button is separate from opening the workout.

If tapped:

Display confirmation dialog.

```
Complete this workout?

Cancel

Complete
```

If confirmed

Remove workout card from Home.

Workout data is marked completed locally.

---

## Workout Completion Rules

Completing a workout removes only that workout day.

Remaining workout days remain unchanged.

---

## Card Selection

Tapping anywhere except the CTA opens Workout Detail.

---

# 9. Screen 2 — Workout Detail

## Purpose

Display every exercise for the selected workout day.

---

## Header

Display

Back

Workout Date

Day Name

---

## Segment Display

Segments appear in the same order as coach input.

Example

```
Power

Strength

Core
```

Do not alphabetically sort.

---

## Exercise Card

Each exercise displays:

Exercise Name

Sets

Reps

Rounds

Duration

Coach Notes

YouTube Tutorial

Only show fields containing values.

Example

```
DB Push Press

Sets
3

Reps
8

Notes

Use straps

Pause 3 seconds

[Watch Tutorial]
```

---

## YouTube Tutorial

Selecting Watch Tutorial opens an in-app browser.

Search Query

```
<Exercise Name> Exercise
```

Example

```
DB Push Press Exercise
```

The application should search YouTube.

Do not maintain an exercise database.

---

## Tutorial Browser

Requirements

Open inside application.

User may:

- Browse search results.
- Watch any video.
- Close browser.

Returning should preserve workout position.

---

## Exercise Order

Display exactly as coach provided.

Never reorder.

---

## Rest Day

If workout is a rest day

Display

```
Rest Day

Enjoy your recovery.
```

Do not show empty exercise cards.

---

# 10. Screen 3 — Import

## Purpose

Import a new workout cycle.

---

## Fields

### Start Date

Native iOS date picker.

Required.

---

### End Date

Native iOS date picker.

Required.

---

Validation

End Date

must be

greater than or equal to

Start Date.

---

### Workout Text

Large multiline text field.

Supports

Paste

Typing

Selection

Undo

---

Placeholder

```
Paste workout here...
```

---

## Submit Button

Disabled until

- Start Date selected
- End Date selected
- Workout text not empty

---

## Submit

When pressed

Application should

Validate

↓

Parse

↓

Save locally

↓

Return user to Home

---

# 11. Parsing Engine

## Objective

Convert coach text into structured workout objects.

No AI required.

Parser should use deterministic rules.

---

## Supported Structure

```
Week

↓

Day

↓

Segment

↓

Exercises
```

---

## Week Detection

Recognize

```
Week-1

Week 1

Week-13

Week-20
```

---

## Day Detection

Recognize

Monday

Tuesday

Wednesday

Thursday

Friday

Saturday

Sunday

---

## Segment Detection

Detect

```
A-

B-

C-

D-
```

Everything following becomes segment title.

Examples

```
A- Strength

B- Power

C- Core
```

---

## Exercise Detection

Exercise numbering should NOT be trusted.

Parser should detect exercise lines even if numbering is inconsistent.

Examples

```
1-

2-

3-

3-

5-

No numbering
```

All supported.

---

## Preserve Coach Text

Do not modify

- Exercise names
- Notes
- Tempo
- Coaching instructions

Store exactly as received.

---

## Structured Values

Extract where possible

- Sets
- Reps
- Duration
- Rounds

Everything else becomes

Coach Notes.

---

## Unknown Formats

If parser cannot classify text

Store inside

Coach Notes.

Never discard information.

---

## Rest Day Detection

Recognize

```
Rest

Rest Day

Recovery

Recovery Day
```

Create Rest Day workout.

---

## Parsing Failure

If workout cannot be parsed

Display

```
Unable to understand workout.

Please verify formatting.
```

Do not save partial data.

---

# 12. Local Storage

Application stores

Workout Cycle

↓

Workout Day

↓

Segment

↓

Exercise

All data remains on device.

No backend.

---

# 13. Data Model

## Workout Cycle

- ID
- Start Date
- End Date
- Week Number
- Date Imported

---

## Workout Day

- ID
- Date
- Day Name
- Completed
- Is Rest Day

---

## Segment

- ID
- Name
- Display Order

---

## Exercise

- ID
- Name
- Sets
- Reps
- Duration
- Rounds
- Coach Notes
- Display Order

---

# 14. Business Rules

## Dates

Workout dates are generated from

Start Date

+

Workout order.

---

Example

Workout starts Monday.

Monday

↓

Tuesday

↓

Wednesday

mapped automatically.

---

If workout starts on Wednesday

Wednesday becomes first workout day.

---

## Import Replacement

Importing a new workout replaces the current active workout cycle.

Previous completed workouts remain stored locally for future enhancement but are hidden from Home.

---

## Multiple Imports

Only one active workout cycle exists.

---

# 15. Validation

Reject submission if

- Empty workout
- Invalid dates
- End before start

---

Accept

Large workout text.

---

# 16. Edge Cases

## Duplicate Import

Same workout pasted twice.

Replace current workout after confirmation.

---

## Missing Segment

Exercises before first segment

Create

```
General
```

segment.

---

## Missing Sets

Display only exercise name.

---

## Missing Reps

Do not display rep field.

---

## Missing Notes

Hide notes section.

---

## Unknown Exercise

Still create exercise.

Tutorial uses exercise name.

---

## Empty Day

Create Rest Day.

---

## Weekend Rest

Support

```
Saturday and Sunday
Rest Day
```

---

## Extra Spaces

Ignore.

---

## Blank Lines

Ignore.

---

## Mixed Uppercase

Support.

---

## Typographical Errors

Parser should tolerate minor formatting inconsistencies where possible without altering coach content.

---

# 17. Performance

Workout import

Target

<1 second

Normal workout

300 exercises maximum.

---

Scrolling

Smooth 60 FPS.

---

App launch

Under 2 seconds.

---

# 18. Accessibility

Support

Dynamic Type

VoiceOver

Large Touch Targets

High Contrast

---

# 19. Analytics (Local Only)

Track locally

Workout Imported

Workout Opened

Tutorial Opened

Workout Completed

Import Failed

Parser Failed

No external analytics in MVP.

---

# 20. Acceptance Criteria

### Home

- Displays imported workouts.
- Orders correctly.
- Shows segment names.
- Opens workout details.
- Supports completion.

---

### Import

- Dates required.
- Text required.
- Submit disabled until valid.
- Successfully parses supported formats.

---

### Workout Detail

- Displays all segments.
- Displays all exercises.
- Preserves order.
- Opens YouTube search.
- Supports rest days.

---

### Parser

Supports

- Week detection
- Day detection
- Segment detection
- Exercise extraction
- Sets
- Reps
- Duration
- Coach notes
- Rest days
- Imperfect numbering
- Unknown text preservation

No workout information should be silently discarded.

---

# 21. Future Enhancements (Out of Scope)

- Exercise thumbnails
- Offline exercise videos
- Apple Health integration
- Workout history
- Weight logging
- Timer
- Rest timer
- Progress tracking
- Coach sharing
- PDF import
- OCR from screenshots
- AI-assisted parsing for unsupported formats
- Exercise favorites
- Calendar view
- Push notifications
- Search
- Multiple workout cycles
- Exercise substitutions

---

# 22. MVP Definition

The MVP is successful when a user can:

1. Receive a workout in WhatsApp.
2. Copy the message.
3. Paste it into GymJam.
4. Import the workout successfully.
5. Open today's workout.
6. View every exercise in order.
7. Watch YouTube tutorials without leaving the app.
8. Complete the workout.
9. Continue using the application with no internet dependency except YouTube search.

If these tasks are completed with minimal friction, the MVP has achieved its objective.



Updated Storage Strategy
Storage

GymJam is a fully offline application.

All workout data is stored locally on the user's device.

No workout information is transmitted to external servers.

No user account is required.

No cloud synchronization is performed.

The application should persist all workout data across application launches and device restarts.

Active Workout Rules

Only one Active Workout Cycle may exist at any given time.

Importing a new workout:

Archives the previous Active Workout Cycle.
Creates a new Active Workout Cycle.
Displays only the new cycle on the Home screen.

The user never has to manually archive workouts.

Workout History
Navigation

Bottom Navigation
Home
History
Import
Purpose

The History screen allows users to revisit previously imported workout cycles.

Historical workouts are read-only.

Users cannot accidentally modify archived workouts.
History
History Information Architecture:

└── 2026

    ├── July

    │   ├── Week 14
    │   │
    │   │── Monday
    │   │── Tuesday
    │   │── Wednesday
    │   │── Thursday
    │   │── Friday
    │
    │   ├── Week 13
    │   │
    │   │── Monday
    │   │── Tuesday
    │   │── Wednesday
    │
    ├── June
        ├── Week 12



Hierarchy
Month

↓

Week

↓

Workout Day


Newest month appears first.

Newest week appears first.

Days remain in chronological order.



History Card

Each archived week displays:

Week Number
Date Range
Number of Workout Days
Completion Percentage

Example
Week 14

Jul 7 – Jul 13

5 Workout Days

100% Completed

Daily Workout Card (History)

Displays
Monday

Segments

Strength

Conditioning

14 Exercises

Completed ✓



History Restrictions

Users may

Browse
Read
Watch YouTube tutorials

Users may not

Edit
Delete
Reorder
Mark complete
Change workout dates



Data Lifecycle
Import Workout

↓

Active Workout Cycle

↓

User completes workouts

↓

Imports New Workout

↓

Previous Cycle Archived

↓

Visible under History




Storage Limits

There is no hard storage limit enforced by the application.

Because workout plans are plain text with lightweight metadata, even hundreds of archived workout cycles consume very little storage (typically only a few megabytes).

To maintain transparency, GymJam should estimate the total local storage used by workout data.

If stored workout data exceeds 1 GB, the application should display a non-blocking informational banner:

Workout history is using over 1 GB of local storage. Consider deleting older workout history if you no longer need it.

The banner should:

Appear only once per app launch until dismissed.
Never block importing new workouts.
Include a Manage Storage action that navigates to History for future cleanup functionality.

Note: Reaching 1 GB with text-only workout data is extremely unlikely. This requirement mainly becomes relevant if future versions add cached videos, images, or attachments. For the MVP, it's best to implement the storage usage calculation but expect the warning to almost never appear.




