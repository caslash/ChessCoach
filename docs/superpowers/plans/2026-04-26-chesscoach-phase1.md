# ChessCoach Phase 1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a playable Human vs Human chess app (Phase 1 skeleton) with `NavigationSplitView` sidebar + board layout, SwiftData models defined, and all placeholder files matching the spec's folder structure.

**Architecture:** Xcode 26 project generated via xcodegen, ChessboardKit for board rendering + ChessKit for rules, `@MainActor @Observable` GameViewModel as central state owner, `NavigationSplitView` with fixed-width sidebar for future coach panel.

**Tech Stack:** Swift 6.3, SwiftUI (macOS 26+), ChessboardKit 1.1.2, LLM.swift (latest tag), SwiftData, xcodegen 2.45.3

---

## File Map

Files to **create** (organised by task):

| File | Responsibility |
|------|----------------|
| `project.yml` | xcodegen project descriptor — packages, targets, build configs |
| `ChessCoach/ChessCoach.entitlements` | App Store sandbox entitlements |
| `ChessCoach/ChessCoach-Direct.entitlements` | Direct-download entitlements (no sandbox) |
| `ChessCoach/ChessCoachApp.swift` | App entry, SwiftData ModelContainer, WindowGroup |
| `ChessCoach/Models/GameRecord.swift` | @Model — persisted game history |
| `ChessCoach/Models/PlayerProfile.swift` | @Model — rolling skill profile |
| `ChessCoach/Models/CoachMessage.swift` | struct — in-session chat bubble value type |
| `ChessCoach/Managers/StockfishManager.swift` | actor stub (UCI subprocess, Phase 2) |
| `ChessCoach/Managers/LLMManager.swift` | actor stub (llama.cpp inference, Phase 4) |
| `ChessCoach/Managers/CoachingEngine.swift` | class stub (eval delta logic, Phase 3) |
| `ChessCoach/Managers/ModelDownloadManager.swift` | class stub (GGUF download, Phase 4) |
| `ChessCoach/ViewModels/GameViewModel.swift` | @MainActor @Observable — central game state |
| `ChessCoach/ViewModels/SetupViewModel.swift` | @MainActor @Observable stub (onboarding, Phase 4) |
| `ChessCoach/Views/RootView.swift` | Onboarding gate → GameView or WelcomeView |
| `ChessCoach/Views/Game/GameView.swift` | NavigationSplitView: sidebar + board detail |
| `ChessCoach/Views/Game/BoardContainerView.swift` | ChessboardKit Chessboard wrapper |
| `ChessCoach/Views/Game/CoachPanelView.swift` | Sidebar shell — Phase 1 shows placeholder text |
| `ChessCoach/Views/Game/CoachMessageView.swift` | Chat bubble — Phase 1 placeholder |
| `ChessCoach/Views/Game/GameControlsView.swift` | Toolbar: New Game, colour picker, difficulty |
| `ChessCoach/Views/Setup/WelcomeView.swift` | First-launch welcome screen with CTA |
| `ChessCoach/Views/Setup/ModelPickerView.swift` | Placeholder (Phase 4) |
| `ChessCoach/Views/Setup/ModelDownloadView.swift` | Placeholder (Phase 4) |
| `ChessCoach/Views/Settings/SettingsView.swift` | Placeholder (Phase 6) |
| `ChessCoach/Utilities/FENUtilities.swift` | FEN helpers stub |
| `ChessCoach/Utilities/Extensions.swift` | Swift extensions stub |
| `ChessCoachTests/Models/GameRecordTests.swift` | Unit tests for GameRecord model |
| `ChessCoachTests/Models/PlayerProfileTests.swift` | Unit tests for PlayerProfile model |
| `ChessCoachTests/Models/CoachMessageTests.swift` | Unit tests for CoachMessage struct |
| `ChessCoachTests/ViewModels/GameViewModelTests.swift` | Unit tests for GameViewModel state |

---

## Task 1: Bootstrap — Generate Xcode Project

**Files:**
- Create: `project.yml`
- Create: `ChessCoach/ChessCoach.entitlements`
- Create: `ChessCoach/ChessCoach-Direct.entitlements`

- [ ] **Step 1: Create `project.yml`**

```yaml
name: ChessCoach
options:
  bundleIdPrefix: com.chesscoach
  deploymentTarget:
    macOS: "26.0"
  xcodeVersion: "26.0"
  createIntermediateGroups: true
  generateEmptyDirectories: true

packages:
  ChessboardKit:
    url: https://github.com/rohanrhu/ChessboardKit
    from: "1.1.2"
  LLMSwift:
    url: https://github.com/eastriverlee/LLM.swift
    from: "1.0.0"

configs:
  Debug: debug
  Release: release
  AppStore: release
  DirectDownload: release

targets:
  ChessCoach:
    type: application
    platform: macOS
    sources:
      - ChessCoach
    resources:
      - path: ChessCoach/Resources
    dependencies:
      - package: ChessboardKit
        product: ChessboardKit
      - package: LLMSwift
        product: LLM
    settings:
      base:
        SWIFT_VERSION: "6.0"
        MACOSX_DEPLOYMENT_TARGET: "26.0"
        PRODUCT_BUNDLE_IDENTIFIER: com.chesscoach.ChessCoach
        CODE_SIGN_STYLE: Automatic
        DEVELOPMENT_TEAM: ""
      configs:
        Debug:
          CODE_SIGN_ENTITLEMENTS: ChessCoach/ChessCoach-Direct.entitlements
        Release:
          CODE_SIGN_ENTITLEMENTS: ChessCoach/ChessCoach-Direct.entitlements
        AppStore:
          CODE_SIGN_ENTITLEMENTS: ChessCoach/ChessCoach.entitlements
          SWIFT_ACTIVE_COMPILATION_CONDITIONS: SANDBOXED
        DirectDownload:
          CODE_SIGN_ENTITLEMENTS: ChessCoach/ChessCoach-Direct.entitlements

  ChessCoachTests:
    type: bundle.unit-test
    platform: macOS
    sources:
      - ChessCoachTests
    dependencies:
      - target: ChessCoach
    settings:
      base:
        SWIFT_VERSION: "6.0"
        MACOSX_DEPLOYMENT_TARGET: "26.0"
        BUNDLE_LOADER: "$(TEST_HOST)"
        TEST_HOST: "$(BUILT_PRODUCTS_DIR)/ChessCoach.app/Contents/MacOS/ChessCoach"
```

