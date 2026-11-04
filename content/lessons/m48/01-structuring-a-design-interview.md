---
id: m48-l01
title: Structuring a mobile design interview
description: "A mobile system design interview gives you a vague prompt and 45 minutes. You learn a structure for that time (requirements, scope, a high-level diagram, one or two deep dives, trade-offs), how to separate functional from non-functional requirements and turn each into a design decision, and how to make the estimates a client design actually needs (data per session, disk budget, decoded image memory) from assumptions you say out loud. The estimates are plain Swift, compiled and run."
module: m48
order: 1
level: advanced
minutes: 55
codeStatus: tested
swiftVersion: "6.4"
prerequisites: [m47-l06, m46-l06, m37-l06, m43-l01]
objectives:
  - Split 45 minutes into requirements, scope, high-level design, deep dives and trade-offs, and say what each phase leaves on the board.
  - Separate functional from non-functional requirements and connect each non-functional one to a concrete design decision.
  - Write down scope explicitly, including what is out of scope and why.
  - Produce back-of-the-envelope estimates for data per session, disk budget, decoded image memory and request rate, from stated assumptions.
  - Recognize the habits that sink a design interview (designing the backend, naming libraries instead of responsibilities, silent drawing).
terms:
  - term: Functional requirement
    definition: Something the app must let a person do, such as "save a recipe" or "check items off a shopping list". It names a feature and its behavior.
  - term: Non-functional requirement
    definition: "A quality the app must have while doing those things: works offline, launches fast, keeps data private, is usable with VoiceOver, stays within a memory budget. These drive most of the client architecture."
  - term: Scope
    definition: The subset of the product you'll design in the time you have, written down along with what you're leaving out.
  - term: Back-of-the-envelope estimate
    definition: A rough calculation from stated assumptions (sizes, counts, rates) whose purpose is to find the order of magnitude and the dominant cost, not a precise number.
  - term: Deep dive
    definition: A focused part of the interview where you design one hard component in detail (sync, image caching, an upload queue), usually chosen with the interviewer.
mastery:
  - Run the five phases on an unseen prompt and keep each within its time box.
  - Turn a vague prompt into a written list of three to five functional and three to five non-functional requirements.
  - State an estimate as assumptions first, then arithmetic, then the decision it changes.
  - Point to the dominant cost in an estimate and say what you'd do about it.
  - Name two trade-offs in your own design and what would make you choose differently.
resources: [hig, xcode-reduce-memory, xcode-memory-use, foundation-urlsession]
cards:
  - id: m48-l01-c1
    front: What are the five phases of a 45-minute mobile design interview, roughly timed?
    back: "Requirements (about 5–8 min), scope and assumptions (2–3), high-level design: API, models, components and one traced data flow (10–12), one or two deep dives (12–15), trade-offs, failure modes and wrap-up (5–8)."
  - id: m48-l01-c2
    front: Functional vs non-functional requirement?
    back: "Functional: what a person can do (save a recipe). Non-functional: qualities while doing it (offline, fast launch, privacy, accessibility, memory). The non-functional list drives most of the client architecture."
  - id: m48-l01-c3
    front: How should you state an estimate in a design interview?
    back: "Assumptions first, out loud and written down; then the arithmetic in round numbers; then the decision it changes (\"so the disk cache needs a byte budget and eviction\"). The interviewer can correct an assumption without restarting the math."
  - id: m48-l01-c4
    front: How much memory does a decoded bitmap take?
    back: "About width × height × 4 bytes for 8-bit RGBA, regardless of the file's compressed size. A 1,200 × 900 pixel image is about 4.3 MB decoded even if the JPEG is 200 KB."
  - id: m48-l01-c5
    front: Why name responsibilities instead of libraries in a design answer?
    back: "\"A client that retries idempotent requests with backoff\" shows you understand the design; a library name doesn't, and the interviewer will ask what it does anyway."
---

## The idea in one sentence

**A design interview is scored on the decisions you make out loud and the trade-offs you name**, so you need a structure that gets you to decisions quickly, leaves time for the hard part, and keeps the interviewer able to steer.

