# 🕹️ GameHub Arcade — Universal 12-in-1 Multiplayer Arcade Suite

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.x-0175C2?logo=dart&logoColor=white)](https://dart.dev)
[![Platforms](https://img.shields.io/badge/Platforms-Web%20%7C%20Android%20%7C%20iOS%20%7C%20Windows-brightgreen)](#multiplatform-support)
[![Architecture](https://img.shields.io/badge/Design-Bento%20Grid%20%2B%20Skeuomorphic-FF007F)](#design-philosophy)
[![Tests](https://img.shields.io/badge/Tests-15%20Passing-success)](#running-automated-tests)

**GameHub Arcade** is an open-source, hyper-accessible cross-platform 2D mini-arcade suite engineered with Flutter and the Flame Engine. It unites casual party games and twitch-reaction physics duels under a single skeuomorphic neon arcade cabinet interface.

Featuring **12 complete games**, instant deep-link lobby matchmaking with 6-character room codes, guest authentication, Google Sign-In, PWA installation, and an ultra-low latency subcollection streaming backend with client-side dead reckoning.

---

## 📸 Overview & Highlights

- **12 Unique Arcade Games:** 4 turn-based tactical board games and 8 high-tick physics duels.
- **Skeuomorphic & Bento-Grid UI:** Physical tactile switches, beveled arcade buttons, acrylic neon borders, and dynamic CRT scanline aesthetics.
- **Instant Matchmaking & Link Invites:** Create or join lobbies in seconds via 6-character room codes (`ARC-XXXX`) or one-click invite deep-links (`#/lobby/:roomId`).
- **Frictionless Auth:** Guest instant play with customizable nicknames + 1-click Google Sign-In popup integration.
- **Ultra-Low Latency Multiplayer:** Independent subcollection channel streaming (`/stream/seat_0`, `/stream/seat_1`, `/stream/physics`) with zero document write-contention and client-side dead reckoning at 60 FPS.
- **Multiplatform Responsive:** Native touch gestures on Mobile, 1-to-1 mouse tracking and keyboard bindings on Web/Desktop wrapped inside a responsive cabinet container (`ResponsiveArcadeContainer`).

---

## 🎮 The 12 Games Explained

The suite is divided into two engine topologies: **Turn-Based Tactical Games** and **Real-Time Physics Duels**.

| # | Game | Category | Players | Engine / Rendering | Input Controls |
|---|---|---|---|---|---|
| 1 | **Tic Tac Toe** | Turn-Based | 1–2 | Custom Animated Grid | Tap / Click |
| 2 | **Snakes & Ladders** | Turn-Based | 2–4 | Custom 100-Tile Painter | Tap / Dice Roll |
| 3 | **Ludo Party** | Turn-Based | 2–4 | Geometric Royal Painter | Tap Token / Roll |
| 4 | **Arcade Bowling** | Turn-Based | 1–2 | 3D Perspective Canvas | Swipe / Drag Vector |
| 5 | **Table Tennis 2.5D** | Real-Time | 1–2 | Isometric Vector Table | Mouse / Touch Drag |
| 6 | **Air Hockey Duel** | Real-Time | 1–2 | Flame Engine Rigid Body | Mouse / Touch Drag |
| 7 | **Flappy Bird Live** | Real-Time | 1–2 | Flame Deterministic PRNG | Tap / Space / Click |
| 8 | **Stick Football** | Real-Time | 1–2 | Rigid Impulse Physics | Slingshot Drag & Flick |
| 9 | **Stack Animals** | Real-Time | 1–2 | Center-of-Mass Physics | Tap Crane Drop |
| 10 | **Banana Monkey** | Real-Time | 1–2 | Falling Object Catcher | Horizontal Drag |
| 11 | **Color Rush** | Real-Time | 1–2 | Stroop Effect Reflex | Rapid Color Tap |
| 12 | **Street Dash** | Real-Time | 1–2 | 3-Lane Endless Runner | Arrows / Left-Right Tap |

---

### Category A: Turn-Based & Tactical Games

#### 1. Tic Tac Toe (`lib/features/games/tictactoe/`)
- **Objective:** Align three matching marks (`X` or `O`) horizontally, vertically, or diagonally on a 3x3 neon grid.
- **Multiplayer Sync:** 15-second per-turn countdown timer with turn-switch snapshots synced over `MultiplayerSyncService.watchGameState`.
- **Solo Mode:** Features an adaptive AI opponent that blocks winning rows and claims center advantage.

#### 2. Snakes & Ladders (`lib/features/games/snakes_ladders/`)
- **Objective:** Race from tile 1 to tile 100 on a multi-tiered board with climbing ladders and sliding serpents.
- **Multiplayer Sync:** 2 to 4 player turn rotation. Rolling a 6 grants a bonus turn.
- **Deterministic Mechanics:** Dice physics synchronized across players with exact landing validation.

#### 3. Ludo Party (`lib/features/games/ludo/`)
- **Objective:** Navigate 4 colored tokens around the royal cross-shaped track and enter Home.
- **Rules Engine:** Authentic Pachisi rules: tokens emerge from Yard only on a roll of 6; safe star tiles prevent captures; capturing an opponent token sends it to the yard and awards a bonus roll.
- **Multiplayer Sync:** 2 to 4 player live turn state machine (`LudoController`) with pawn path validation.

#### 4. Arcade Bowling (`lib/features/games/bowling/`)
- **Objective:** Knock down all 10 pins across standard frames with strikes and spares.
- **Physics & Animation:** 3D perspective hardwood bowling lane with rotational ball spin, perspective scaling (`1.0 -> 0.45`), and pin scatter physics calculated from swipe velocity and release angle.
- **Multiplayer Sync:** 1v1 turn-based roll synchronization with live scorecards.

---

### Category B: Real-Time & Physics Duels

#### 5. Table Tennis 2.5D (`lib/features/games/table_tennis/`)
- **Objective:** Return the ping-pong ball across the net past your opponent's paddle.
- **Physics & Controls:** Isometric perspective with parabolic gravity arc bounce (`ballZ`), paddle curvature angle control (`vx` modifier), and comfortable human-reactable speeds.
- **Multiplayer Stream:** Dedicated `stream/physics` channel from Host + dead-reckoning trajectory simulation on Guest for butter-smooth 60 FPS rallies.

#### 6. Air Hockey Duel (`lib/features/games/air_hockey/`)
- **Objective:** Strike the neon puck into the opponent's goal slot while defending your own.
- **Physics & Controls:** Flame Engine rigid puck body with wall rebounds, friction decay, and tactile impact sound effects.
- **Multiplayer Stream:** Host broadcasts authoritative puck coordinates and score; both players stream mallets on independent seat channels with dead-reckoning velocity prediction.

#### 7. Flappy Bird Live (`lib/features/games/flappy_bird/`)
- **Objective:** Flap through moving neon pipe gates without crashing into pipes or boundary walls.
- **Deterministic Obstacles:** Seeded Pseudo-Random Number Generator (`SeededPRNG`) ensures both players encounter the exact same pipe obstacles at the exact same distances.
- **Multiplayer Stream:** Real-time ghost bird altitude and distance telemetry streamed between seats.

#### 8. Stick Football (`lib/features/games/stick_football/`)
- **Objective:** Slingshot your team's 5 hockey puck discs into the ball to score goals into the opponent's net.
- **Physics & Controls:** Elastic slingshot pull-back indicator with impulse vector calculation, disc-to-disc and disc-to-ball elastic collisions.
- **Multiplayer Sync:** Turn-based shot impulses synchronized with goal zone triggers.

#### 9. Stack Animals (`lib/features/games/stack_animals/`)
- **Objective:** Drop swinging animal shapes onto a balancing pedestal to build the highest tower without collapsing.
- **Physics & Controls:** Harmonic pendulum swing crane with center-of-mass balance detection and tilt collapse physics.
- **Multiplayer Sync:** Turn-based alternating drops with live tower height tracking.

#### 10. Banana Monkey (`lib/features/games/banana_monkey/`)
- **Objective:** Catch falling bananas while avoiding falling bomb hazards within a 45-second timer.
- **Controls & Mechanics:** Smooth capacitive horizontal drag with escalating spawn speeds.
- **Multiplayer Stream:** Real-time 1v1 duel scoreboard synchronization.

#### 11. Color Rush (`lib/features/games/color_rush/`)
- **Objective:** Rapidly tap the color box that matches the **meaning** of the word, overcoming the Stroop cognitive effect.
- **Scoring:** Time-decay reaction score (`max(100, 1000 - elapsedMs)`).
- **Multiplayer Stream:** 10-round live duel synchronization with millisecond response scores.

#### 12. Street Dash (`lib/features/games/street_dash/`)
- **Objective:** Dodge barriers, traffic cones, and obstacles in a high-speed 3-lane vertical runner.
- **Controls:** Arrow keys or Left/Right tactile buttons to jump between lanes.
- **Multiplayer Stream:** Live distance and survival status streamed to the opponent.

---

## 🛠️ Local Installation & Setup

### Prerequisites
- [Flutter SDK](https://docs.flutter.dev/get-started/install) (`3.22.0` or higher recommended)
- [Dart SDK](https://dart.dev/get-dart) (`3.4.0` or higher)
- [Git](https://git-scm.com/)

### 1. Clone the Repository
```bash
git clone https://github.com/M-D-Ansari/gameAcarde.git
cd gameAcarde
```

### 2. Install Dependencies
```bash
flutter pub get
```

### 3. Configure Environment Credentials
Copy the example environment template:
```bash
cp .env.example .env
```
Populate `.env` with your Firebase project credentials or pass them via `--dart-define` at runtime:
```bash
flutter run -d chrome \
  --dart-define=FIREBASE_API_KEY="YOUR_API_KEY" \
  --dart-define=FIREBASE_APP_ID="YOUR_APP_ID" \
  --dart-define=FIREBASE_PROJECT_ID="YOUR_PROJECT_ID"
```
*(Note: If run without `--dart-define`, the app launches in safe offline/mock fallback mode).*

### 4. Run Locally on Target Platforms

- **Run in Chrome (Web PWA):**
  ```bash
  flutter run -d chrome
  ```
- **Run on Windows Desktop:**
  ```bash
  flutter run -d windows
  ```
- **Run on Android Device / Emulator:**
  ```bash
  flutter run -d android
  ```
- **Run on iOS Simulator:**
  ```bash
  flutter run -d ios
  ```

---

## 🧪 Running Automated Tests

All core algorithms, vector math, Ludo rules, deterministic PRNG sequences, and lobby matchmaking are covered by automated unit tests.

To run the complete test suite:
```bash
flutter test
```

To run individual test suites:
```bash
flutter test test/lobby_test.dart
flutter test test/ludo_rules_test.dart
flutter test test/prng_test.dart
flutter test test/vector_test.dart
```

---

## 🎨 How to Customize & Modify Games

### 1. Adjusting Game Speeds & Physics Parameters
- **Table Tennis Ball Speed:** Edit `vx`, `vy`, and `vz` in [`lib/features/games/table_tennis/presentation/table_tennis_screen.dart`](lib/features/games/table_tennis/presentation/table_tennis_screen.dart).
- **Air Hockey Friction & Rebound:** Modify `_checkPaddleCollision()` and friction multiplier in [`lib/features/games/air_hockey/engine/air_hockey_flame_game.dart`](lib/features/games/air_hockey/engine/air_hockey_flame_game.dart).
- **Bowling Ball Velocity & Scaling:** Adjust `_rollController` curve and durations in [`lib/features/games/bowling/presentation/bowling_screen.dart`](lib/features/games/bowling/presentation/bowling_screen.dart).
- **Flappy Bird Gravity:** Tweak `gravity` and `jumpImpulse` in [`lib/features/games/flappy_bird/engine/flappy_bird_flame_game.dart`](lib/features/games/flappy_bird/engine/flappy_bird_flame_game.dart).

### 2. Modifying Arcade Theme & Colors
All visual tokens (neon gradients, bevels, recessed slots, and bento cards) are centralized in:
- [`lib/core/theme/app_theme.dart`](lib/core/theme/app_theme.dart)
  - `AppColors.electricCyan` (`#00F2FE`)
  - `AppColors.arcadeMagenta` (`#F355DA`)
  - `AppColors.arcadeAmber` (`#FFB300`)
  - `AppColors.laserGreen` (`#00E676`)
  - `AppColors.chassisBlack` (`#0B0E14`)

### 3. Adding a New Minigame
To add a 13th game to GameHub:
1. **Define Game Metadata:** Add a new entry to `enum GameType` in [`lib/core/constants/game_types.dart`](lib/core/constants/game_types.dart).
2. **Create Presentation Screen:** Create `lib/features/games/<your_game>/presentation/<your_game>_screen.dart`.
3. **Register Route:** Add a `GoRoute` in [`lib/core/routing/app_router.dart`](lib/core/routing/app_router.dart).
4. **Hook Realtime Sync:** Use `MultiplayerSyncService.watchSeatStream` and `updateSeatStream` for live multiplayer synchronization.

---

## 🤝 Contribution Workflow (How to Create a PR)

We welcome contributions from the community! Follow these steps to submit a Pull Request:

### Step 1: Fork the Repository
Click the **Fork** button at the top right of [github.com/M-D-Ansari/gameAcarde](https://github.com/M-D-Ansari/gameAcarde) to create your own copy.

### Step 2: Clone Your Fork
```bash
git clone https://github.com/<YOUR-USERNAME>/gameAcarde.git
cd gameAcarde
```

### Step 3: Create a Feature Branch
```bash
git checkout -b feat/your-feature-name
# Examples:
# git checkout -b feat/add-sound-toggle
# git checkout -b fix/air-hockey-rebound-glitch
```

### Step 4: Make Your Changes & Test
Make sure your changes adhere to code style guidelines and pass all tests:
```bash
flutter analyze
flutter test
```

### Step 5: Commit Your Changes
Use clean, descriptive conventional commit messages:
```bash
git add .
git commit -m "feat(table_tennis): add spin paddle curve physics"
```

### Step 6: Push to Your Fork
```bash
git push -u origin feat/your-feature-name
```

### Step 7: Open a Pull Request
1. Go to your fork on GitHub.
2. Click **Compare & pull request**.
3. Select `base: main` from the upstream repository.
4. Fill in the PR description detailing what was changed, tested, and any relevant screenshots.
5. Submit the Pull Request!

---

## 📋 Rules & Standards for Pull Requests

To maintain high code quality, security, and stability, all Pull Requests must satisfy the following rules:

1. **🔒 Zero Credentials & Secrets Rule:**
   - **Never** commit real API keys, service accounts, `.env` files, `firebase.json`, `firestore.rules`, or Google Search Console verification tokens.
   - Always verify that `.gitignore` prevents private credentials from being staged.

2. **✅ Automated Tests Must Pass:**
   - Every PR must pass `flutter test` with all 15 tests green.
   - If adding a new feature or rules engine, include matching unit tests in `test/`.

3. **🧹 Clean Static Analysis:**
   - Run `flutter analyze` locally; zero warnings and zero errors are required.
   - Format code using `dart format .`.

4. **📱 Multiplatform Responsiveness:**
   - Any new screen must support both Touch (mobile) and Mouse/Keyboard (desktop/web).
   - Use `ResponsiveArcadeContainer` to keep gameplay centered and proportional across ultrawide monitors and portrait phones.

5. **🎨 Design Consistency:**
   - Adhere to the Dark Arcade Neon & Bento-Grid design system in `AppTheme`.
   - Avoid generic Material 3 light themes or flat default buttons; use `TactileArcadeButton` and `SkeuomorphicDecorations`.

6. **⚡ Non-Blocking Multiplayer Stream:**
   - Never write to root room documents on fast 60 FPS tick loops.
   - Always route real-time telemetry through dedicated subcollection channels in `MultiplayerSyncService`.

---

## 📜 License

This project is licensed under the [MIT License](LICENSE). You are free to use, modify, and distribute this codebase for educational and personal projects.

---

<p align="center">
  Crafted with 🕹️ for retro arcade lovers everywhere.
</p>