- [ ] **Step 2: Create App Store sandbox entitlements at `ChessCoach/ChessCoach.entitlements`**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.app-sandbox</key>
    <true/>
    <key>com.apple.security.network.client</key>
    <true/>
</dict>
</plist>
```

- [ ] **Step 3: Create direct-download entitlements at `ChessCoach/ChessCoach-Direct.entitlements`**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.app-sandbox</key>
    <false/>
</dict>
</plist>
```

- [ ] **Step 4: Create the source directory tree so xcodegen finds it**

```bash
mkdir -p ChessCoach/Resources/Engines
mkdir -p ChessCoach/Models
mkdir -p ChessCoach/Managers
mkdir -p ChessCoach/ViewModels
mkdir -p ChessCoach/Views/Game
mkdir -p ChessCoach/Views/Setup
mkdir -p ChessCoach/Views/Settings
mkdir -p ChessCoach/Utilities
mkdir -p ChessCoachTests/Models
mkdir -p ChessCoachTests/ViewModels
```

- [ ] **Step 5: Run xcodegen**

```bash
xcodegen generate
```

Expected output ends with: `Created project at ChessCoach.xcodeproj`

- [ ] **Step 6: Verify the project structure opened and packages can be resolved**

```bash
xcodebuild -resolvePackageDependencies -project ChessCoach.xcodeproj -scheme ChessCoach
```

Expected: Resolves ChessboardKit and LLM.swift without error. Note the resolved LLM.swift version from output (needed for final report).

- [ ] **Step 7: Commit**

```bash
git add project.yml ChessCoach/ChessCoach.entitlements ChessCoach/ChessCoach-Direct.entitlements ChessCoach.xcodeproj
git commit -m "chore: bootstrap Xcode 26 project via xcodegen with ChessboardKit + LLM.swift"
```

---

## Task 2: Explore ChessboardKit API

Before writing any board code, inspect the resolved package to confirm the exact types and method signatures. The CLAUDE.md describes the expected API; verify it matches reality.

**Files:**
- Read: `.build/checkouts/ChessboardKit/Sources/` (or equivalent SPM cache path)

- [ ] **Step 1: Find the resolved package sources**

```bash
find ~/Library/Developer/Xcode/DerivedData -path "*/ChessboardKit/Sources" -type d 2>/dev/null | head -3
# Also check:
find ~/Library/Developer/Xcode/DerivedData -name "Chessboard.swift" 2>/dev/null | head -3
```

- [ ] **Step 2: Read the ChessboardKit public API**

Open the `Chessboard.swift` file (or equivalent main view file) and note:
- The exact name of the SwiftUI view type
- The model type name and its initialiser
- The `onMove` callback parameter names and types
- Any `setFen` or equivalent method signature

Read the ChessKit `Game` type and `FenSerialization` API.

- [ ] **Step 3: Record spec gaps**

If any API names differ from CLAUDE.md §5 (e.g. callback parameters differ, `setFen` has a different signature), record them here as `// TODO: spec gap` comments in `BoardContainerView.swift` when writing Task 7.

No commit needed — this is a research step.

---

## Task 3: Create Placeholder Files for All Non-Phase-1 Files

All files in the §3 folder structure that aren't fully implemented in Phase 1 must exist with a comment so the project compiles cleanly.

**Files:**
- Create: All stub files listed in the File Map above

- [ ] **Step 1: Create `ChessCoach/Managers/StockfishManager.swift`**

```swift
import Foundation

// TODO: Phase 2 — UCI subprocess wrapper
actor StockfishManager {
    static let shared = StockfishManager()
    private init() {}
}
```

- [ ] **Step 2: Create `ChessCoach/Managers/LLMManager.swift`**

```swift
import Foundation

// TODO: Phase 4 — llama.cpp inference via LLM.swift
actor LLMManager {
    static let shared = LLMManager()
    private init() {}
}
```

- [ ] **Step 3: Create `ChessCoach/Managers/CoachingEngine.swift`**

```swift
import Foundation

// TODO: Phase 3 — centipawn delta evaluation and coaching triggers
@MainActor
final class CoachingEngine {
    static let shared = CoachingEngine()
    private init() {}
}
```

- [ ] **Step 4: Create `ChessCoach/Managers/ModelDownloadManager.swift`**

```swift
import Foundation

// TODO: Phase 4 — first-launch GGUF model download with pause/resume
@MainActor
final class ModelDownloadManager: ObservableObject {
}
```

- [ ] **Step 5: Create `ChessCoach/ViewModels/SetupViewModel.swift`**