> [!note] What this module is and isn't
> Formats differ between companies, and nothing here describes any particular company's interview. The structure, time boxes and estimates are this course's recommendation. The client techniques they lean on come from earlier modules: networking and pagination (30), persistence and sync (31, 37), architecture (32), scrolling and images (27), telemetry (41), security (42) and performance and accessibility (43). The interview bank's `system-design` questions are practice prompts for this module; the designs in these lessons are new ones, so you can practice on those afterwards without having read their answers.

## The prompt is vague on purpose

A typical prompt is one sentence: "Design a recipe app." It leaves out who uses it, what they do, whether it works offline, how many recipes there are, and what matters most. That's the test. A candidate who starts drawing boxes has designed an app nobody asked for. A candidate who spends twenty minutes on questions has no time to design anything.

The whole module uses one running prompt so each lesson can build on the previous one:

> Design **Mise**, a recipe app. People browse a feed of recipes with photos, open a recipe, save it, and add its ingredients to a shopping list that the people in a household share.

## The 45 minutes

| Phase | Time | What you say and write | Left on the board |
| --- | --- | --- | --- |
| 1. Requirements | 5–8 min | Users, core actions, then qualities: offline, freshness, scale, sensitive data, accessibility, platform versions | Two lists: functional and non-functional |
| 2. Scope and assumptions | 2–3 min | What you'll design, what you won't, the numbers you assume | A short "in / out / assume" list |
| 3. High-level design | 10–12 min | API endpoints and models, client components, one data flow traced end to end | A box diagram and 3–5 endpoints |
| 4. Deep dives | 12–15 min | One or two hard parts in detail, picked with the interviewer | A focused diagram or state machine |
| 5. Trade-offs and wrap-up | 5–8 min | Failure modes, observability, testing, what you'd change with different requirements | A list of trade-offs |

Two habits make the table work:

- **Say which phase you're in.** "I have enough requirements; let me scope it." The interviewer learns where you are and can redirect you before you spend ten minutes on the wrong thing.
- **Check in at the boundaries.** "Before I go deeper, is there a part you'd like me to focus on?" Interviewers often have a deep dive in mind. If they don't, pick the part where your requirements make the design hardest.

### Phase 1: requirements

Start with people and actions: who opens the app, and what are the three or four things they do most? Then go through the qualities. A short checklist keeps you from forgetting one:

- **Offline:** which actions must work without a network, and which may show stale data?
- **Freshness:** how stale is acceptable? Seconds (chat), minutes (a feed), days (a recipe)?
- **Scale on the device:** items per screen, items stored, media sizes. Server scale matters only where it changes the client.
- **Sensitive data:** accounts, payments, health, location, anything that needs protection or that you shouldn't collect at all.
- **Accessibility and localization:** Dynamic Type, VoiceOver, right-to-left languages.
- **Platform:** minimum iOS version, iPad, widgets, watch.

For Mise, after a few questions, the lists look like this:

| Functional | Non-functional |
| --- | --- |
| Browse a feed of recipes with photos, newest first | Feed shows something within a second of launch, even offline |
| Open a recipe and read it while cooking | Saved recipes and the shopping list work fully offline |
| Save a recipe | The shopping list syncs across a household's devices within about a minute when online |
| Add ingredients to a shared shopping list, check items off | Usable with VoiceOver and the largest text sizes |
| | Stays within a sensible memory budget while scrolling photos |
| | No personal data beyond the account email; no location |

**Each non-functional requirement should point at a decision.** "Works offline" means a local store that the UI reads from. "Syncs within a minute" means some kind of change feed, not a full download. "Usable with VoiceOver" means the API has to carry alt text for photos. If a quality on your list changes nothing in your design, either you haven't designed for it yet or it doesn't belong on the list.

### Phase 2: scope and assumptions

Write three short lists:

- **In:** feed, recipe detail, save, shared shopping list.
- **Out:** authoring recipes, comments, search, payments, the recommendation algorithm, server internals.
- **Assume:** the numbers you'll use for estimates (next section).

