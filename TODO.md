# GameHub Mini-Arcade Suite — Master Implementation Roadmap (TODO)

## Live Production Deployment
- **Firebase Project ID:** `gamehub-arcade-987`
- **Firebase Console:** [https://console.firebase.google.com/project/gamehub-arcade-987/overview](https://console.firebase.google.com/project/gamehub-arcade-987/overview)
- **Live Hosting URL (Global CDN):** [https://gamehub-arcade-987.web.app](https://gamehub-arcade-987.web.app)
- **Local Dev Server:** [http://localhost:8080](http://localhost:8080)

---

## Phase 1: Project Foundation & Core Infrastructure
- [x] **1.1 Flutter Project Initialization**
  - [x] Configure `pubspec.yaml` with all dependencies (`flame`, `flutter_riverpod`, `firebase_core`, `firebase_database`, `app_links`, `go_router`, etc.).
  - [x] Set up directory structure following Feature-First Clean Architecture (`core/`, `features/`).
  - [x] Configure Android build settings (`AndroidManifest.xml` with intent-filters for App Links and deep links).
  - [x] Configure iOS build settings (`ios/Runner/Info.plist` with Universal Links and URL Schemes).
  - [x] Configure Web PWA settings (`web/index.html`, `web/manifest.json`).
  - [x] Configure Windows Desktop settings (`windows/runner/main.cpp`).
- [x] **1.2 Core Utilities & Base Infrastructure**
  - [x] Implement `PresenceManager` utilizing `.info/connected` and `onDisconnect()`.
  - [x] Build vector utilities, screen-to-normalized coordinate converters, and LERP helpers (`NormalizedPoint`).
  - [x] Implement deterministic PRNG generator (`SeededPRNG`) for infinite runners and procedural drops.
  - [x] Build `ResponsiveArcadeContainer` for Desktop/Web arcade cabinet framing.
- [x] **1.3 De-AI'd Skeuomorphic UI & Bento Grid Redesign**
  - [x] Tactile 3D arcade buttons with physical push-down translation and bottom drop-depth (`TactileArcadeButton`).
  - [x] Recessed inset console slots with ambient drop shadows (`SkeuomorphicDecorations.recessedSlot`).
  - [x] Mechanical sliding switch (`PhysicalModeSwitch`) for Solo (Default) vs Multiplayer.
  - [x] Asymmetric Bento Grid layout with Hero 60 FPS Arena card, Matchmaking bar, and multi-shape game tiles.
- [x] **1.4 Authentication & Player Profile Feature**
  - [x] Anonymous guest login on first launch (Solo Mode default).
  - [x] Guest login & custom nickname allowed for Multiplayer lobbies.
  - [x] Google Sign-In (`signInWithGoogle` via Firebase Auth & Google provider).
  - [x] In-memory mock fallback repository for offline/preview testing.
  - [x] Account profile card and sign-out dialog in AppBar.
  - [x] Install App option in AppBar with guided PWA / Desktop / Mobile setup.

---

## Phase 2: Lobby, Matchmaking & Deep Linking
- [x] **2.1 Deep Linking Pipeline**
  - [x] Configure Android App Links intent filters for `https://gamehub.app/join` and `gamehub://join`.
  - [x] Implement `DeepLinkController` with `app_links` to handle cold boot and background resume.
  - [x] Connect deep link trigger to `GoRouter` dynamic route injection (`/lobby/:roomId`).
  - [x] Extract room codes from direct codes or pasted full web URLs (`LobbyUtils.extractRoomCode`).
- [x] **2.2 Room Creation & Discovery**
  - [x] Firestore Lobby Repository (`FirestoreLobbyRepository`) with active sub-millisecond document listeners.
  - [x] 6-character room code generator (collision-resistant).
  - [x] Real-time waiting room (`MatchLobbyScreen`) with skeuomorphic seat cards, one-touch code and link copying, host controls, ready toggles, and auto-launch.
  - [x] Auto-join logic when navigating via web invite link.

---

## Phase 3: Category A Games (Turn-Based & State-Sync)
- [x] **3.1 Tic Tac Toe (1v1)**
  - [x] Skeuomorphic wooden/acrylic recessed board with 3D embossed X and O stamps.
  - [x] Fast heuristics AI in Solo mode (220ms response time).
  - [x] Rematch loop and win lines.
- [x] **3.2 Snakes & Ladders (2P - 4P)**
  - [x] 10x10 serpentine board layout with 8 snakes and 8 ladders.
  - [x] Snappy bot turns in Solo mode + 4P Multiplayer.
- [x] **3.3 Ludo (4-Player Party)**
  - [x] 3D physical dice with rounded edges, drop shadow, and rotating throw animation.
  - [x] Fast automated bot turns (250ms delay) for Yellow, Blue, and Red tokens.
  - [x] Tactile token advance buttons (`T1`-`T4`) with 3D push depth.
- [x] **3.4 Bowling (1v1)**
  - [x] 3D perspective animated ball rolling down the hardwood lane with rotational spin.
  - [x] Dynamic pin knockdown physics and 10-frame dual scoreboard.
  - [x] Full 1v1 turn-based multiplayer sync via Firestore (`MultiplayerSyncService`).

---

## Phase 4: Category B Games (High-Tick / Flame Engine Real-Time)
- [x] **4.1 Air Hockey (1v1)**
  - [x] Live multiplayer stream of puck position, scores, and both player mallets over Firestore.
  - [x] High-speed responsive physics with physical center-knob mallets and heavy puck.
  - [x] Reactive AI bot with defensive half-court clamping in Solo mode.
- [x] **4.2 Flappy Bird Live Duel (1v1)**
  - [x] Real-time ghost bird altitude & distance streaming over Firestore.
  - [x] Deterministic procedural pipe generator using shared room seed.
- [x] **4.3 Table Tennis / 2.5D Pong (1v1)**
  - [x] Tuned ball speed to comfortable human-playable speed.
  - [x] 2-Player live duel: Host controls bottom cyan paddle, Guest controls top magenta paddle.
  - [x] Real-time paddle and ball position sync over Firestore.
- [x] **4.4 Stick Football / Finger Soccer (1v1)**
  - [x] 1v1 multiplayer impulse shot sync with deterministic barrier rebounds.
- [x] **4.5 Stack Animals (1v1 / Party)**
  - [x] 1v1 alternating tower drop turns synced live over Firestore.
- [x] **4.6 Banana Monkey, Color Rush, Street Dash**
  - [x] Real-time 1v1 live dual score and progress streams over Firestore.
- [x] **4.6 Banana Monkey (1v1)**
  - [x] Horizontal monkey basket controls with falling bananas, golden bananas, and anvils.
- [x] **4.7 Color Rush (1v1 Reaction)**
  - [x] 4x4 randomized color grid with Stroop effect conflicting word prompts.
- [x] **4.8 Street Dash (1v1 Endless Runner)**
  - [x] 3-lane vertical runner with swipe controls and keyboard arrow support.

---

## Phase 5: Cloud Functions & Anti-Cheat
- [x] **5.1 Authoritative Game Cloud Functions**
  - [x] `enforceTurnTimeout`: Background scheduled turn handover if a client times out.
  - [x] `resolveMatchFinished`: Validates submitted scores, calculates Elo adjustments, and credits coin balance.
- [x] **5.2 Security Rules Deployment**
  - [x] Deployed RTDB security rules (`database.rules.json`).
  - [x] Deployed Firestore security rules (`firestore.rules`).

---

## Phase 6: Polish, Performance & Production Readiness
- [x] **6.1 Unit Tests & Verification**
  - [x] 11/11 tests passing (`test/ludo_rules_test.dart`, `test/prng_test.dart`, `test/vector_test.dart`).
- [x] **6.2 Production Deployment & Hosting**
  - [x] Deployed live to Firebase Hosting (`https://gamehub-arcade-987.web.app`).
  - [x] Firestore security rules released to cloud.
- [x] **6.3 Audio, SFX & Haptics**
  - [x] Sound and haptic manager ([`audio_manager.dart`](file:///c:/useThis/personal/qSpiders\alphaBatch\gameApp\lib\core\services\audio_manager.dart)).