```swift
import Foundation
import Observation

// TODO: Phase 4 — drives the first-launch onboarding flow
@MainActor
@Observable
final class SetupViewModel {
}
```

- [ ] **Step 6: Create `ChessCoach/Views/Setup/ModelPickerView.swift`**

```swift
import SwiftUI

// TODO: Phase 4 — RAM-aware model picker with download size labels
struct ModelPickerView: View {
    var body: some View {
        Text("Model picker — Phase 4")
    }
}
```

- [ ] **Step 7: Create `ChessCoach/Views/Setup/ModelDownloadView.swift`**

```swift
import SwiftUI

// TODO: Phase 4 — download progress UI with pause/resume
struct ModelDownloadView: View {
    var body: some View {
        Text("Model download — Phase 4")
    }
}
```

- [ ] **Step 8: Create `ChessCoach/Views/Settings/SettingsView.swift`**

```swift
import SwiftUI

// TODO: Phase 6 — difficulty, coaching verbosity, model selector
struct SettingsView: View {
    var body: some View {
        Text("Settings — Phase 6")
            .padding()
    }
}
```

- [ ] **Step 9: Create `ChessCoach/Utilities/FENUtilities.swift`**

```swift
import Foundation

// TODO: FEN helpers beyond ChessKit's built-in serialization
enum FENUtilities {
}
```

- [ ] **Step 10: Create `ChessCoach/Utilities/Extensions.swift`**

```swift
import Foundation
import SwiftUI

// Swift and SwiftUI extensions added as needed
```

- [ ] **Step 11: Commit placeholder stubs**

```bash
git add ChessCoach/Managers/ ChessCoach/ViewModels/SetupViewModel.swift \
        ChessCoach/Views/Setup/ModelPickerView.swift \
        ChessCoach/Views/Setup/ModelDownloadView.swift \
        ChessCoach/Views/Settings/SettingsView.swift \
        ChessCoach/Utilities/
git commit -m "chore: add Phase 2–6 placeholder stubs matching CLAUDE.md §3 structure"
```

---

## Task 4: SwiftData Models

Define all three models fully in Phase 1 to avoid schema migration issues later.

**Files:**
- Create: `ChessCoach/Models/GameRecord.swift`
- Create: `ChessCoach/Models/PlayerProfile.swift`
- Create: `ChessCoach/Models/CoachMessage.swift`
- Create: `ChessCoachTests/Models/GameRecordTests.swift`
- Create: `ChessCoachTests/Models/PlayerProfileTests.swift`
- Create: `ChessCoachTests/Models/CoachMessageTests.swift`

- [ ] **Step 1: Write the failing test for `GameRecord`**

Create `ChessCoachTests/Models/GameRecordTests.swift`:

```swift
import Testing
import Foundation
@testable import ChessCoach

@Suite("GameRecord")
struct GameRecordTests {
    @Test("initialises with expected default values")
    func defaultValues() {
        let record = GameRecord(
            id: UUID(),
            date: .now,
            pgn: "1. e4 e5",
            playerColour: "white",
            difficulty: 5,
            result: "win",
            acpl: 32.5,
            blunderCount: 1,
            mistakeCount: 2
        )
        #expect(record.difficulty == 5)
        #expect(record.playerColour == "white")
        #expect(record.blunderCount == 1)
    }
}
```

- [ ] **Step 2: Run test to confirm it fails (type not yet defined)**

```bash
xcodebuild test -project ChessCoach.xcodeproj \
    -scheme ChessCoachTests \
    -destination "platform=macOS" \
    -only-testing:ChessCoachTests/GameRecordTests 2>&1 | tail -20
```

Expected: Compile error — `GameRecord` not found.

- [ ] **Step 3: Implement `GameRecord`**

Create `ChessCoach/Models/GameRecord.swift`:

```swift
import Foundation
import SwiftData

@Model
final class GameRecord {
    var id: UUID
    var date: Date
    var pgn: String
    var playerColour: String
    var difficulty: Int
    var result: String
    var acpl: Double
    var blunderCount: Int
    var mistakeCount: Int

    init(
        id: UUID = UUID(),
        date: Date = .now,
        pgn: String,
        playerColour: String,
        difficulty: Int,
        result: String,
        acpl: Double,
        blunderCount: Int,
        mistakeCount: Int
    ) {
        self.id = id
        self.date = date
        self.pgn = pgn
        self.playerColour = playerColour
        self.difficulty = difficulty
        self.result = result
        self.acpl = acpl
        self.blunderCount = blunderCount
        self.mistakeCount = mistakeCount
    }
}
```

- [ ] **Step 4: Write the failing test for `PlayerProfile`**

Create `ChessCoachTests/Models/PlayerProfileTests.swift`:

```swift
import Testing
import Foundation
@testable import ChessCoach

@Suite("PlayerProfile")
struct PlayerProfileTests {
    @Test("initialises with beginner skill bracket")
    func defaultSkillBracket() {
        let profile = PlayerProfile(
            rollingACPL: 0,
            gamesPlayed: 0,
            skillBracket: "beginner",
            preferredDifficulty: 5,
            coachingVerbosity: "normal",
            selectedModelFilename: ""
        )
        #expect(profile.skillBracket == "beginner")
        #expect(profile.coachingVerbosity == "normal")
        #expect(profile.preferredDifficulty == 5)
    }
}
```

- [ ] **Step 5: Implement `PlayerProfile`**

Create `ChessCoach/Models/PlayerProfile.swift`:

```swift
import Foundation
import SwiftData

@Model
final class PlayerProfile {
    var rollingACPL: Double
    var gamesPlayed: Int
    var skillBracket: String
    var preferredDifficulty: Int
    var coachingVerbosity: String
    var selectedModelFilename: String

    init(
        rollingACPL: Double = 0,
        gamesPlayed: Int = 0,
        skillBracket: String = "beginner",
        preferredDifficulty: Int = 5,
        coachingVerbosity: String = "normal",
        selectedModelFilename: String = ""
    ) {
        self.rollingACPL = rollingACPL
        self.gamesPlayed = gamesPlayed
        self.skillBracket = skillBracket
        self.preferredDifficulty = preferredDifficulty
        self.coachingVerbosity = coachingVerbosity
        self.selectedModelFilename = selectedModelFilename
    }
}
```

- [ ] **Step 6: Write the failing test for `CoachMessage`**

Create `ChessCoachTests/Models/CoachMessageTests.swift`:

```swift
import Testing
import Foundation
@testable import ChessCoach

@Suite("CoachMessage")
struct CoachMessageTests {
    @Test("initialises with isStreaming true and empty text")
    func initialStreamingState() {
        let msg = CoachMessage(moveNumber: 5, mover: "You", classification: "Blunder")
        #expect(msg.isStreaming == true)
        #expect(msg.text.isEmpty)
        #expect(msg.mover == "You")
        #expect(msg.moveNumber == 5)
    }

    @Test("badge colour matches classification")
    func badgeColourBlunder() {
        let blunder = CoachMessage(moveNumber: 1, mover: "You", classification: "Blunder")
        let mistake = CoachMessage(moveNumber: 1, mover: "You", classification: "Mistake")
        let inaccuracy = CoachMessage(moveNumber: 1, mover: "You", classification: "Inaccuracy")
        let instructive = CoachMessage(moveNumber: 1, mover: "CPU", classification: "Instructive")
        // Verify they don't all return the same colour
        #expect(blunder.badgeColourName != mistake.badgeColourName)
        #expect(inaccuracy.badgeColourName != instructive.badgeColourName)
    }
}
```

- [ ] **Step 7: Implement `CoachMessage`**

Create `ChessCoach/Models/CoachMessage.swift`:

```swift
import Foundation
import SwiftUI

struct CoachMessage: Identifiable {
    let id: UUID
    let moveNumber: Int
    let mover: String
    let classification: String
    var text: String
    var isStreaming: Bool

    init(
        id: UUID = UUID(),
        moveNumber: Int,
        mover: String,
        classification: String,
        text: String = "",
        isStreaming: Bool = true
    ) {
        self.id = id
        self.moveNumber = moveNumber
        self.mover = mover
        self.classification = classification
        self.text = text
        self.isStreaming = isStreaming
    }

    var badgeColourName: String {
        switch classification {
        case "Blunder":     return "red"
        case "Mistake":     return "orange"
        case "Inaccuracy":  return "yellow"
        case "Instructive": return "blue"
        default:            return "secondary"
        }
    }

    var badgeColour: Color {
        switch classification {
        case "Blunder":     return .red
        case "Mistake":     return .orange
        case "Inaccuracy":  return .yellow
        case "Instructive": return .blue
        default:            return .secondary
        }
    }
}
```

- [ ] **Step 8: Run all model tests to confirm they pass**

```bash
xcodebuild test -project ChessCoach.xcodeproj \
    -scheme ChessCoachTests \
    -destination "platform=macOS" \
    -only-testing:ChessCoachTests/GameRecordTests \
    -only-testing:ChessCoachTests/PlayerProfileTests \
    -only-testing:ChessCoachTests/CoachMessageTests 2>&1 | tail -30
```

Expected: `** TEST SUCCEEDED **` — 4 tests pass.

- [ ] **Step 9: Commit**

```bash
git add ChessCoach/Models/ ChessCoachTests/Models/
git commit -m "feat: define SwiftData models GameRecord, PlayerProfile, and CoachMessage struct"
```

---

## Task 5: GameViewModel — Phase 1 Scope

Central game state. Phase 1 scope: tracks whose turn it is, current difficulty, player colour, move history for Human vs Human play, and the coach messages list.

**Files:**
- Create: `ChessCoach/ViewModels/GameViewModel.swift`
- Create: `ChessCoachTests/ViewModels/GameViewModelTests.swift`

- [ ] **Step 1: Write failing tests for `GameViewModel`**

Create `ChessCoachTests/ViewModels/GameViewModelTests.swift`:

```swift
import Testing
import Foundation
@testable import ChessCoach

@Suite("GameViewModel")
@MainActor
struct GameViewModelTests {
    @Test("starts with white to move")
    func initialTurnIsWhite() {
        let vm = GameViewModel()
        #expect(vm.isWhiteToMove == true)
    }

    @Test("default difficulty is 5")
    func defaultDifficulty() {
        let vm = GameViewModel()
        #expect(vm.currentDifficulty == 5)
    }

    @Test("player colour defaults to white")
    func defaultPlayerColour() {
        let vm = GameViewModel()
        #expect(vm.playerColour == "white")
    }

    @Test("startNewGame resets coach messages")
    func startNewGameClearsMessages() {
        let vm = GameViewModel()
        vm.coachMessages = [CoachMessage(moveNumber: 1, mover: "You", classification: "Blunder")]
        vm.startNewGame()
        #expect(vm.coachMessages.isEmpty)
    }

    @Test("startNewGame resets turn to white")
    func startNewGameResetsTurn() {
        let vm = GameViewModel()
        vm.isWhiteToMove = false
        vm.startNewGame()
        #expect(vm.isWhiteToMove == true)
    }
}
```