Saying what's out is as useful as saying what's in. It shows you can prioritize, and it gives the interviewer a chance to say "actually, I'd like to see search."

### Phase 3: high-level design

Three things, in this order:

1. **The API the client needs.** Endpoints, the main models, pagination. Lesson 2 covers this.
2. **Components.** Responsibilities, not class names or libraries.
3. **One data flow traced end to end.** "Launch: read the local store, render, request page one, merge, render again."

A first diagram for Mise, in the form you'd draw on a whiteboard:

```text
┌────────────────────── iOS app ───────────────────────┐
│  Feed ─┐   Recipe ─┐   Shopping list ─┐               │
│  screen│   screen  │   screen         │   (SwiftUI)   │
│        ▼           ▼                  ▼               │
│   FeedModel   RecipeModel      ListModel              │
│        │           │                  │               │
│        ▼           ▼                  ▼               │
│  RecipeRepository           ShoppingListRepository    │
│     │        │                   │          │         │
│     ▼        ▼                   ▼          ▼         │
│  Local   API client ◄── Sync engine ── Outbox         │
│  store       │                                        │
│  Image pipeline (memory + disk cache)                 │
└──────────────┼────────────────────────────────────────┘
               ▼
        HTTPS API · push (APNs)
```

### Phase 4: deep dives

Pick the parts where your requirements bite. For Mise, the shared shopping list (offline edits from two phones, conflicts) and the photo feed (memory, disk cache, prefetching) are the interesting ones. Lessons 3 and 4 are those deep dives. Go into data structures, state machines, retry policies and edge cases: this is where most of the signal is.

### Phase 5: trade-offs and wrap-up

Name the choices you made and when you'd choose differently. "I used last-writer-wins per field on list items because two people rarely edit the same item's quantity; for a document editor I'd need something else." Then failure modes (no network, app killed mid-sync, server down), what you'd measure, and how you'd test it. Lesson 5 covers the observability and privacy parts.

## Estimates with stated assumptions

Estimates in a mobile interview are about the device: how much data a session moves, how much disk the offline mode needs, how much memory decoded images take. Server-side numbers come up only when they change the client (request rate drives how aggressively you batch or cache).

**The format matters more than the numbers.** Assumptions first, written down; then round arithmetic; then the decision. If the interviewer says "recipes have ten photos, not one", you change one line and redo the math.

Here's Mise's estimate as code, so each number traces back to an assumption. Units are decimal (1 KB = 1,000 bytes, 1 MB = 1,000,000 bytes) because that's what you'd use on a whiteboard, and the arithmetic is integer-only so the output is the same on every machine.

```swift
/// Formats bytes as MB with one decimal, using integer math only.
func megabytes(_ bytes: Int) -> String {
    let tenths = (bytes + 50_000) / 100_000          // round to the nearest 0.1 MB
    return "\(tenths / 10).\(tenths % 10) MB"
}

struct Assumptions {
    // Feed
    let recipesPerPage = 20
    let pagesPerSession = 5
    let jsonBytesPerRecipe = 1_500
    let thumbnailBytes = 60_000              // JPEG, 600 × 450 pixels
    // Offline
    let savedRecipes = 200
    let fullPhotoBytes = 250_000             // JPEG, 1,200 × 900 pixels
    let recipeDetailBytes = 8_000            // steps and ingredients as JSON
    // Screen
    let thumbnailWidthPixels = 1_074         // 358 points × 3
    let thumbnailHeightPixels = 804          // 268 points × 3
    let thumbnailsOnScreen = 3
    // Server side, only to size request rates
    let dailyActiveUsers = 500_000
    let sessionsPerUserPerDay = 3
    let requestsPerSession = 8
    let peakToAverage = 3
}

let a = Assumptions()

let recipesPerSession = a.recipesPerPage * a.pagesPerSession
let feedJSON = recipesPerSession * a.jsonBytesPerRecipe
let feedImages = recipesPerSession * a.thumbnailBytes
print("Per session: \(recipesPerSession) recipes, JSON \(megabytes(feedJSON)), images \(megabytes(feedImages))")

let offline = a.savedRecipes * (a.fullPhotoBytes + a.recipeDetailBytes)
print("Offline saved recipes: \(megabytes(offline))")

let decodedThumbnail = a.thumbnailWidthPixels * a.thumbnailHeightPixels * 4
print("One decoded thumbnail: \(megabytes(decodedThumbnail)); on screen: \(megabytes(decodedThumbnail * a.thumbnailsOnScreen))")

let requestsPerDay = a.dailyActiveUsers * a.sessionsPerUserPerDay * a.requestsPerSession
let averagePerSecond = requestsPerDay / 86_400
print("Requests: \(requestsPerDay) per day, about \(averagePerSecond)/s average, \(averagePerSecond * a.peakToAverage)/s at peak")
```

