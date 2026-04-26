# ChessCoach — macOS App Spec & Agent Handoff Document

> **Purpose:** This document is the complete source of truth for building the ChessCoach macOS app.
> It is written for a Claude Code agent and should be read in full before writing any code.
> All architectural decisions are finalised here. Do not deviate without flagging a conflict.

---

## 1. Product Overview

**ChessCoach** is a native macOS chess app where the user plays against a CPU opponent (Stockfish)
and receives real-time, Socratic coaching from a local LLM. The coach never tells the user what
move to make — it helps them understand *why* a position is good or bad, and guides them to
discover better moves themselves through questions and concept explanations.

### Core principles
- **Fully local.** No internet required after first-launch model download. No API keys. No accounts.
- **Reactive coaching.** The coach speaks when something meaningful happens — a blunder, a missed
  tactic, a good sacrifice — not on every move.
- **Explanatory, not prescriptive.** The coach gently explains *why* a move was an error
  and what concept it violated — without telling the player what move they should have made.
  It never asks open-ended rhetorical questions. The player cannot respond, so every coach
  message should be self-contained and genuinely informative.
- **All skill levels.** Both the CPU difficulty and coaching depth adapt to the user's apparent level.
- **Distribution:** targeting both Mac App Store and direct download (.dmg). Architecture must
  support both (no hardcoded paths, proper sandboxing considered from the start).

---

## 2. Tech Stack

| Component | Technology | Notes |
|---|---|---|
| UI framework | SwiftUI (macOS 14+) | No AppKit fallbacks needed |
| Chess board | ChessboardKit 1.1.2 | SPM package |
| Chess rules engine | ChessKit (auto-included by ChessboardKit) | Move validation, FEN, PGN |
| CPU opponent + evaluator | Stockfish 17 | Bundled binary in app bundle |
| LLM inference | llama.cpp via swift-llama or LLM.swift SPM package | In-process, Metal GPU |
| Model format | GGUF (quantized) | Downloaded on first launch |
| Persistence | SwiftData | Game history, player profile, settings |
| Minimum deployment | macOS 26 Tahoe | Required for Liquid Glass APIs (Xcode 26+) |

### Swift Package Dependencies
```
https://github.com/rohanrhu/ChessboardKit — from: "1.1.2"
https://github.com/eastriverlee/LLM.swift — (llama.cpp Swift wrapper)
```

Stockfish is **not** an SPM package — it is a compiled universal binary (arm64 + x86_64)
placed at `ChessCoach/Resources/Engines/stockfish`. It communicates via stdin/stdout (UCI protocol).

---

## 3. Project Structure

```
ChessCoach/
├── ChessCoachApp.swift                  # App entry point, lifecycle
├── Resources/
│   ├── Engines/
│   │   └── stockfish                   # Universal binary, chmod +x at build time
│   └── Assets.xcassets/
├── Models/                             # SwiftData models + value types
│   ├── GameRecord.swift                # Persisted game history
│   ├── PlayerProfile.swift            # Rolling skill profile
│   └── CoachMessage.swift             # Value type for chat bubble data
├── Managers/                           # Stateful service singletons
│   ├── StockfishManager.swift          # UCI subprocess wrapper
│   ├── LLMManager.swift                # llama.cpp inference + streaming
│   ├── CoachingEngine.swift            # Eval delta logic, trigger decisions
│   └── ModelDownloadManager.swift      # First-launch GGUF download
├── ViewModels/
│   ├── GameViewModel.swift             # Central game state, owns all managers
│   └── SetupViewModel.swift           # First-launch onboarding flow
├── Views/
│   ├── RootView.swift                  # Top-level navigation
│   ├── Game/
│   │   ├── GameView.swift              # Main game screen layout (sidebar + board)
│   │   ├── BoardContainerView.swift    # ChessboardKit wrapper
│   │   ├── CoachPanelView.swift        # Sidebar shell + ScrollView
│   │   ├── CoachMessageView.swift      # Single chat bubble with header + badge
│   │   └── GameControlsView.swift     # Toolbar: New Game, colour, difficulty
│   ├── Setup/
│   │   ├── WelcomeView.swift           # First launch welcome
│   │   ├── ModelPickerView.swift       # RAM detection + model recommendation
│   │   └── ModelDownloadView.swift     # Download progress UI
│   └── Settings/
│       └── SettingsView.swift          # Difficulty, coaching prefs, model swap
└── Utilities/
    ├── FENUtilities.swift              # FEN helpers beyond ChessKit
    └── Extensions.swift               # Swift extensions
```