- [ ] **Step 2: Run to confirm tests fail**

```bash
xcodebuild test -project ChessCoach.xcodeproj \
    -scheme ChessCoachTests \
    -destination "platform=macOS" \
    -only-testing:ChessCoachTests/GameViewModelTests 2>&1 | tail -20
```

Expected: Compile error — `GameViewModel` not found.

- [ ] **Step 3: Implement `GameViewModel`**

Create `ChessCoach/ViewModels/GameViewModel.swift`:

```swift
import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class GameViewModel {
    // MARK: - Game state
    var isWhiteToMove: Bool = true
    var currentDifficulty: Int = 5
    var playerColour: String = "white"
    var isGameOver: Bool = false
    var gameResultMessage: String = ""

    // MARK: - Coach
    var coachMessages: [CoachMessage] = []

    // MARK: - Position tracking (populated by BoardContainerView via ChessKit)
    var currentFEN: String = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"
    var pgn: String = ""
    var moveNumber: Int = 1

    // MARK: - Actions

    func startNewGame() {
        isWhiteToMove = true
        isGameOver = false
        gameResultMessage = ""
        coachMessages = []
        currentFEN = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"
        pgn = ""
        moveNumber = 1
    }

    func togglePlayerColour() {
        playerColour = playerColour == "white" ? "black" : "white"
    }

    // Called by BoardContainerView after each legal move.
    // Phase 2+ will route to StockfishManager; Phase 3+ to CoachingEngine.
    func handleMove(lan: String, newFEN: String, newPGN: String) {
        currentFEN = newFEN
        pgn = newPGN
        isWhiteToMove.toggle()
        // Increment move number after black plays
        if isWhiteToMove { moveNumber += 1 }
        // TODO: Phase 3 — pass to CoachingEngine for eval delta
    }
}
```

- [ ] **Step 4: Run tests to confirm they pass**

```bash
xcodebuild test -project ChessCoach.xcodeproj \
    -scheme ChessCoachTests \
    -destination "platform=macOS" \
    -only-testing:ChessCoachTests/GameViewModelTests 2>&1 | tail -20
```

Expected: `** TEST SUCCEEDED **` — 5 tests pass.

- [ ] **Step 5: Commit**

```bash
git add ChessCoach/ViewModels/GameViewModel.swift ChessCoachTests/ViewModels/GameViewModelTests.swift
git commit -m "feat: implement GameViewModel with Phase 1 game state"
```

---

## Task 6: BoardContainerView — ChessboardKit Integration

This is the most API-sensitive task. Adapt the code below to the exact ChessboardKit API found in Task 2.

**Files:**
- Create: `ChessCoach/Views/Game/BoardContainerView.swift`

**Note:** If the ChessboardKit API differs from what CLAUDE.md describes, implement against the real API and add `// TODO: spec gap` comments noting the discrepancy. The key contract this view must fulfil: when a legal move is made, call `gameViewModel.handleMove(lan:newFEN:newPGN:)`.

- [ ] **Step 1: Implement `BoardContainerView`**

Create `ChessCoach/Views/Game/BoardContainerView.swift`:

```swift
import SwiftUI
import ChessboardKit

// ChessboardKit wraps ChessKit internally. The Chessboard view owns a ChessboardModel
// which exposes a ChessKit Game for rule enforcement and FEN/PGN serialization.
struct BoardContainerView: View {
    @Bindable var gameViewModel: GameViewModel

    // ChessboardKit model — owns the chess engine state for this session.
    // Re-created on startNewGame() via .id() modifier.
    @State private var chessboardModel = ChessboardModel()

    var body: some View {
        Chessboard(model: chessboardModel)
            .onMove { move, isLegal, from, to, lan, promotionPiece in
                guard isLegal else { return }
                handleLegalMove(move: move, lan: lan)
            }
            .aspectRatio(1, contentMode: .fit)
            .onChange(of: gameViewModel.currentFEN) { _, newFEN in
                // Driven externally only during CPU turns (Phase 2).
                // In Phase 1 (HvH), ChessboardKit drives the FEN internally.
            }
    }

    // MARK: - Private

    private func handleLegalMove(move: some Any, lan: String) {
        // Derive updated FEN from ChessKit after the move has been applied.
        // ChessboardKit applies the move internally before firing onMove.
        let newFEN = serializeCurrentFEN()
        let newPGN = serializeCurrentPGN()

        withAnimation(.spring(duration: 0.3)) {
            gameViewModel.handleMove(lan: lan, newFEN: newFEN, newPGN: newPGN)
        }
    }

    private func serializeCurrentFEN() -> String {
        // TODO: spec gap — verify FenSerialization API matches ChessKit version
        // bundled with ChessboardKit 1.1.2. CLAUDE.md §5 references FenSerialization.
        // Adjust the call below to match the actual API after package resolution.
        guard let game = chessboardModel.game else { return gameViewModel.currentFEN }
        return FenSerialization.default.serialize(position: game.position)
    }

    private func serializeCurrentPGN() -> String {
        // TODO: spec gap — verify PGNSerialization API for current ChessKit version.
        guard let game = chessboardModel.game else { return gameViewModel.pgn }
        return PGNSerialization.default.serialize(game: game)
    }
}
```

**If ChessboardKit's `Chessboard` view is initialised differently (e.g. `Chessboard()` with no argument and `chessboardModel` is an `@StateObject`), or if the `onMove` callback signature differs, adjust the initialiser and callback accordingly and document the gap.**