```output
Per session: 100 recipes, JSON 0.2 MB, images 6.0 MB
Offline saved recipes: 51.6 MB
One decoded thumbnail: 3.5 MB; on screen: 10.4 MB
Requests: 12000000 per day, about 138/s average, 414/s at peak
```

What each line tells you, said as the decision it drives:

- **Images dominate the network**: 6 MB of photos against 0.2 MB of JSON. So the design effort goes into the image pipeline (sizes per screen, caching, Low Data Mode), not into shaving JSON.
- **Offline needs about 50 MB of disk** for 200 saved recipes, nearly all photos. That's acceptable, but it means saved photos live in a store with a budget, separate from the evictable feed cache, and the app should show how much space it uses.
- **Decoded images are big.** A 60 KB JPEG becomes 3.5 MB of pixels at display size. Three on screen plus a few prefetched rows is tens of megabytes, which is why the memory cache needs a cost limit and why you decode at display size, never at full resolution (Module 27).
- **138 requests a second on average** doesn't change the client much. It does justify caching feed pages on the device and avoiding a request per row, and it's the number to hand the backend team.

> [!tip] Round aggressively, then say so
> On a whiteboard, 86,400 seconds is "about 100,000", and 12 million a day is "about 120 a second". The interviewer wants the order of magnitude and the dominant cost. Say "roughly" and move on.

## Habits that sink a design interview

- **Designing the backend.** Sharding, load balancers and database choice rarely matter in a mobile interview unless the interviewer asks. The client depends on the API contract, push payloads, pagination and idempotency; design those.
- **Library names instead of responsibilities.** "I'd use a library for images" says nothing. "A pipeline with a memory cache keyed by URL and size, a disk cache with a byte budget, and request coalescing" does.
- **Silent drawing.** Talk while you draw. A diagram without narration gives the interviewer nothing to react to.
- **One right answer.** Most choices have a cost. Saying what you gave up is the point.
- **No numbers.** "It might use a lot of memory" invites "how much?" Have the decoded-bitmap formula ready.

## Common mistakes

> [!error] Jumping to the diagram
> Without requirements, every box is a guess. Spend the first five minutes on users, actions and qualities, and write them down where you both can see them.

> [!error] Listing non-functional requirements that change nothing
> "It should be fast and secure" isn't a requirement. "The feed shows cached content within a second of launch, offline" is, and it implies a local store that the UI reads first.

> [!error] Estimating without stating assumptions
> A number with no visible assumptions can't be corrected, only argued with. Write the assumptions as a list before you multiply.

> [!error] Using the compressed file size for memory
> A 60 KB JPEG doesn't take 60 KB in memory once decoded. Use width × height × 4 bytes at the size you'll display it.

> [!error] Spending the deep dive on the easy part
> A detailed login screen earns little. Go where the requirements make the design hard: offline edits, conflicts, large media, real time.

## Exercises