---

## 4. First-Launch Onboarding Flow

This is the most critical UX moment. The app must feel effortless.

### Steps
1. **Welcome screen** — brief explanation of what the app is. Single CTA: "Get Started."
2. **Model picker** — detect RAM via `ProcessInfo.processInfo.physicalMemory`:
   - `< 12 GB` → recommend **Llama 3.2 3B Q4** (~2.0 GB download)
   - `≥ 12 GB` → recommend **Qwen2.5 7B Q4** (~4.7 GB download)
   - Always show both options with clear size and quality labels. Let the user override.
3. **Download screen** — URLSession download with:
   - Animated progress bar
   - Download speed + estimated time remaining
   - Pause/resume support
   - Save to `~/Library/Application Support/ChessCoach/models/<filename>.gguf`
4. **Done** — transition directly into the game view. No relaunch required.

### Model download URLs
```
Llama 3.2 3B Q4:  https://huggingface.co/bartowski/Llama-3.2-3B-Instruct-GGUF/resolve/main/Llama-3.2-3B-Instruct-Q4_K_M.gguf
Qwen2.5 7B Q4:    https://huggingface.co/bartowski/Qwen2.5-7B-Instruct-GGUF/resolve/main/Qwen2.5-7B-Instruct-Q4_K_M.gguf
```

On subsequent launches: check if file exists at expected path → load directly, skip onboarding.

---

## 5. Game Flow (Happy Path)

```
1. User opens app → GameView appears
2. User selects difficulty (1–10 slider) and colour (white/black)
3. "New Game" → ChessboardKit initialised with starting FEN
4. StockfishManager.newGame() called — sends "ucinewgame" to Stockfish process

--- PLAYER TURN ---
5. Player drags/clicks a piece
6. ChessboardKit.onMove fires with (move, isLegal, from, to, lan, promotionPiece)
7. If !isLegal → ignore (ChessboardKit handles visual reset)
8. ChessKit: chessboardModel.game.make(move: move)
9. New FEN serialized via FenSerialization
10. chessboardModel.setFen(newFEN, lan: lan) with withAnimation
11. CoachingEngine.evaluateMove(before: prevFEN, after: newFEN, lan: lan)
    → sends "position fen <FEN>\ngo depth 18" to Stockfish (eval-only mode)
    → reads "score cp N" from output
    → computes delta = abs(scoreBefore - scoreAfter)
    → if delta >= threshold → trigger LLM coaching (async, non-blocking)

--- CPU TURN ---
12. StockfishManager.requestMove(fen: newFEN, difficulty: currentDifficulty)
    → sends UCI commands (see §7) to Stockfish (opponent mode)
    → reads "bestmove <lan>" from output
    → returns LAN string (e.g. "e2e4")
13. ChessKit: resolve LAN to Move object, game.make(move:)
14. chessboardModel.setFen(cpuFEN, lan: cpuLAN) with withAnimation
15. Back to step 5

--- COACHING (runs in parallel with CPU turn) ---
16. CoachingEngine also evaluates the CPU's move (before: playerFEN, after: cpuFEN)
    → same centipawn delta logic applies
    → if the CPU played a strong move the player may have missed, coach may note it
    → if the CPU played a surprising or instructive move, coach explains it
17. LLMManager.stream(prompt: coachingPrompt) → AsyncStream<String>
18. A new CoachMessage is appended to the chat history with .thinking state
19. Tokens stream in, updating the message in place
20. CoachPanelView auto-scrolls to the latest message
```

### Coaching trigger summary
Coaching is evaluated after **every move** — both player and CPU — using the same
centipawn delta thresholds. This means:
- Player blunders → coach gently asks what they were thinking about
- CPU plays a strong or surprising move → coach highlights why it was effective
- Good moves by either side → no comment (unless "verbose" mode is on)
- CPU moves are evaluated for instructional value, not just error detection

---

## 6. StockfishManager

`StockfishManager` is an `actor` (Swift concurrency) wrapping a single `Process` instance.
Stockfish runs as a persistent subprocess for the lifetime of the app — do not restart it per move.