- [ ] **Step 2: Verify the file compiles by building the project**

```bash
xcodebuild build -project ChessCoach.xcodeproj \
    -scheme ChessCoach \
    -destination "platform=macOS" 2>&1 | grep -E "(error:|warning:|BUILD)"
```

Expected: Zero errors. Address any API mismatch before continuing.

- [ ] **Step 3: Commit**

```bash
git add ChessCoach/Views/Game/BoardContainerView.swift
git commit -m "feat: implement BoardContainerView wrapping ChessboardKit"
```

---

## Task 7: CoachPanelView and CoachMessageView (Phase 1 Placeholders)

Phase 1: sidebar shows placeholder text. The full streaming UI comes in Phase 4. The layout and message bubble structure must be correct now so Phase 4 only fills in content.

**Files:**
- Create: `ChessCoach/Views/Game/CoachPanelView.swift`
- Create: `ChessCoach/Views/Game/CoachMessageView.swift`

- [ ] **Step 1: Implement `CoachMessageView`**

Create `ChessCoach/Views/Game/CoachMessageView.swift`:

```swift
import SwiftUI

struct CoachMessageView: View {
    let message: CoachMessage

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Header
            Text("Move \(message.moveNumber) · \(message.mover)")
                .font(.caption)
                .foregroundStyle(.secondary)

            // Classification badge — small glass pill per CLAUDE.md §11
            Text(message.classification)
                .font(.caption2.weight(.semibold))
                .textCase(.uppercase)
                .foregroundStyle(message.badgeColour)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .glassEffect(.regular)

            // Message body
            HStack(alignment: .bottom, spacing: 2) {
                Text(message.text.isEmpty ? " " : message.text)
                    .font(.body)
                    .lineSpacing(4)

                if message.isStreaming {
                    BlinkingCursor()
                }
            }
        }
        .padding(16)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Blinking cursor for streaming state
private struct BlinkingCursor: View {
    @State private var opacity: Double = 1

    var body: some View {
        Text("|")
            .font(.body)
            .opacity(opacity)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) {
                    opacity = 0
                }
            }
    }
}
```

- [ ] **Step 2: Implement `CoachPanelView`**

Create `ChessCoach/Views/Game/CoachPanelView.swift`:

```swift
import SwiftUI

struct CoachPanelView: View {
    @Bindable var gameViewModel: GameViewModel

    var body: some View {
        Group {
            if gameViewModel.coachMessages.isEmpty {
                placeholderView
            } else {
                messageListView
            }
        }
    }

    // MARK: - Placeholder (Phase 1)
    private var placeholderView: some View {
        VStack(spacing: 8) {
            Text("Your coach is watching.")
                .font(.body)
                .foregroundStyle(.secondary)
            Text("I'll speak up when it matters.")
                .font(.body)
                .foregroundStyle(.tertiary)
        }
        .multilineTextAlignment(.center)
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Message list (Phase 4 fills this in fully)
    private var messageListView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(gameViewModel.coachMessages) { message in
                        CoachMessageView(message: message)
                            .id(message.id)
                    }
                }
                .padding(16)
            }
            .onChange(of: gameViewModel.coachMessages.count) { _, _ in
                if let last = gameViewModel.coachMessages.last {
                    withAnimation(.spring(duration: 0.3)) {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
        }
    }
}
```

- [ ] **Step 3: Build to verify**

```bash
xcodebuild build -project ChessCoach.xcodeproj \
    -scheme ChessCoach \
    -destination "platform=macOS" 2>&1 | grep -E "(error:|warning:|BUILD)"
```

Expected: Zero errors.

- [ ] **Step 4: Commit**

```bash
git add ChessCoach/Views/Game/CoachPanelView.swift ChessCoach/Views/Game/CoachMessageView.swift
git commit -m "feat: implement CoachPanelView and CoachMessageView with Phase 1 placeholder"
```

---

## Task 8: GameControlsView

Toolbar controls for New Game, player colour toggle, and difficulty slider.

**Files:**
- Create: `ChessCoach/Views/Game/GameControlsView.swift`

- [ ] **Step 1: Implement `GameControlsView`**

Create `ChessCoach/Views/Game/GameControlsView.swift`:

```swift
import SwiftUI

struct GameControlsView: View {
    @Bindable var gameViewModel: GameViewModel
    @State private var showingSettings = false

    var body: some View {
        GlassEffectContainer {
            HStack(spacing: 12) {
                // New Game
                Button {
                    gameViewModel.startNewGame()
                } label: {
                    Label("New Game", systemImage: "arrow.counterclockwise")
                }
                .glassEffect(.regular.interactive())
                .accessibilityLabel("Start a new game")

                Divider()
                    .frame(height: 20)

                // Player colour toggle
                Button {
                    gameViewModel.togglePlayerColour()
                } label: {
                    Label(
                        gameViewModel.playerColour == "white" ? "Playing White" : "Playing Black",
                        systemImage: gameViewModel.playerColour == "white"
                            ? "circle.fill"
                            : "circle"
                    )
                }
                .glassEffect(.regular.interactive())
                .accessibilityLabel("Toggle player colour — currently \(gameViewModel.playerColour)")

                Divider()
                    .frame(height: 20)

                // Difficulty
                HStack(spacing: 8) {
                    Text("Difficulty")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    Slider(value: difficultyBinding, in: 1...10, step: 1)
                        .frame(minWidth: 120, maxWidth: 160)
                        .accessibilityLabel("Difficulty level \(gameViewModel.currentDifficulty) of 10")
                    Text("\(gameViewModel.currentDifficulty)")
                        .font(.callout.monospacedDigit())
                        .frame(width: 20)
                }
                .padding(.horizontal, 8)
                .glassEffect(.regular)

                Divider()
                    .frame(height: 20)

                // Settings
                Button {
                    showingSettings = true
                } label: {
                    Label("Settings", systemImage: "gearshape")
                }
                .glassEffect(.regular.interactive())
                .accessibilityLabel("Open settings")
                .sheet(isPresented: $showingSettings) {
                    SettingsView()
                        .frame(minWidth: 400, minHeight: 300)
                }
            }
            .padding(.horizontal, 8)
        }
    }

    private var difficultyBinding: Binding<Double> {
        Binding(
            get: { Double(gameViewModel.currentDifficulty) },
            set: { gameViewModel.currentDifficulty = Int($0) }
        )
    }
}
```