````exercise
id: m48-l01-e1
type: comprehension
multiple: true
prompt: "The prompt is \"Design a habit tracker.\" Which of these are non-functional requirements?"
choices:
  - text: "Checking off today's habit works without a network and syncs later."
    correct: true
    why: "It's about a quality (offline behavior) of an action, not a new action."
  - text: "A person can create a habit with a name and a daily or weekly schedule."
    correct: false
    why: "That's an action the app must support: functional."
  - text: "Streak data never leaves the device without an account."
    correct: true
    why: "A privacy constraint: a quality, and it shapes where data lives."
  - text: "The home screen is fully usable with VoiceOver and the largest accessibility text size."
    correct: true
    why: "Accessibility is a quality of every screen, and it's a requirement, not a polish item."
  - text: "A person can see a weekly chart of completed habits."
    correct: false
    why: "A feature: functional."
solution: |
  Non-functional: offline check-off, data staying on the device without an account, and accessibility. Each one changes the design: a local store with an outbox, a decision about what is uploaded and when, and layouts that reflow at large text sizes with labels for every control. The two features (create a habit, see a weekly chart) are functional.
````

````exercise
id: m48-l01-e2
type: prediction
prompt: "The interviewer changes two assumptions: recipes now have 3 thumbnails each in the feed, and people scroll 8 pages per session. Same helper. What does it print?"
code: |
  func megabytes(_ bytes: Int) -> String {
      let tenths = (bytes + 50_000) / 100_000
      return "\(tenths / 10).\(tenths % 10) MB"
  }

  let recipesPerPage = 20
  let pagesPerSession = 8
  let thumbnailsPerRecipe = 3
  let thumbnailBytes = 60_000
  let jsonBytesPerRecipe = 1_500

  let recipes = recipesPerPage * pagesPerSession
  print("Recipes: \(recipes)")
  print("JSON: \(megabytes(recipes * jsonBytesPerRecipe))")
  print("Images: \(megabytes(recipes * thumbnailsPerRecipe * thumbnailBytes))")
output: |
  Recipes: 160
  JSON: 0.2 MB
  Images: 28.8 MB
hints:
  - "160 × 1,500 = 240,000 bytes. Add 50,000 and divide by 100,000, discarding the remainder."
  - "160 × 3 × 60,000 = 28,800,000 bytes."
solution: |
  ```output
  Recipes: 160
  JSON: 0.2 MB
  Images: 28.8 MB
  ```

  20 × 8 = 160 recipes. JSON is 240,000 bytes; (240,000 + 50,000) / 100,000 = 2 tenths, printed as `0.2 MB`. Images are 160 × 3 × 60,000 = 28,800,000 bytes, 288 tenths, `28.8 MB`.

  The decision it changes: nearly 30 MB per session is a lot on cellular. You'd load only the first thumbnail of each recipe in the feed, fetch the others when a person swipes the carousel, and send smaller images under Low Data Mode (Module 43).
````

````exercise
id: m48-l01-e3
type: solve
prompt: |
  Write `offlineBudget(savedItems:photoBytes:photosPerItem:textBytes:limitBytes:)` that returns a one-line verdict for an offline feature. Compute the total bytes as `savedItems × (photoBytes × photosPerItem + textBytes)`. If the total fits within the limit, return `"fits: N MB of L MB"`; otherwise return `"over: N MB of L MB, keep at most K items"`, where K is the largest item count that fits. Use the `megabytes` helper from the lesson for N and L.

  Expected output:

  ```output
  fits: 51.6 MB of 100.0 MB
  over: 154.8 MB of 100.0 MB, keep at most 129 items
  over: 2.0 MB of 1.0 MB, keep at most 0 items
  ```
starter: |
  func megabytes(_ bytes: Int) -> String {
      let tenths = (bytes + 50_000) / 100_000
      return "\(tenths / 10).\(tenths % 10) MB"
  }

  func offlineBudget(savedItems: Int, photoBytes: Int, photosPerItem: Int, textBytes: Int, limitBytes: Int) -> String {
      // your code
      return ""
  }

  print(offlineBudget(savedItems: 200, photoBytes: 250_000, photosPerItem: 1, textBytes: 8_000, limitBytes: 100_000_000))
  print(offlineBudget(savedItems: 200, photoBytes: 250_000, photosPerItem: 3, textBytes: 24_000, limitBytes: 100_000_000))
  print(offlineBudget(savedItems: 1, photoBytes: 2_000_000, photosPerItem: 1, textBytes: 0, limitBytes: 1_000_000))
