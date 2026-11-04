# GameHub Mini-Arcade Suite — Game Design Document (GDD) & UI/UX Specifications

## 1. Executive Summary & Product Vision
GameHub is a high-engagement, hyper-accessible 2D multiplayer mini-arcade mobile application built for Android. It bridges casual local/party play with instant online matchmaking through 6-character room codes and zero-friction deep-linked lobby invites.

The application delivers 12 diverse games split across two synchronization topologies:
1. **Turn-Based & Delta State Games (4 Games):** Strategic, low-frequency input games with strict turn enforcement.
2. **High-Tick Physics & Real-Time Games (8 Games):** Twitch-reaction, 60 FPS physics-driven arcade games powered by the Flame Engine and dead-reckoning interpolation.

---

## 2. Design System & Visual Language

### 2.1 Color Palette & Theme Tokens
- **Theme:** Dark Arcade Neon (Material 3 Dark Foundation)
- **Primary / Brand Neon:** Electric Cyan (`#00F2FE` -> `#4FACFE`)
- **Secondary Neon:** Cyber Magenta (`#F355DA` -> `#7000FF`)
- **Accent Gold / Coins:** Sol Gold (`#FFD200` -> `#F7971E`)
- **Success / Safe Zones:** Emerald Green (`#00E676`)
- **Alert / Danger / Kicks:** Crimson Flare (`#FF1744`)
- **Background Deep:** Void Slate (`#0B0E14`)
- **Surface Elevation 1 (Cards):** Onyx Navy (`#151A23`)
- **Surface Elevation 2 (Modals):** Carbon (`#1E2532`)
- **Grid / Board Dividers:** Muted Silver (`#334155`)

### 2.2 Typography
- **Display / Headers:** `Orbitron` / `Russo One` (Arcade, bold, uppercase, high contrast)
- **Body & Numerical HUD:** `Inter` / `Roboto Mono` (Tabular figures for timers, scores, coordinates)

### 2.3 Audio & Haptic Feedback Hierarchy
- **Audio Channels:**
  - SFX (Puck hits, dice rolls, token captures, hoop chimes, bounce snaps)
  - Ambient Arcade BGM (Upbeat low-fi synthwave, 110-120 BPM, volume ducked during gameplay)
- **Haptic Feedback Patterns:**
  - `HapticFeedback.lightImpact()`: UI button press, tile select.
  - `HapticFeedback.mediumImpact()`: Dice roll, paddle collision.
  - `HapticFeedback.heavyImpact()`: Token capture, goal scored, game over.
  - `HapticFeedback.vibrate()`: Disconnection alert, turn timeout warning (last 3 seconds).

---

## 3. User Flows & Screen Wireframes

### 3.1 Onboarding & Authentication Flow
```
[App Launch]
    │
    ▼
[Auth Check] ──(Not Signed In)──► [Guest Instant Login] ──► [Home Arcade Hub]
    │                                     │
    └──(Existing Token)                   ▼
            │                   [Account Linking Banner]
            │                   (Google / Email Upgrade)
            ▼
    [Home Arcade Hub]
```
- **Zero Friction:** Users can play immediately as an Authenticated Anonymous Guest without entering credentials.
- **Account Protection:** A sticky banner prompts guest users to link their Google or Email/Password account to save win records, coins, and unlocks.

### 3.2 Matchmaking & Lobby Flow
```
                 [Home Arcade Hub]
                  │              │
      ┌───────────┘              └───────────┐
      ▼                                      ▼
[Create Room]                          [Join Room]
  - Select Game (1 of 12)                - 6-Char Room Code Entry
  - Select Mode (1v1 Duel or 4P Party)   - OR Paste Deep Link
  - Set Public / Private (Passcode)      - Scan QR Code
      │                                      │
      └──────────────► [Lobby Room] ◄────────┘
                            │
              (Host / Guest Real-time Presence)
              - Player Seats (0..3)
              - Ready Check Toggle
              - Deep Link Sharing Sheet
              - Host "Start Match"
                            │
                            ▼
                    [In-Game HUD & Canvas]
```

### 3.3 In-Game Universal HUD Layout
- **Top Bar:** 
  - Opponent Profile (Avatar, Name, Ping / Connection Indicator).
  - Central Live Scoreboard / Round Counter.
  - Turn Timer Ring (15-second radial progress bar changing from Green to Amber to Flashing Red).
- **Center Canvas:**
  - Flutter CustomPainter (Turn-based boards) or Flame `GameWidget` (Physics games).
- **Bottom Bar:**
  - Local Player Stats (Seat identifier, Coin bet, Sound/Pause quick toggles).
  - Action tray (Dice roll button, gesture area, item tray).

### 3.4 Disconnect & Forfeiture Modal
- When a remote player loses connection (`.info/connected` flags false):
  - Game pauses with a 30-second reconnection countdown banner.
  - If reconnect fails: Host/Active player awarded default victory; match marked forfeited in RTDB.

---

## 4. Game-Specific Design Documents (GDD)

### Category A: Turn-Based & State-Sync Games

