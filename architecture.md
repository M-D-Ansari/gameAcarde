# GameHub Mini-Arcade Suite — Technical Architecture Specification

## 1. Multiplatform System Topology & Infrastructure

GameHub is architected as a universal cross-platform application with full support for:
- **Mobile:** Android (APK / AAB) and iOS (IPA / App Store)
- **Web:** Progressive Web App (PWA) with CanvasKit / HTML rendering
- **Desktop:** Windows (Win32 / C++ native runner)

```
┌────────────────────────────────────────────────────────────────────────┐
│               Universal Multiplatform Client (Flutter 3.x)             │
│  [Android OS]        [Apple iOS]          [Web PWA]       [Windows]    │
│  • Touch Gestures    • Metal Render       • CanvasKit     • Mouse Drag │
│  • App Links         • Universal Links    • Browser URL   • Keyboard   │
├────────────────────────────────────────────────────────────────────────┤
│  ┌───────────────────────┐  ┌───────────────────────────────────────┐  │
│  │ Riverpod 2 Notifiers  │  │ Flame Engine v1.16+ (Physics & Canvas)│  │
│  └──────────┬────────────┘  └───────────────────┬───────────────────┘  │
└─────────────┼───────────────────────────────────┼──────────────────────┘
              │                                   │
              ▼                                   ▼
    [Cloud Firestore]              [Firebase Realtime Database (RTDB)]
    - User Profiles                - Room State Delta Sync
    - Persistent Game Stats        - 50Hz Interpolated Motion Packets
    - Global Leaderboards          - High-Precision Presence (.info/connected)
    - Match History Logs           - Atomic Room Locks & Transactions
              ▲                                   ▲
              │                                   │
              └───────────────────┬───────────────┘
                                  │
                    ┌─────────────┴─────────────┐
                    │ Firebase Cloud Functions  │
                    │ - Turn Timeout Enforcer   │
                    │ - Anti-Cheat Win Checker  │
                    │ - Elo & Coin Settlement   │
                    └───────────────────────────┘
```

---

## 2. Cross-Platform Input & Responsive Layout Engine

### 2.1 Multi-Modal Input Abstraction
The game engine supports concurrent input paradigms:
1. **Touch Inputs (Mobile/Tablet):** `PanDetector`, `TapDetector` for capacitive drag and flick gestures.
2. **Mouse Controls (Desktop/Web):** `MouseMovementDetector` enables smooth 1-to-1 mallet and paddle positioning on Windows and browser viewports.
3. **Keyboard Shortcuts (Desktop/Web):** `KeyboardEvents` maps `Spacebar`, `W`, and `ArrowUp` to arcade actions (e.g., Flappy Bird jump, runner lane switching).

### 2.2 Responsive Arcade Cabinet Shell (`ResponsiveArcadeContainer`)
To preserve optimal aspect ratios for vertical 9:16 and 1:1 board games on ultrawide/1080p desktop monitors:
- On mobile devices: edge-to-edge native fullscreen rendering.
- On Web & Windows desktop: centers the active gameplay area in a stylized neon arcade cabinet frame (`maxWidth: 540-600px`) with ambient neon drop-shadows, preventing unnatural horizontal stretching.

---

## 3. Platform-Specific Deep Linking Protocols

| Platform | Protocol / Transport | Fallback Mechanism |
| :--- | :--- | :--- |
| **Android** | Android App Links (`https://gamehub.app/join?code=XYZ123`) via `assetlinks.json` | Custom URI scheme `gamehub://join?code=XYZ123` |
| **iOS** | Apple Universal Links (`https://gamehub.app/join?code=XYZ123`) via `apple-app-site-association` | Custom URI scheme `gamehub://join?code=XYZ123` |
| **Web** | Direct browser URL query parameters (`https://gamehub.app/#/lobby/XYZ123`) | In-app QR code scanner and 6-char input modal |
| **Windows** | Command-line argument passing (`mini_arcade_hub.exe --join=XYZ123`) & clipboard auto-detect | Manual 6-char code input |

---

## 4. Multiplatform Firebase Configuration

Configuration is managed via `DefaultFirebaseOptions.currentPlatform`:
- **Android:** Targets `android/app/google-services.json`.
- **iOS:** Targets `ios/Runner/GoogleService-Info.plist`.
- **Web & Windows:** Initialized with direct Web API options and RTDB URL (`https://gamehub-arcade-prod-default-rtdb.firebaseio.com`).
- **Offline / Mock Fallback:** When credentials are omitted during local development, repositories switch automatically to `MockAuthRepository` and `MockLobbyRepository`.

---

## 5. Layered Clean Architecture (Feature-First)

```
lib/
├── core/
│   ├── config/                  # DefaultFirebaseOptions (cross-platform)
│   ├── network/                 # RTDB service, Firestore client, Presence manager
│   ├── routing/                 # GoRouter & AppLinks receiver
│   ├── theme/                   # Material 3 dark arcade theme & gradients
│   ├── utils/                   # Vector math, NormalizedPoint, SeededPRNG
│   └── widgets/                 # ResponsiveArcadeContainer (Desktop/Web framing)
│
├── features/
│   ├── auth/                    # Guest sign-in & credential linking
│   ├── lobby/                   # Room creation, discovery, matchmaking
│   └── games/
│       ├── ludo/                # 4-Player Turn-Based Party Game
│       ├── tictactoe/           # 1v1 Turn-Based Neon Battle
│       ├── air_hockey/          # 1v1 Real-Time Flame Physics Game
│       └── flappy_bird/         # 1v1 Seeded Deterministic Ghost Duel
```