### Initialisation
```swift
// On app launch:
let stockfishURL = Bundle.main.url(forResource: "stockfish", withExtension: nil, subdirectory: "Engines")!
// Launch process, open pipes, send "uci", wait for "uciok"
```

### UCI command sequence — new game
```
ucinewgame
isready        → wait for "readyok"
```

### UCI command sequence — CPU move (opponent mode)
```
position fen <FEN>
setoption name Skill Level value <N>       ← from difficulty mapping
go movetime <ms>                           ← from difficulty mapping
```
Read stdout until line starts with `bestmove`, extract the move token.

### UCI command sequence — position evaluation (coach mode)
```
position fen <FEN>
go depth 18
```
Read stdout until line starts with `info depth 18`, extract `score cp <N>`.
Note: if `score` contains `mate`, treat as ±10000cp.

### Difficulty mapping (1–10 slider → UCI params)

| Slider | Skill Level | movetime (ms) | Notes |
|--------|-------------|---------------|-------|
| 1 | 0 | 100 | Makes intentional blunders |
| 2 | 2 | 150 | |
| 3 | 4 | 200 | |
| 4 | 6 | 300 | |
| 5 | 8 | 500 | Casual club player |
| 6 | 11 | 800 | |
| 7 | 14 | 1200 | |
| 8 | 16 | 2000 | Strong amateur |
| 9 | 18 | 3000 | |
| 10 | 20 | 5000 | Near-maximum strength |

### Thread safety
`StockfishManager` is a Swift `actor`. All UCI I/O happens on its isolated executor.
Callers use `await stockfish.requestMove(...)` and `await stockfish.evaluate(...)`.
The two modes (opponent + eval) are **sequential within the actor** — eval completes
before opponent move is requested, so there is no pipe contention.

---

## 7. CoachingEngine

`CoachingEngine` decides *when* to coach and *what context* to pass to the LLM.

### Trigger thresholds (centipawn delta)

| Classification | Delta | Behaviour |
|---|---|---|
| Brilliant / best | delta < -50 (player gained) | Optional: brief positive note |
| Inaccuracy | 50–99 | Coach triggers — mild |
| Mistake | 100–199 | Coach triggers — moderate |
| Blunder | 200+ | Coach triggers — full coaching response |
| Good move | < 50 swing | No coaching |

Thresholds should be stored as user-adjustable constants (for verbosity setting):
- **Quiet mode:** only blunders (200+)
- **Normal mode:** mistakes + blunders (100+) ← default
- **Verbose mode:** all of the above (50+)

### Skill adaptation
`PlayerProfile` maintains a rolling average of centipawn loss per move (ACPL — Average
Centipawn Loss). This is updated after every game and stored via SwiftData.

ACPL brackets used to calibrate coaching language in the LLM prompt:
- ACPL 0–30: Strong player — use chess nomenclature freely
- ACPL 31–80: Intermediate — explain terms when used
- ACPL 81+: Beginner — plain language, fundamental concepts

---

## 8. LLMManager

`LLMManager` wraps the llama.cpp inference via the LLM.swift package.

### Model loading
```swift
// Loaded once on app start (after first-launch setup):
let modelPath = // ~/Library/Application Support/ChessCoach/models/<filename>.gguf
let llm = LLM(from: modelURL, template: .chatML)
```

### Coaching prompt structure

The prompt sent to the LLM on every coaching trigger:

