import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/game_types.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/physical_mode_switch.dart';
import '../../../../core/widgets/responsive_arcade_container.dart';
import '../../../../core/widgets/tactile_button.dart';
import '../../../auth/data/auth_repository.dart';
import '../../../auth/domain/player_profile.dart';
import '../../data/lobby_repository.dart';
import '../../domain/lobby_utils.dart';

enum ArcadePlayMode { solo, multiplayer }
final playModeProvider = StateProvider<ArcadePlayMode>((ref) => ArcadePlayMode.solo);

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentProfile = ref.watch(authStateProvider).valueOrNull ?? PlayerProfile.guest('guest_001');
    final activeMode = ref.watch(playModeProvider);
    final isMultiplayer = activeMode == ArcadePlayMode.multiplayer;
    final lobbyRepo = ref.read(lobbyRepositoryProvider);
    final isGoogleAuth = currentProfile.email != null && !currentProfile.isAnonymous;

    return Scaffold(
      backgroundColor: AppColors.darkSlate,
      appBar: AppBar(
        backgroundColor: AppColors.chassisBlack,
        elevation: 0,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: SkeuomorphicDecorations.arcadeButton(
                baseColor: AppColors.electricCyan,
                radius: 8,
              ),
              child: const Text('GH', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 14)),
            ),
            const SizedBox(width: 8),
            const Text('ARCADE HUB', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 1.5, fontSize: 17)),
          ],
        ),
        actions: [
          // Install App Action (PWA & Desktop)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
            child: TactileArcadeButton(
              height: 32,
              baseColor: AppColors.laserGreen,
              onPressed: () => _showInstallAppDialog(context),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.download_rounded, color: Colors.black, size: 16),
                  SizedBox(width: 4),
                  Text('INSTALL', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 10)),
                ],
              ),
            ),
          ),

          // Google / Guest Profile Action
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
            child: TactileArcadeButton(
              height: 32,
              baseColor: isGoogleAuth ? AppColors.electricCyan : AppColors.arcadeMagenta,
              onPressed: () => _showAuthProfileModal(context, ref, currentProfile),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isGoogleAuth ? Icons.verified_user_rounded : Icons.person_rounded,
                    color: Colors.black,
                    size: 16,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    isGoogleAuth ? 'GOOGLE' : 'GUEST',
                    style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 10),
                  ),
                ],
              ),
            ),
          ),

          // Coins Meter (Skeuomorphic digital counter)
          Container(
            margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: SkeuomorphicDecorations.recessedSlot(radius: 12),
            child: Row(
              children: [
                const Icon(Icons.monetization_on, color: AppColors.arcadeAmber, size: 15),
                const SizedBox(width: 4),
                Text(
                  '${currentProfile.coins}',
                  style: const TextStyle(
                    color: AppColors.arcadeAmber,
                    fontWeight: FontWeight.w900,
                    fontFamily: 'monospace',
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: ResponsiveArcadeContainer(
          maxWidth: 680,
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Physical Mechanical Switch (Solo vs Multiplayer)
                PhysicalModeSwitch(
                  isMultiplayer: isMultiplayer,
                  onChanged: (val) {
                    ref.read(playModeProvider.notifier).state =
                        val ? ArcadePlayMode.multiplayer : ArcadePlayMode.solo;
                  },
                ),

                const SizedBox(height: 16),

                // 2. Bento Grid: Hero Featured Card (Air Hockey / Live Physics Arena)
                _buildHeroBentoCard(context, ref, lobbyRepo, currentProfile, isMultiplayer),

                const SizedBox(height: 12),

                // 3. Bento Grid: Matchmaking / Room Bar
                if (isMultiplayer)
                  _buildMultiplayerLobbyBento(context, ref, lobbyRepo, currentProfile)
                else
                  _buildSoloStatsBento(context, currentProfile),

                const SizedBox(height: 16),

                // 4. Section Label
                Row(
                  children: [
                    Container(width: 4, height: 14, color: isMultiplayer ? AppColors.arcadeMagenta : AppColors.electricCyan),
                    const SizedBox(width: 8),
                    Text(
                      isMultiplayer ? 'ONLINE DUEL & PARTY LOBBIES (LIVE 1V1 SYNC)' : 'INSTANT SOLO ARCADE GAMES (GUEST MODE)',
                      style: TextStyle(
                        color: isMultiplayer ? AppColors.arcadeMagenta : AppColors.electricCyan,
                        fontWeight: FontWeight.w900,
                        fontSize: 11,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // 5. Bento Grid: Multi-Shape Game Tiles
                _buildBentoGameGrid(context, ref, lobbyRepo, currentProfile, isMultiplayer),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // INSTALL APP MODAL
  void _showInstallAppDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.chassisBlack,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.laserGreen, width: 2),
        ),
        title: const Row(
          children: [
            Icon(Icons.download_for_offline, color: AppColors.laserGreen, size: 24),
            SizedBox(width: 10),
            Text('Install GameHub Arcade', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enjoy full screen 60 FPS gameplay, instant offline caching, and desktop/home screen launch without browser tabs!',
              style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 16),
            _buildInstallStep(
              icon: Icons.computer,
              title: 'Chrome / Edge on Desktop:',
              desc: 'Click the Install icon (⤓) on the right side of the URL bar, or choose "Install GameHub Arcade" in the 3-dots menu.',
            ),
            const SizedBox(height: 12),
            _buildInstallStep(
              icon: Icons.phone_android,
              title: 'Android (Chrome):',
              desc: 'Tap the 3-dot menu icon and select "Add to Home screen" or "Install App".',
            ),
            const SizedBox(height: 12),
            _buildInstallStep(
              icon: Icons.apple,
              title: 'iPhone / iPad (Safari):',
              desc: 'Tap the Share icon (⎋) at the bottom, then choose "Add to Home Screen".',
            ),
          ],
        ),
        actions: [
          TactileArcadeButton(
            height: 40,
            baseColor: AppColors.laserGreen,
            onPressed: () => Navigator.pop(ctx),
            child: const Text('GOT IT', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );
  }

  Widget _buildInstallStep({required IconData icon, required String title, required String desc}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppColors.electricCyan, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
              const SizedBox(height: 2),
              Text(desc, style: const TextStyle(color: Colors.white60, fontSize: 11, height: 1.3)),
            ],
          ),
        ),
      ],
    );
  }

  // PROFILE / LOGIN MODAL
  void _showAuthProfileModal(BuildContext context, WidgetRef ref, PlayerProfile profile) {
    final authRepo = ref.read(authRepositoryProvider);
    final isGoogleAuth = profile.email != null && !profile.isAnonymous;
    final nameController = TextEditingController(text: profile.displayName);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.chassisBlack,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.arcadeMagenta, width: 2),
        ),
        title: Row(
          children: [
            Icon(isGoogleAuth ? Icons.verified : Icons.account_circle, color: isGoogleAuth ? AppColors.electricCyan : AppColors.arcadeMagenta, size: 24),
            const SizedBox(width: 10),
            Text(isGoogleAuth ? 'Google Account' : 'Arcade Player Profile', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (isGoogleAuth) ...[
              Text('Signed in as: ${profile.displayName}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 4),
              Text(profile.email ?? '', style: const TextStyle(color: Colors.white60, fontSize: 12)),
              const SizedBox(height: 16),
              TactileArcadeButton(
                height: 42,
                baseColor: AppColors.warningRed,
                onPressed: () async {
                  await authRepo.signOut();
                  ref.read(playModeProvider.notifier).state = ArcadePlayMode.solo;
                  if (context.mounted) Navigator.pop(ctx);
                },
                child: const Text('SIGN OUT', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
              ),
            ] else ...[
              const Text(
                'Play immediately with a custom guest nickname or link your Google account to preserve your stats!',
                style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.4),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: nameController,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                decoration: InputDecoration(
                  labelText: 'Nickname',
                  labelStyle: const TextStyle(color: Colors.white54),
                  filled: true,
                  fillColor: AppColors.recessedSlot,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 14),
              TactileArcadeButton(
                height: 42,
                baseColor: Colors.white,
                onPressed: () async {
                  try {
                    await authRepo.signInWithGoogle();
                    if (context.mounted) {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          backgroundColor: AppColors.chassisBlack,
                          content: Text('Google Sign-In successful!', style: TextStyle(color: AppColors.laserGreen, fontWeight: FontWeight.bold)),
                        ),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Google Sign-In: $e')),
                      );
                    }
                  }
                },
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.g_mobiledata_rounded, color: Colors.black, size: 28),
                    SizedBox(width: 6),
                    Text('SIGN IN WITH GOOGLE', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 11)),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              TactileArcadeButton(
                height: 42,
                baseColor: AppColors.arcadeMagenta,
                onPressed: () {
                  Navigator.pop(ctx);
                },
                child: const Text('SAVE GUEST PROFILE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 11)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // HERO BENTO CARD
  Widget _buildHeroBentoCard(
    BuildContext context,
    WidgetRef ref,
    LobbyRepository repo,
    PlayerProfile profile,
    bool isMultiplayer,
  ) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: SkeuomorphicDecorations.bentoCard(
        surfaceColor: const Color(0xFF1B222E),
        accentColor: AppColors.electricCyan,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.electricCyan.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.electricCyan.withOpacity(0.4)),
                ),
                child: const Text('FEATURED 60 FPS ARENA',
                  style: TextStyle(color: AppColors.electricCyan, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.8)),
              ),
              const Row(
                children: [
                  Icon(Icons.bolt, color: AppColors.arcadeAmber, size: 16),
                  Text('LOW PING', style: TextStyle(color: AppColors.arcadeAmber, fontSize: 11, fontWeight: FontWeight.bold)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Air Hockey: Neon Championship',
            style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          const Text(
            'Sub-millisecond rigid puck physics, live puck and mallet streaming, and guest/Google multiplayer.',
            style: TextStyle(color: Colors.white60, fontSize: 12, height: 1.4),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TactileArcadeButton(
                  baseColor: isMultiplayer ? AppColors.arcadeMagenta : AppColors.electricCyan,
                  onPressed: () {
                    if (isMultiplayer) {
                      _launchMultiplayer(context, ref, repo, GameType.airHockey, profile);
                    } else {
                      context.push('/games/air_hockey/solo?solo=true');
                    }
                  },
                  child: Text(
                    isMultiplayer ? 'CREATE DUEL LOBBY' : 'PLAY SOLO VS AI',
                    style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 0.5),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // MULTIPLAYER LOBBY BENTO
  Widget _buildMultiplayerLobbyBento(
    BuildContext context,
    WidgetRef ref,
    LobbyRepository repo,
    PlayerProfile profile,
  ) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: SkeuomorphicDecorations.bentoCard(
        surfaceColor: const Color(0xFF241C2B),
        accentColor: AppColors.arcadeMagenta,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.arcadeMagenta.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.key, color: AppColors.arcadeMagenta, size: 24),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Join With 6-Char Code', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                Text('Instant matchmaking & deep link lobby', style: TextStyle(color: Colors.white54, fontSize: 11)),
              ],
            ),
          ),
          TactileArcadeButton(
            height: 38,
            baseColor: AppColors.arcadeMagenta,
            onPressed: () => _showJoinCodeDialog(context, ref),
            child: const Text('ENTER CODE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 11)),
          ),
        ],
      ),
    );
  }

  // SOLO STATS BENTO
  Widget _buildSoloStatsBento(BuildContext context, PlayerProfile profile) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: SkeuomorphicDecorations.bentoCard(
        surfaceColor: const Color(0xFF17202C),
        accentColor: AppColors.electricCyan,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.electricCyan.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.leaderboard, color: AppColors.electricCyan, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Player ELO: ${profile.elo}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                Text('${profile.wins} Wins / ${profile.gamesPlayed} Matches Total', style: const TextStyle(color: Colors.white54, fontSize: 11)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.laserGreen.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text('READY', style: TextStyle(color: AppColors.laserGreen, fontWeight: FontWeight.bold, fontSize: 10)),
          ),
        ],
      ),
    );
  }

  // ASYMMETRIC BENTO GRID OF ALL 12 GAMES
  Widget _buildBentoGameGrid(
    BuildContext context,
    WidgetRef ref,
    LobbyRepository repo,
    PlayerProfile profile,
    bool isMultiplayer,
  ) {
    final games = GameType.values.where((g) => g != GameType.airHockey).toList();

    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.15,
      ),
      itemCount: games.length,
      itemBuilder: (context, index) {
        final game = games[index];
        final isTurnBased = index % 2 == 0;
        final accent = isTurnBased ? AppColors.electricCyan : AppColors.arcadeAmber;

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: SkeuomorphicDecorations.bentoCard(
            surfaceColor: const Color(0xFF1A222D),
            accentColor: accent,
            radius: 16,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: accent.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      isTurnBased ? Icons.casino : Icons.speed,
                      color: accent,
                      size: 16,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white10,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${game.maxPlayers}P',
                      style: const TextStyle(color: Colors.white70, fontSize: 9, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    game.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isTurnBased ? 'Turn-based Strategy' : 'Real-time Reaction',
                    style: const TextStyle(color: Colors.white38, fontSize: 10),
                  ),
                ],
              ),
              TactileArcadeButton(
                height: 34,
                baseColor: isMultiplayer ? AppColors.arcadeMagenta : accent,
                onPressed: () {
                  if (isMultiplayer) {
                    _launchMultiplayer(context, ref, repo, game, profile);
                  } else {
                    context.push('/games/${game.id}/solo?solo=true');
                  }
                },
                child: Text(
                  isMultiplayer ? 'HOST LOBBY' : 'PLAY SOLO',
                  style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 10),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _launchMultiplayer(
    BuildContext context,
    WidgetRef ref,
    LobbyRepository repo,
    GameType game,
    PlayerProfile profile,
  ) async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppColors.chassisBlack,
          duration: Duration(milliseconds: 1500),
          content: Row(
            children: [
              SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.arcadeMagenta)),
              SizedBox(width: 12),
              Text('Creating Multiplayer Arena...', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      );

      final roomId = await repo.createRoom(gameType: game, host: profile);
      if (context.mounted) {
        context.push('/lobby/$roomId');
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.chassisBlack,
            content: Text('Lobby Error: $e', style: const TextStyle(color: AppColors.warningRed)),
          ),
        );
      }
    }
  }

  void _showJoinCodeDialog(BuildContext context, WidgetRef ref) {
    final textController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.chassisBlack,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.arcadeMagenta, width: 1.5),
        ),
        title: const Row(
          children: [
            Icon(Icons.gamepad, color: AppColors.arcadeMagenta, size: 22),
            SizedBox(width: 8),
            Text('Join Arcade Room', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Enter 6-char room code or paste full invite URL:',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: textController,
              style: const TextStyle(
                color: AppColors.arcadeMagenta,
                fontSize: 20,
                letterSpacing: 2,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                hintText: 'XYZ123 or paste link',
                hintStyle: const TextStyle(color: Colors.white24, fontSize: 14, letterSpacing: 0),
                filled: true,
                fillColor: AppColors.recessedSlot,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('CANCEL', style: TextStyle(color: Colors.white54)),
          ),
          TactileArcadeButton(
            height: 40,
            baseColor: AppColors.arcadeMagenta,
            onPressed: () {
              final raw = textController.text;
              final code = LobbyUtils.extractRoomCode(raw);
              if (code.length >= 4) {
                Navigator.pop(ctx);
                context.push('/lobby/$code');
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    backgroundColor: AppColors.chassisBlack,
                    content: Text(
                      'Please enter a valid 6-character room code or invite link',
                      style: TextStyle(color: AppColors.arcadeMagenta),
                    ),
                  ),
                );
              }
            },
            child: const Text('JOIN LOBBY', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );
  }
}