- [ ] **Step 2: Build**

```bash
xcodebuild build -project ChessCoach.xcodeproj \
    -scheme ChessCoach \
    -destination "platform=macOS" 2>&1 | grep -E "(error:|warning:|BUILD)"
```

- [ ] **Step 3: Commit**

```bash
git add ChessCoach/Views/Game/GameControlsView.swift
git commit -m "feat: implement GameControlsView toolbar with New Game, colour, difficulty"
```

---

## Task 9: GameView — NavigationSplitView Layout

Two-column layout: left sidebar for the coach panel, right detail for the board. Matches CLAUDE.md §10 exactly.

**Files:**
- Create: `ChessCoach/Views/Game/GameView.swift`

- [ ] **Step 1: Implement `GameView`**

Create `ChessCoach/Views/Game/GameView.swift`:

```swift
import SwiftUI

struct GameView: View {
    @State private var gameViewModel = GameViewModel()
    @State private var sidebarVisible = true

    var body: some View {
        NavigationSplitView {
            // Left sidebar — coach panel
            CoachPanelView(gameViewModel: gameViewModel)
                .navigationSplitViewColumnWidth(min: 260, ideal: 280, max: 320)
        } detail: {
            // Right detail — chess board fills available space
            BoardContainerView(gameViewModel: gameViewModel)
                .aspectRatio(1, contentMode: .fit)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .toolbar {
            ToolbarItemGroup(placement: .automatic) {
                GameControlsView(gameViewModel: gameViewModel)
            }
        }
        .navigationTitle("ChessCoach")
    }
}

#Preview {
    GameView()
}
```

- [ ] **Step 2: Build**

```bash
xcodebuild build -project ChessCoach.xcodeproj \
    -scheme ChessCoach \
    -destination "platform=macOS" 2>&1 | grep -E "(error:|warning:|BUILD)"
```

- [ ] **Step 3: Commit**

```bash
git add ChessCoach/Views/Game/GameView.swift
git commit -m "feat: implement GameView with NavigationSplitView sidebar + board layout"
```

---

## Task 10: RootView, WelcomeView, and Onboarding Gate

`RootView` reads a `hasCompletedOnboarding` `UserDefaults` key and shows either `WelcomeView` (as a full-screen sheet on first launch) or `GameView` directly. SwiftData replaces UserDefaults in Phase 5 — the flag is keyed the same way so migration is a one-line change.

**Files:**
- Create: `ChessCoach/Views/RootView.swift`
- Create: `ChessCoach/Views/Setup/WelcomeView.swift`

- [ ] **Step 1: Implement `WelcomeView`**

Create `ChessCoach/Views/Setup/WelcomeView.swift`:

```swift
import SwiftUI

struct WelcomeView: View {
    @Binding var hasCompletedOnboarding: Bool

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // App icon / hero
            Image(systemName: "crown.fill")
                .font(.system(size: 80))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.accent)

            VStack(spacing: 12) {
                Text("ChessCoach")
                    .font(.largeTitle.weight(.bold))

                Text("Play chess against a strong CPU opponent\nwhile a local AI coach explains your mistakes.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }

            // TODO: Phase 4 — replace this button with ModelPickerView flow
            Button {
                hasCompletedOnboarding = true
            } label: {
                Text("Get Started")
                    .font(.body.weight(.semibold))
                    .frame(minWidth: 200)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .accessibilityLabel("Get started — open the chess app")

            Spacer()
        }
        .padding(48)
        .frame(minWidth: 480, minHeight: 360)
    }
}

#Preview {
    WelcomeView(hasCompletedOnboarding: .constant(false))
}
```

- [ ] **Step 2: Implement `RootView`**

Create `ChessCoach/Views/RootView.swift`:

```swift
import SwiftUI

struct RootView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    var body: some View {
        if hasCompletedOnboarding {
            GameView()
        } else {
            WelcomeView(hasCompletedOnboarding: $hasCompletedOnboarding)
        }
    }
}

#Preview {
    RootView()
}
```

- [ ] **Step 3: Build**

```bash
xcodebuild build -project ChessCoach.xcodeproj \
    -scheme ChessCoach \
    -destination "platform=macOS" 2>&1 | grep -E "(error:|warning:|BUILD)"
```

- [ ] **Step 4: Commit**

```bash
git add ChessCoach/Views/RootView.swift ChessCoach/Views/Setup/WelcomeView.swift
git commit -m "feat: implement RootView onboarding gate and WelcomeView first-launch screen"
```

---

## Task 11: ChessCoachApp Entry Point and SwiftData Container