#### 1. Tic Tac Toe
- **Mode:** 1v1 Duel.
- **Board:** 3x3 Grid with animated neon neon strokes (X: Cyan, O: Magenta).
- **Rules:**
  - 15-second turn timer.
  - Three in a row (horizontal, vertical, diagonal) wins.
  - Win evaluator draws an animated vector strike line across winning indices.
- **Sync:** RTDB updates board array `[0..8]`, switches `currentTurnSeat`.

#### 2. Snakes & Ladders
- **Mode:** 2-Player Duel or 4-Player Party.
- **Board:** 10x10 serpentine grid (1 to 100).
- **Rules:**
  - 8 Snakes (e.g., 99->54, 87->24, 62->18, 17->7).
  - 8 Ladders (e.g., 4->14, 9->31, 28->84, 51->67, 80->100).
  - Exact roll required to reach 100.
  - Server-synced 3D dice roll physics animation; tokens glide step-by-step along cell center coordinates.

#### 3. Ludo
- **Mode:** 4-Player Party (Green, Yellow, Blue, Red).
- **Board:** Standard cross layout, 4 Yard bases, 52 common tiles, 4 colored home columns (5 tiles each), 1 center Home.
- **Rules:**
  - Roll 6 to move token out of Yard.
  - Rolling 6 awards a consecutive turn (max 2 consecutive sixes; 3rd forfeits turn).
  - Capturing an opponent's token sends it back to their Yard and awards a bonus turn.
  - 8 Safe Star Zones (no captures allowed).
  - First player to escort all 4 tokens Home wins.

#### 4. Bowling
- **Mode:** 1v1 Asynchronous or Turn-alternating Duel.
- **Input:** Swipe-to-throw with velocity vector (speed and spin curve).
- **Simulation:** Rigid pin physics settlement (Forge2D pin collision or server-settled pin table).
- **Scoring:** Official 10-frame bowling scorecard with strikes (`X`), spares (`/`), and open frames.

---

### Category B: High-Tick / Physics-Based Real-Time Games

#### 5. Flappy Bird Live Duel
- **Mode:** 1v1 Real-Time Endless Duel.
- **Mechanics:** 
  - Synchronized PRNG seed creates identical pipe gaps and vertical offsets.
  - Local bird runs full 60 FPS physics.
  - Opponent bird renders as a semi-transparent ghost avatar with live distance tracking.
  - Last bird flying or farthest distance wins.

#### 6. Table Tennis (2.5D Pong)
- **Mode:** 1v1 Real-Time Duel.
- **Perspective:** 2.5D isometric table perspective.
- **Mechanics:**
  - Paddle follow finger swipe.
  - Spin applied based on tangential paddle velocity vector at moment of collision.
  - Ball trajectory predictive curve with ping compensation.
  - First to 11 points wins.

#### 7. Air Hockey
- **Mode:** 1v1 Real-Time Duel.
- **Mechanics:**
  - Mallets clamped to respective half-courts (0.0 to 0.48 for Top, 0.52 to 1.0 for Bottom).
  - Rigid circular puck bouncing with restitution coefficient = 0.98.
  - Goal slot sensors trigger goal explosion particles and score update.
  - First to 7 goals wins.

#### 8. Stick Football (Finger Soccer)
- **Mode:** 1v1 Turn-based Physics Duel.
- **Mechanics:**
  - 5 player pucks per team on a soccer pitch.
  - Slingshot drag-and-release impulse mechanics.
  - Pucks bounce off pitch barriers and collide with ball.
  - Turn switches once all pucks come to a complete rest (velocity < epsilon).
  - First to 3 goals wins.

#### 9. Stack Animals
- **Mode:** 1v1 Duel or Party.
- **Mechanics:**
  - Swinging crane drops geometric animal shapes (cubes, ovals, triangles) onto a floating platform.
  - Synchronized shape drop queue from shared room seed.
  - Tower height tracked. If player's animals topple into water, life lost.
  - Highest stable stack after 60 seconds wins.

#### 10. Banana Monkey
- **Mode:** 1v1 Real-Time Duel.
- **Mechanics:**
  - Monkey moves horizontally at bottom of screen.
  - Bananas (+10 pts), Golden Bananas (+50 pts), and Anvils (-30 pts / stun 2s) fall from top.
  - Identical item drops spawned via shared seed.
  - 60-second speed-escalating match. Highest score wins.

#### 11. Color Rush
- **Mode:** 1v1 Reaction Test.
- **Mechanics:**
  - 4x4 grid of color tiles.
  - Central prompt displays a color word (e.g., "BLUE") written in a conflicting color font (Stroop effect).
  - First player to tap the correct match gets +100 points minus reaction latency in milliseconds.
  - 10 rounds per match.

#### 12. Street Dash
- **Mode:** 1v1 Endless Runner Duel.
- **Mechanics:**
  - 3-lane vertical runner. Swipe left/right to dodge barricades, swipe up to jump hurdles.
  - Seed-generated deterministic obstacle progression.
  - Live ghost indicator shows opponent's lane and progress ahead/behind.
  - Crash ends run; farthest surviving runner wins.