hints:
  - "Compute the bytes for one item first; the total is that times the count."
  - "The largest count that fits is the integer division limit / perItem."
rubric:
  - Computes bytes per item and the total from the stated formula.
  - Returns the "fits" form when total ≤ limit.
  - Computes the largest item count with integer division, including 0 when one item doesn't fit.
solution: |
  ```swift
  func megabytes(_ bytes: Int) -> String {
      let tenths = (bytes + 50_000) / 100_000
      return "\(tenths / 10).\(tenths % 10) MB"
  }

  func offlineBudget(savedItems: Int, photoBytes: Int, photosPerItem: Int, textBytes: Int, limitBytes: Int) -> String {
      let perItem = photoBytes * photosPerItem + textBytes
      let total = savedItems * perItem
      if total <= limitBytes {
          return "fits: \(megabytes(total)) of \(megabytes(limitBytes))"
      }
      let maximum = limitBytes / perItem
      return "over: \(megabytes(total)) of \(megabytes(limitBytes)), keep at most \(maximum) items"
  }

  print(offlineBudget(savedItems: 200, photoBytes: 250_000, photosPerItem: 1, textBytes: 8_000, limitBytes: 100_000_000))
  print(offlineBudget(savedItems: 200, photoBytes: 250_000, photosPerItem: 3, textBytes: 24_000, limitBytes: 100_000_000))
  print(offlineBudget(savedItems: 1, photoBytes: 2_000_000, photosPerItem: 1, textBytes: 0, limitBytes: 1_000_000))
  ```

  ```output
  fits: 51.6 MB of 100.0 MB
  over: 154.8 MB of 100.0 MB, keep at most 129 items
  over: 2.0 MB of 1.0 MB, keep at most 0 items
  ```

  Per item is 258,000 bytes in the first case and 774,000 in the second; 100,000,000 / 774,000 is 129 with integer division. The last case shows the edge: when a single item is larger than the budget, the answer is 0, and the design has to change (smaller photos offline), not the limit. In an interview, the "keep at most" number is what turns into a product rule: "offline keeps your 120 most recently saved recipes."
````

````exercise
id: m48-l01-e4
type: find-errors
prompt: "A candidate's plan for \"Design a podcast app\" in 45 minutes. Mark every real problem."
code: |
  0–2   "I'll start with the architecture: MVVM with Combine and Alamofire."
  2–20  Draws the backend: CDN, Kafka topics, a sharded Postgres cluster for episodes.
  20–30 Lists requirements: play episodes, subscribe, download, "should be fast and secure".
  30–43 Designs the login screen in detail.
  43–45 "I think that covers it."
choices:
  - text: "Architecture and libraries come before any requirements, so nothing justifies them."
    correct: true
  - text: "Eighteen minutes on server infrastructure the client doesn't depend on."
    correct: true
  - text: "\"Fast and secure\" are not requirements that drive a decision."
    correct: true
  - text: "The deep dive is on the least interesting part; offline downloads and playback state are where the design is hard."
    correct: true
  - text: "No trade-offs, failure modes or measurement at the end."
    correct: true
  - text: "Mentioning MVVM at all is a mistake in a system design interview."
    correct: false
    why: "Naming a presentation pattern is fine once it's justified by requirements; the problem here is the order and the library names."
rubric:
  - I flagged starting from architecture and libraries.
  - I flagged the backend time.
  - I flagged the vague non-functional requirements.
  - I flagged the deep dive choice.
  - I flagged the missing wrap-up.
solution: |
  Everything except the MVVM point is a real problem.

  - **Order.** Requirements come first; MVVM and library names before them are unjustified. Replace "Alamofire" with the responsibility: "a client that resumes downloads and retries idempotent requests."
  - **Backend.** The client depends on the feed of episodes, the download URLs and how progress syncs. CDN internals and database sharding don't change the app.
  - **Vague qualities.** Rewrite as "playback starts within a second for downloaded episodes", "downloads continue in the background and survive the app being terminated", "playback position syncs across devices."
  - **Deep dive.** Background downloads with a byte budget, and syncing playback position with conflicts between two devices, are the hard parts.
  - **No wrap-up.** Two minutes on trade-offs and failure modes is cheap and is where you show judgment.