```
SYSTEM:
You are a friendly, knowledgeable chess coach sitting beside the player as they play.
Your job is to help them understand what just happened and why — not to quiz them.

When the player makes an error:
- Gently and clearly name what went wrong (e.g. "that move leaves your king exposed on
  the back rank" or "moving that pawn let the knight into a strong outpost on d5")
- Briefly explain the chess concept it violated — king safety, piece activity, pawn
  structure, tactical patterns, etc.
- If helpful, note what to watch for going forward — but never say what specific move
  they should have played

When the CPU plays an instructive move:
- Point out what made it strong or effective
- Name the concept or pattern (fork, pin, outpost, tempo gain, etc.)
- Help the player recognise this pattern so they can use or counter it in future

Rules:
- Never ask rhetorical questions. The player cannot respond, so every message must be
  self-contained and genuinely informative on its own.
- Never reveal the specific best move Stockfish recommended.
- Never say "you should have played [move]" or reference specific square notation
  unless the player is at STRONG level.
- Be warm and encouraging in tone, never critical or discouraging.
- Keep responses concise: 2–4 sentences for simple errors, up to 6 for complex concepts.
- Adapt language to player level: <BEGINNER|INTERMEDIATE|STRONG>
  - BEGINNER: plain language, name pieces not squares, explain all terms used
  - INTERMEDIATE: standard chess vocabulary, light use of notation
  - STRONG: full chess terminology and notation freely used

USER:
Game so far (PGN): <PGN of moves played so far>
Current position (FEN): <current FEN>
Move made by: <"the player" or "the CPU opponent">
Move description: <descriptive terms, e.g. "the player moved the knight to the edge of the board">
Position evaluation before move: <e.g. "+0.3 (slight white advantage)">
Position evaluation after move: <e.g. "-1.4 (significant black advantage)">
Classification: <Blunder / Mistake / Inaccuracy / Instructive CPU move>
Stockfish best line (context only — do NOT reveal to the player): <best continuation>

Coach response:
```

When `Move made by` is "the CPU opponent", the coaching focus shifts:
the coach explains *why* the CPU move was strong or instructive, helping
the player recognise patterns they should watch for.

### Chat message model

Coaching output is represented as a list of messages, not a single string. This
maps directly to the chat UI and preserves the full coaching history for the session.

```swift
struct CoachMessage: Identifiable {
    let id: UUID
    let moveNumber: Int          // Which move triggered this (e.g. 12)
    let mover: String            // "You" or "CPU"
    let classification: String   // "Blunder", "Mistake", "Inaccuracy", "Good move"
    var text: String             // Streams in token by token
    var isStreaming: Bool        // true while LLM is generating
}
```

`GameViewModel` owns `@Published var coachMessages: [CoachMessage]`.

On each coaching trigger:
1. Append a new `CoachMessage` with `isStreaming: true` and empty `text`
2. Stream tokens — each token mutates the last message's `text` in place
3. On completion, set `isStreaming: false`

The `CoachPanelView` renders the full `coachMessages` array, so the user sees
the entire coaching conversation for the current game scrolled chronologically.

---

## 9. Data Models (SwiftData)

### GameRecord
```swift
@Model class GameRecord {
    var id: UUID
    var date: Date
    var pgn: String                  // Full PGN of the game
    var playerColour: String         // "white" or "black"
    var difficulty: Int              // 1–10
    var result: String               // "win", "loss", "draw"
    var acpl: Double                 // Average centipawn loss for this game
    var blunderCount: Int
    var mistakeCount: Int
}
```

### PlayerProfile
```swift
@Model class PlayerProfile {
    var rollingACPL: Double          // Exponential moving average across games
    var gamesPlayed: Int
    var skillBracket: String         // "beginner", "intermediate", "strong"
    var preferredDifficulty: Int     // Last used difficulty, restored on launch
    var coachingVerbosity: String    // "quiet", "normal", "verbose"
    var selectedModelFilename: String
}
```

---

## 10. UI Layout

### GameView — two-column layout (sidebar left, board right)
```
┌─────────────────────────────────────────────────────────────┐
│  toolbar: New Game · Colour picker · Difficulty · Settings   │
├───────────────────────┬─────────────────────────────────────┤
│                       │                                     │
│   CoachPanelView      │       BoardContainerView            │
│   (left sidebar)      │       (ChessboardKit)               │
│   min width: 260pt    │       Always square, fills height   │
│   max width: 320pt    │                                     │
│                       │                                     │
│   Chat-style list     │                                     │
│   of CoachMessages    │                                     │
│   scrolled to bottom  │                                     │
│                       │                                     │
└───────────────────────┴─────────────────────────────────────┘
```

- Left sidebar: `CoachPanelView`, fixed width range 260–320pt, not resizable by user
- Right: board, square aspect ratio, fills remaining space
- No text input field anywhere — the coach is read-only
- On narrow windows (< 700pt): sidebar collapses; board fills full width; coach
  messages accessible via a slide-in drawer toggled by a toolbar button

### CoachPanelView — chat message list