Wire everything together: the app entry point sets up the SwiftData `ModelContainer` and injects it into the environment, then presents `RootView`.

**Files:**
- Create: `ChessCoach/ChessCoachApp.swift`

- [ ] **Step 1: Implement `ChessCoachApp`**

Create `ChessCoach/ChessCoachApp.swift`:

```swift
import SwiftUI
import SwiftData

@main
struct ChessCoachApp: App {
    private let modelContainer: ModelContainer

    init() {
        do {
            modelContainer = try ModelContainer(for: GameRecord.self, PlayerProfile.self)
        } catch {
            fatalError("Failed to create SwiftData ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(modelContainer)
        .defaultSize(width: 960, height: 680)
        .windowResizability(.contentMinSize)
    }
}
```

- [ ] **Step 2: Final clean build**

```bash
xcodebuild clean build \
    -project ChessCoach.xcodeproj \
    -scheme ChessCoach \
    -destination "platform=macOS" 2>&1 | grep -E "(error:|warning:|BUILD SUCCEEDED|BUILD FAILED)"
```

Expected: `** BUILD SUCCEEDED **` — zero errors, zero warnings.

If there are warnings, address them before proceeding. Common issues:
- `@Sendable` conformance warnings in Swift 6 strict concurrency → add `@MainActor` or `nonisolated` as appropriate
- Unused variable warnings → prefix with `_`
- ChessboardKit API mismatch → apply fixes found in Task 2 and document spec gap

- [ ] **Step 3: Run all tests clean**

```bash
xcodebuild test \
    -project ChessCoach.xcodeproj \
    -scheme ChessCoachTests \
    -destination "platform=macOS" 2>&1 | tail -20
```

Expected: All tests pass (`** TEST SUCCEEDED **`).

- [ ] **Step 4: Commit**

```bash
git add ChessCoach/ChessCoachApp.swift
git commit -m "feat: wire up ChessCoachApp entry point with SwiftData ModelContainer"
```

---

## Task 12: Verification and Phase 1 Report

- [ ] **Step 1: Confirm folder structure matches CLAUDE.md §3 exactly**

```bash
find ChessCoach -name "*.swift" | sort
```

Compare against the tree in CLAUDE.md §3. Every listed file should exist. No extra files should be present.

- [ ] **Step 2: Record the resolved LLM.swift version**

```bash
cat ChessCoach.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved \
    | grep -A5 "LLM"
```

Note the exact version — required in the Phase 1 completion report.

- [ ] **Step 3: Confirm zero errors and zero warnings in a clean build**

```bash
xcodebuild clean build \
    -project ChessCoach.xcodeproj \
    -scheme ChessCoach \
    -destination "platform=macOS" 2>&1 | grep -E "(error:|warning:|BUILD)"
```

- [ ] **Step 4: Final commit**

```bash
git add -A
git commit -m "chore: Phase 1 complete — Human vs Human playable, folder structure matches spec"
```

- [ ] **Step 5: Compose the Phase 1 completion report**

Report must include:
1. Confirmation: `** BUILD SUCCEEDED **` with zero errors, zero warnings
2. LLM.swift resolved version (from Package.resolved)
3. Any spec gaps encountered (API name mismatches from ChessboardKit exploration in Task 2, or any CLAUDE.md §3 gaps)
4. Confirmation that Human vs Human chess is playable through the full game

---

## Self-Review Checklist

### Spec coverage
- [x] §3 Folder structure — all files created or stubbed (Tasks 2, 3)
- [x] §9 SwiftData models — GameRecord, PlayerProfile fully defined; CoachMessage struct (Task 4)
- [x] §10 NavigationSplitView 260–320pt sidebar — `navigationSplitViewColumnWidth(min:ideal:max:)` (Task 9)
- [x] §11 Liquid Glass — glass only on toolbar controls and classification badge; NOT on board, bubbles, or lists (Tasks 7, 8)
- [x] §11 `GlassEffectContainer` wrapping adjacent glass buttons in toolbar (Task 8)
- [x] §5 Phase 1 game flow — onMove fires → `handleMove()` called → turn toggles (Tasks 5, 6)
- [x] §12 Sandboxing — `#if SANDBOXED` compilation condition via AppStore build config; two entitlement files (Task 1)
- [x] §14 Phase 1 done criteria — HvH playable, NavigationSplitView layout in place, folder structure exact (Task 12)
- [x] §4 Onboarding flag — `hasCompletedOnboarding` in UserDefaults (Task 10)
- [x] §11 HIG checklist — accessibility labels on all interactive elements (Tasks 7, 8, 9, 10)

### Potential gaps (flagged for executor)
- ChessboardKit `onMove` callback: the exact Swift parameter types for `move` (likely a ChessKit `Move`) need to be verified in Task 2. The `handleLegalMove` function uses `some Any` as a placeholder — replace with the real type.
- `chessboardModel.game` accessor: may be `game` (non-optional) or `game?` (optional). The `serializeCurrentFEN` and `serializeCurrentPGN` methods guard for optional — adjust if non-optional.
- `FenSerialization.default.serialize(position:)` and `PGNSerialization.default.serialize(game:)` signatures: verify against actual ChessKit version bundled with ChessboardKit 1.1.2.
- `startNewGame()` in `GameViewModel` currently resets state but does not reset the `ChessboardModel` inside `BoardContainerView`. Phase 1 handles this by re-creating the view using `.id(gameViewModel.moveNumber)` or similar. If ChessboardKit does not support programmatic reset, add `// TODO: spec gap` and use a view identity reset.