````

````exercise
id: m48-l01-e5
type: explain
prompt: "An interviewer says: \"Don't worry about numbers, just design it.\" The candidate has already written the note below on the board. Explain why you might still do one quick estimate, which one you'd pick for a photo-heavy app, and how you'd keep it to a minute."
code: |
  Assume: cell image 358 × 268 pt at 3x; ~10 images decoded (screen + prefetch)
  Math:   1,074 × 804 × 4 bytes ≈ 3.5 MB each → ~35 MB
  So:     memory cache capped by cost; downsample to display size
rubric:
  - Says an estimate is worth doing when it changes a decision, and only then.
  - Picks decoded image memory or data per session for a photo-heavy app.
  - Describes stating assumptions, rounding, and naming the decision it drives.
  - Respects the interviewer's steer by keeping it short.
solution: |
  Do one estimate only if it changes the design, and say why in one sentence. For a photo-heavy app, decoded image memory is the one that matters: "Each cell's image is about 1,000 × 800 pixels at 3x, so about 3.5 MB decoded; with a screen and a half of prefetch, say 10 images, that's 35 MB. So I'll cap the memory cache by cost and downsample to display size." That's the note on the board: assumption, arithmetic, decision, about a minute to say. If the interviewer still wants to move on, move on; you've shown the habit without spending their time.
````

````exercise
id: m48-l01-e6
type: design
prompt: "Run phases 1 and 2 for \"Design a parking app: find a spot near you, pay for a session, extend it before it expires.\" Write the functional and non-functional lists, the in/out/assume lists, and say which two parts you'd propose as deep dives."
rubric:
  - Functional list covers finding, paying, extending and seeing the active session.
  - Non-functional list includes reliability of payment (idempotency), reminders before expiry, location privacy, offline or poor-signal behavior, and accessibility.
  - Scope says explicitly what's out (for example, the payment processor's internals, enforcement).
  - Assumptions are concrete numbers or facts the design will use.
  - Deep dives are the hard parts, for example paying exactly once on a poor connection and expiry reminders that work when the app isn't running.
solution: |
  **Functional:** see nearby zones on a map with rates; start a session for a zone and a vehicle; see the active session with time remaining; extend it; see past sessions and receipts.

  **Non-functional:** a session is charged exactly once even on a bad garage connection; a reminder arrives before expiry even when the app isn't running; location is used only while finding a zone, and precise location isn't stored; the active session is visible offline; everything works with VoiceOver and large text; payment details are never stored on the device beyond what the payment SDK manages.

  **In:** zone lookup, start and extend, the active session, reminders. **Out:** the payment processor, enforcement officers' tools, the map rendering itself. **Assume:** sessions last 1–4 hours; a person has one active session at a time; the server owns the session's end time.

  **Deep dives:** (1) starting and extending as idempotent operations with a client-generated session ID, retried safely after a timeout (Module 43's QA1941 guidance), and (2) reminders: a local notification scheduled from the server's end time when the session starts, rescheduled on extend, with a push as a backup. Those are where the requirements make the design hard.
````

## Summary

- Run five phases in 45 minutes: requirements, scope and assumptions, a high-level design with one traced data flow, one or two deep dives, then trade-offs and failure modes. Say which phase you're in and check in at the boundaries.
- Functional requirements are actions; non-functional ones are qualities. Each non-functional requirement should point at a design decision, or it isn't doing any work.
- Write down what's in, what's out and what you assume.
- Estimates state assumptions first, use round numbers, and end with the decision they drive. On mobile, the useful ones are data per session, disk for offline, and decoded image memory (width × height × 4 bytes).
- Design the client and the contract it depends on, name responsibilities rather than libraries, and spend the deep dive where the design is hard.