Styled after a modern chat app (Claude, ChatGPT). Each `CoachMessage` renders as
a distinct chat bubble with metadata above it.

```
┌─────────────────────────────┐
│  CoachPanelView             │
│  ─────────────────────────  │
│                             │
│  ┌───────────────────────┐  │
│  │ 🔵 Move 8 · You       │  │  ← move metadata header
│  │ Blunder               │  │  ← classification badge
│  │                       │  │
│  │ That move opened up   │  │  ← coach message bubble
│  │ your king quite a     │  │
│  │ bit. What were you    │  │
│  │ planning to do about  │  │
│  │ the bishop on b4?     │  │
│  └───────────────────────┘  │
│                             │
│  ┌───────────────────────┐  │
│  │ 🟡 Move 9 · CPU       │  │
│  │ Instructive           │  │
│  │                       │  │
│  │ Notice how the CPU    │  │
│  │ used that tempo to    │  │  ← streaming: cursor blinks
│  │ centralise its        │     at end while isStreaming
│  │ knight. Central       │
│  │ knights are often ... │  ← animated typing indicator
│  └───────────────────────┘
│                             │
└─────────────────────────────┘
```

### Message bubble anatomy
- **Header line:** small muted text — "Move 12 · You" or "Move 12 · CPU"
- **Classification badge:** colour-coded pill
  - Blunder → red
  - Mistake → orange
  - Inaccuracy → yellow
  - Instructive → blue
  - (No badge for silent/no-comment moves — those produce no message at all)
- **Bubble:** rounded rect, slightly inset from sidebar edges, coach-accent
  background colour (not the user's side — there is no user bubble, only coach bubbles)
- **Streaming cursor:** a blinking `|` appended to the text while `isStreaming == true`
- **Idle state:** when no messages yet, sidebar shows a centred placeholder:
  "Your coach is watching. I'll speak up when it matters."

### Coaching panel states
1. **Idle** — placeholder text centred in sidebar
2. **Thinking** — new bubble appears immediately with a 3-dot animated indicator
   before tokens begin streaming (covers LLM prompt construction latency)
3. **Streaming** — tokens appear in the bubble with blinking cursor
4. **Done** — `isStreaming = false`, cursor removed, full message visible

### Settings panel (separate window, opened from toolbar)
- Difficulty slider (1–10) with label ("Beginner" → "Maximum")
- Coaching verbosity picker (Quiet / Normal / Verbose)
- Model selector (shows installed models, option to download alternate)
- "Reset player profile" button

---

## 11. UI Principles & Design Language

### Deployment note
Liquid Glass requires **macOS 26 Tahoe** and **Xcode 26**. The minimum deployment
target is therefore macOS 26. This is a deliberate tradeoff: the language is modern,
native, and deeply integrated — it cannot be backported. Do not attempt to conditionally
apply glass on older OS versions; simply require macOS 26+.

### Overall character
ChessCoach should feel like a calm, intelligent companion — not a game client.
The aesthetic should be modern and inviting: generous whitespace, warm typography,
and a clear visual hierarchy that keeps the chess board as the hero element.
The coaching sidebar feels like a conversation, not a log.

### Liquid Glass — where to use it

Liquid Glass is a **navigation-layer material** — it belongs on controls that float
above content, not on content itself. Follow Apple's golden rule strictly.

**Apply `.glassEffect()` to:**
- The main toolbar (automatic — recompiling with Xcode 26 applies it for free)
- The macOS sidebar (automatic via `NavigationSplitView`)
- Floating action buttons (e.g. "New Game" if implemented as a floating control)
- Sheets and popovers (automatic)
- The onboarding modal panels
- Classification badges on coach messages (subtle `.glassEffect(.regular)`)
- The game result overlay (win/loss/draw)

**Never apply `.glassEffect()` to:**
- The chess board or any square within it
- The coach message bubbles themselves (content layer)
- Scrollable lists or any list rows
- Full-screen or large background regions
- Any element stacked on top of another glass element

**Never stack glass on glass.** If two glass elements are adjacent, wrap them in a
`GlassEffectContainer` — this gives them a shared sampling region and enables morphing.

```swift
// ✅ Correct — toolbar buttons grouped in a container
GlassEffectContainer {
    HStack(spacing: 12) {
        Button("New Game", systemImage: "arrow.counterclockwise") { }
            .glassEffect(.regular.interactive())
        Button("Settings", systemImage: "gearshape") { }
            .glassEffect(.regular.interactive())
    }
}

// ❌ Wrong — glass on scrollable content
ScrollView {
    ForEach(coachMessages) { msg in
        CoachMessageView(msg)
            .glassEffect()  // Never do this
    }
}
```

### Morphing transitions
Use `glassEffectID(_:in:)` with a shared `@Namespace` when a glass element
transitions between states (e.g. the game result overlay appearing, or a difficulty
popover expanding). This produces Apple's signature fluid morphing animation.

```swift
@Namespace private var glassNamespace

// Collapsed state
Button("Difficulty") { }
    .glassEffect(.regular.interactive())
    .glassEffectID("difficulty", in: glassNamespace)

// Expanded popover uses same ID → morphs smoothly
DifficultyPopover()
    .glassEffect()
    .glassEffectID("difficulty", in: glassNamespace)
```

### Typography
- Use the system font (SF Pro) throughout — never a custom typeface
- Coach messages: `.body` size, regular weight, generous line spacing (1.4–1.6)
- Move metadata headers: `.caption` size, `.secondary` colour
- Classification badges: `.caption2`, semibold, all caps
- Board coordinates (if shown): `.caption2`, `.tertiary` colour
- Toolbar labels: `.callout` or system default

### Colour
- Do not define a custom colour palette — use semantic system colours exclusively:
  `.primary`, `.secondary`, `.accent`, `.background`, `.secondaryBackground`
- The chess board colours are ChessboardKit's built-in scheme — use `.light` or `.dark`
  (matching the system appearance) rather than defining custom board colours
- Classification badge tints using system semantic colours:
  - Blunder → `.red`
  - Mistake → `.orange`
  - Inaccuracy → `.yellow`
  - Instructive → `.blue`
- Accent colour: set a single app-wide accent in Assets.xcassets. Suggested: a warm
  amber/gold that evokes chess pieces without being garish. One colour, used sparingly.

### Spacing & layout
- Follow the 8pt grid: all padding, margins, and gaps should be multiples of 8
  (8, 16, 24, 32). Use SwiftUI's `.padding()` defaults where possible — they already
  follow system spacing.
- Coach message bubbles: 16pt horizontal padding, 12pt vertical padding, 12pt corner radius
- Sidebar internal padding: 16pt on all sides
- Between coach messages: 12pt gap
- Board container: no padding — the board fills its container edge to edge

### Motion & animation
- Use `withAnimation(.spring(duration: 0.3))` for state transitions
- Piece movement animation is handled by ChessboardKit's built-in `withAnimation` block
- Coach message appearance: slide in from bottom with a gentle spring
  (`.transition(.move(edge: .bottom).combined(with: .opacity))`)
- Streaming cursor blink: simple `.opacity` animation, 0.6s repeat, autoreverse
- Never use animations longer than 0.5s for UI state changes — keep it snappy

### Coach message bubble styling
The bubble is **not** glass — it is a plain rounded rect using
`.background(.secondaryBackground)` or a subtle fill. The glass material is reserved
for the sidebar chrome (handled automatically by `NavigationSplitView`), not the
message content.

```swift
// ✅ Correct bubble styling
VStack(alignment: .leading, spacing: 6) {
    // Header
    Text("Move \(msg.moveNumber) · \(msg.mover)")
        .font(.caption)
        .foregroundStyle(.secondary)

    // Badge
    Text(msg.classification)
        .font(.caption2.weight(.semibold))
        .textCase(.uppercase)
        .foregroundStyle(msg.badgeColour)
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .glassEffect(.regular)  // ✅ Small badge = ok for glass

    // Message body — plain, no glass
    Text(msg.text)
        .font(.body)
        .lineSpacing(4)
}
.padding(16)
.background(.secondaryBackground, in: RoundedRectangle(cornerRadius: 12))
```

### Onboarding screens
- Full-height centred layout, generous whitespace
- Use SF Symbols for iconography (large, `.hierarchical` rendering)
- Model picker cards: plain rounded rects, no glass — the "recommended" card gets
  a subtle accent border (`.accent` colour, 2pt)
- Download progress: system `ProgressView` with label, no custom chrome
- Single primary CTA button per screen using `.buttonStyle(.borderedProminent)`

### HIG compliance checklist
The agent must verify these before considering any view complete:
- [ ] All interactive elements meet 44×44pt minimum touch/click target size
- [ ] All text meets 4.5:1 contrast ratio against its background
- [ ] App responds correctly to both Light and Dark mode (test both)
- [ ] Dynamic Type is respected — no hardcoded font sizes, use `.font(.body)` etc.
- [ ] Reduce Motion is respected — wrap all decorative animations in
      `if !accessibilityReduceMotion`
- [ ] Keyboard navigation works for all controls (macOS requirement)
- [ ] All images and icons have accessibility labels
- [ ] Focus ring is visible on all interactive elements

---

## 12. App Sandbox & Permissions

For **Mac App Store** compliance:
- Enable App Sandbox in entitlements
- Add `com.apple.security.network.client` (for model download)
- Add `com.apple.security.files.user-selected.read-write` (not needed — writing to
  Application Support is allowed within sandbox via container)
- Stockfish subprocess: add `com.apple.security.temporary-exception.mach-lookup.global-name`
  is NOT needed — spawning a bundled helper binary is allowed under sandbox via
  `com.apple.security.app-sandbox` with helper tool entitlement

For **direct download (.dmg)**: no sandbox required, simpler entitlements.

Build both targets from the start. Use `#if SANDBOXED` compiler flag controlled by
a build configuration to switch between entitlement sets.

### Stockfish binary
- Must be code-signed with the same Developer ID as the app
- Add to `Copy Bundle Resources` build phase
- Set executable permission in a Run Script build phase:
  ```bash
  chmod +x "$BUILT_PRODUCTS_DIR/$CONTENTS_FOLDER_PATH/Resources/Engines/stockfish"
  ```

---

## 13. Error Handling & Edge Cases

| Scenario | Handling |
|---|---|
| Model file missing on launch | Show onboarding again, don't crash |
| Stockfish process dies mid-game | Restart process, re-send position, show brief "reconnecting" indicator |
| LLM inference OOM | Catch exception, show "Coach unavailable" in panel, continue game |
| Download interrupted | Resume support via `URLSessionDownloadTask` with resume data |
| Illegal move from ChessboardKit | Already handled by `isLegal` check — no action needed |
| Checkmate / stalemate | Detect via ChessKit game state, show result overlay, log GameRecord |
| User resigns | Treat as loss, log GameRecord, offer new game |

---

## 14. Implementation Order (Recommended)

Build in this order so each phase is independently testable:

### Phase 1 — Skeleton & board
- Xcode project setup, SPM packages added
- `GameView` layout with ChessboardKit rendering starting position
- Human vs Human works (both sides can move)

### Phase 2 — Stockfish integration
- `StockfishManager` actor with UCI subprocess
- CPU plays moves at fixed difficulty
- Human vs CPU works end-to-end

### Phase 3 — Evaluation pipeline
- Stockfish eval before/after each player move
- `CoachingEngine` computes delta and classifies moves
- Console logs confirm correct classification

### Phase 4 — LLM integration
- `ModelDownloadManager` + onboarding flow
- `LLMManager` loads model and streams output
- `CoachPanelView` renders streaming text
- Full coaching loop works end-to-end

### Phase 5 — Persistence & profile
- SwiftData models integrated
- `PlayerProfile` ACPL updated after each game
- Coaching prompt uses correct skill bracket

### Phase 6 — Polish & UI principles
- Settings view
- Coaching verbosity modes
- Window sizing / responsive layout
- Full Liquid Glass pass: verify glass is only on navigation layer, `GlassEffectContainer`
  used wherever multiple glass elements are adjacent, morphing transitions wired up
- HIG compliance checklist pass (see §11) — Dark Mode, Dynamic Type, Reduce Motion,
  keyboard nav, accessibility labels
- App icon (multi-layer Liquid Glass icon via Icon Composer in Xcode 26)
- About window

---

## 15. What This App Is NOT

To keep scope clear for the agent:
- No online play, no chess servers, no lichess/chess.com integration
- No puzzle mode (v1)
- No game import (PGN paste) (v1)
- No voice coaching
- No iOS/iPadOS version (macOS only, v1)
- No multiplayer (human vs human is fine to leave working but not a feature)
