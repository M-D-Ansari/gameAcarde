import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/game_types.dart';
import '../../../../core/services/audio_manager.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/responsive_arcade_container.dart';
import '../../../../core/widgets/tactile_button.dart';
import '../../../auth/data/auth_repository.dart';
import '../../../auth/domain/player_profile.dart';
import '../../data/lobby_repository.dart';
import '../../domain/lobby_utils.dart';
import '../../domain/room_model.dart';

class MatchLobbyScreen extends ConsumerStatefulWidget {
  final String roomId;

  const MatchLobbyScreen({super.key, required this.roomId});

  @override
  ConsumerState<MatchLobbyScreen> createState() => _MatchLobbyScreenState();
}

class _MatchLobbyScreenState extends ConsumerState<MatchLobbyScreen> {
  bool _navigatedToGame = false;
  bool _promptShown = false;

  void _copyToClipboard(BuildContext context, String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    AudioManager.instance.playPuckHit();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.chassisBlack,
        duration: const Duration(seconds: 2),
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: AppColors.laserGreen, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '$label copied: $text',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showGuestLoginModal(BuildContext context, RoomModel room, PlayerProfile currentProfile) {
    final existingName = (currentProfile.displayName.isNotEmpty &&
            !currentProfile.displayName.startsWith('Guest_') &&
            !currentProfile.displayName.startsWith('guest_') &&
            !currentProfile.displayName.startsWith('Player_'))
        ? currentProfile.displayName
        : '';
    final nameController = TextEditingController(text: existingName);
    final authRepo = ref.read(authRepositoryProvider);
    final lobbyRepo = ref.read(lobbyRepositoryProvider);
    bool isBusy = false;
    String? statusMessage;

    final hostPlayer = room.players.values.firstWhere(
      (p) => p.isHost,
      orElse: () => const RoomPlayer(
        uid: '',
        seatIndex: 0,
        displayName: 'Arcade Host',
        avatarUrl: '',
        isHost: true,
        isReady: true,
        isConnected: true,
        lastPing: 0,
      ),
    );

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dCtx) => StatefulBuilder(
        builder: (context, setModalState) {
          return AlertDialog(
            backgroundColor: AppColors.chassisBlack,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
              side: const BorderSide(color: AppColors.arcadeMagenta, width: 2.5),
            ),
            titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.arcadeMagenta.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.arcadeMagenta.withOpacity(0.4), width: 1.5),
                  ),
                  child: const Icon(Icons.sports_esports, color: AppColors.arcadeMagenta, size: 26),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('JOIN ARCADE MATCH',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                            letterSpacing: 0.8,
                          )),
                      SizedBox(height: 2),
                      Text('Login or choose a guest nickname',
                          style: TextStyle(color: Colors.white54, fontSize: 11)),
                    ],
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.recessedSlot,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.consoleBevel),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(room.meta.gameType.title,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 14,
                                )),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.arcadeAmber.withOpacity(0.18),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: AppColors.arcadeAmber, width: 1),
                              ),
                              child: Text(
                                widget.roomId,
                                style: const TextStyle(
                                  color: AppColors.arcadeAmber,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 12,
                                  fontFamily: 'monospace',
                                  letterSpacing: 1.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Host: ${hostPlayer.displayName} • ${room.players.length}/${room.meta.gameType.maxPlayers} Players',
                          style: const TextStyle(color: Colors.white54, fontSize: 11),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  TactileArcadeButton(
                    height: 48,
                    baseColor: Colors.white,
                    onPressed: isBusy
                        ? null
                        : () async {
                            setModalState(() {
                              isBusy = true;
                              statusMessage = 'Signing in with Google...';
                            });
                            try {
                              final profile = await authRepo.signInWithGoogle();
                              setModalState(() => statusMessage = 'Joining lobby seat...');
                              await lobbyRepo.joinRoom(roomId: widget.roomId, player: profile);
                              if (context.mounted) Navigator.pop(dCtx);
                            } catch (e) {
                              setModalState(() {
                                isBusy = false;
                                statusMessage = null;
                              });
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    backgroundColor: AppColors.warningRed,
                                    content: Text('Google Sign-In Error: $e'),
                                  ),
                                );
                              }
                            }
                          },
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.g_mobiledata_rounded, color: Colors.black, size: 30),
                        const SizedBox(width: 6),
                        Text(
                          isBusy && statusMessage != null && statusMessage!.contains('Google')
                              ? statusMessage!
                              : 'SIGN IN WITH GOOGLE',
                          style: const TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.w900,
                            fontSize: 12,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  Row(
                    children: [
                      const Expanded(child: Divider(color: Colors.white24, thickness: 1)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: Text(
                          'OR PLAY AS GUEST',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.4),
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                      const Expanded(child: Divider(color: Colors.white24, thickness: 1)),
                    ],
                  ),

                  const SizedBox(height: 14),

                  TextField(
                    controller: nameController,
                    autofocus: true,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                    decoration: InputDecoration(
                      labelText: 'Guest Nickname',
                      labelStyle: const TextStyle(color: AppColors.arcadeMagenta, fontSize: 12, fontWeight: FontWeight.bold),
                      hintText: 'e.g. NeonRunner, PixelAce',
                      hintStyle: const TextStyle(color: Colors.white30, fontSize: 12),
                      filled: true,
                      fillColor: AppColors.recessedSlot,
                      prefixIcon: const Icon(Icons.badge_outlined, color: AppColors.arcadeMagenta, size: 20),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.consoleBevel),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.consoleBevel),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.arcadeMagenta, width: 2),
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  TactileArcadeButton(
                    height: 46,
                    baseColor: AppColors.arcadeMagenta,
                    onPressed: isBusy
                        ? null
                        : () async {
                            final rawName = nameController.text.trim();
                            final finalName = rawName.isNotEmpty
                                ? rawName
                                : 'Guest_${Random().nextInt(900) + 100}';

                            setModalState(() {
                              isBusy = true;
                              statusMessage = 'Joining lobby as $finalName...';
                            });

                            try {
                              final profile = await authRepo.signInAnonymously(finalName);
                              await lobbyRepo.joinRoom(roomId: widget.roomId, player: profile);
                              if (context.mounted) Navigator.pop(dCtx);
                            } catch (e) {
                              setModalState(() {
                                isBusy = false;
                                statusMessage = null;
                              });
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    backgroundColor: AppColors.warningRed,
                                    content: Text('Join Error: $e'),
                                  ),
                                );
                              }
                            }
                          },
                    child: isBusy && statusMessage != null && statusMessage!.contains('Guest')
                        ? Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                statusMessage!,
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                              ),
                            ],
                          )
                        : const Text(
                            'JOIN AS GUEST',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 12,
                              letterSpacing: 0.8,
                            ),
                          ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(dCtx);
                  context.go('/');
                },
                child: const Text('CANCEL (BACK TO HUB)', style: TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final roomAsync = ref.watch(roomStreamProvider(widget.roomId));
    final currentProfile = ref.watch(authStateProvider).valueOrNull ??
        PlayerProfile.guest('guest_${widget.roomId.hashCode.abs().remainder(900) + 100}');
    final lobbyRepo = ref.read(lobbyRepositoryProvider);
    final inviteLink = LobbyUtils.buildInviteLink(widget.roomId);

    return Scaffold(
      backgroundColor: AppColors.darkSlate,
      appBar: AppBar(
        backgroundColor: AppColors.chassisBlack,
        elevation: 0,
        title: Text('Lobby: ${widget.roomId}'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            lobbyRepo.leaveRoom(roomId: widget.roomId, uid: currentProfile.uid);
            context.pop();
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share, color: AppColors.electricCyan),
            tooltip: 'Share Invite Link',
            onPressed: () => _copyToClipboard(context, inviteLink, 'Lobby Link'),
          ),
          InkWell(
            onTap: () {
              roomAsync.whenData((room) {
                if (room != null) _showGuestLoginModal(context, room, currentProfile);
              });
            },
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
              decoration: BoxDecoration(
                color: currentProfile.isAnonymous
                    ? AppColors.arcadeMagenta.withOpacity(0.18)
                    : AppColors.laserGreen.withOpacity(0.18),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: currentProfile.isAnonymous ? AppColors.arcadeMagenta : AppColors.laserGreen,
                  width: 1.2,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    currentProfile.isAnonymous ? Icons.account_circle_outlined : Icons.check_circle,
                    size: 14,
                    color: currentProfile.isAnonymous ? AppColors.arcadeMagenta : AppColors.laserGreen,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    currentProfile.isAnonymous ? 'Guest' : 'Online',
                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      body: ResponsiveArcadeContainer(
        maxWidth: 580,
        child: roomAsync.when(
          loading: () => const Center(child: CircularProgressIndicator(color: AppColors.electricCyan)),
          error: (err, _) => Center(child: Text('Error: $err', style: const TextStyle(color: Colors.red))),
          data: (room) {
            if (room == null) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Room not found or closed by host.', style: TextStyle(color: Colors.white70)),
                    const SizedBox(height: 16),
                    TactileArcadeButton(
                      baseColor: AppColors.electricCyan,
                      onPressed: () => context.pop(),
                      child: const Text('Back to Hub', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              );
            }

            // Check if player is already seated in this room
            final bool isAlreadyInRoom = room.players.containsKey(currentProfile.uid);

            // If not seated and not yet prompted, check if user needs to login or set nickname
            if (!isAlreadyInRoom && !_promptShown) {
              _promptShown = true;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                final bool isLoggedInUser = currentProfile.email != null && !currentProfile.isAnonymous;

                if (isLoggedInUser) {
                  // Fully authenticated user with permanent profile: auto-join seat
                  lobbyRepo.joinRoom(roomId: widget.roomId, player: currentProfile).catchError((e) {
                    debugPrint('Auto-join existing identity error: $e');
                  });
                } else {
                  // Guest user or unauthenticated visitor opening link: MUST show login / guest popup!
                  _showGuestLoginModal(context, room, currentProfile);
                }
              });
            }

            // Auto-route on match start
            if (room.meta.status == RoomStatus.inProgress && !_navigatedToGame) {
              _navigatedToGame = true;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                final myPlayer = room.players[currentProfile.uid];
                final seat = myPlayer?.seatIndex ?? 0;
                final isHost = myPlayer?.isHost ?? false;

                switch (room.meta.gameType) {
                  case GameType.ludo:
                    context.pushReplacement('/games/ludo/${widget.roomId}?seat=$seat');
                    break;
                  case GameType.ticTacToe:
                    context.pushReplacement('/games/tic_tac_toe/${widget.roomId}?seat=$seat');
                    break;
                  case GameType.airHockey:
                    context.pushReplacement('/games/air_hockey/${widget.roomId}?seat=$seat&host=$isHost');
                    break;
                  case GameType.flappyBird:
                    context.pushReplacement('/games/flappy_bird/${widget.roomId}?seat=$seat&seed=${room.meta.seed}');
                    break;
                  default:
                    context.pushReplacement('/games/${room.meta.gameType.id}/${widget.roomId}?seat=$seat');
                    break;
                }
              });
            }

            final isHost = currentProfile.uid == room.meta.hostUid;
            final myPlayer = room.players[currentProfile.uid];
            final isReady = myPlayer?.isReady ?? false;

            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Game Header Bento
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: SkeuomorphicDecorations.bentoCard(
                        surfaceColor: const Color(0xFF1B232E),
                        accentColor: AppColors.electricCyan,
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.electricCyan.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.sports_esports, color: AppColors.electricCyan, size: 28),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  room.meta.gameType.title,
                                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Seats: ${room.players.length} / ${room.meta.gameType.maxPlayers} Players Connected',
                                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Tactile Room Code & Share Link Bento Box
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: SkeuomorphicDecorations.bentoCard(
                        surfaceColor: const Color(0xFF19202A),
                        accentColor: AppColors.arcadeAmber,
                        radius: 16,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.vpn_key_rounded, color: AppColors.arcadeAmber, size: 18),
                                  SizedBox(width: 6),
                                  Text(
                                    'LOBBY CODE & INVITE',
                                    style: TextStyle(
                                      color: AppColors.arcadeAmber,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 11,
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppColors.laserGreen.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: AppColors.laserGreen.withOpacity(0.5), width: 1),
                                ),
                                child: const Text(
                                  'ACTIVE',
                                  style: TextStyle(color: AppColors.laserGreen, fontWeight: FontWeight.bold, fontSize: 10),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),

                          // Large Room Code Display Bar
                          Container(
                            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                            decoration: BoxDecoration(
                              color: AppColors.recessedSlot,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppColors.consoleBevel, width: 1.5),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  widget.roomId,
                                  style: const TextStyle(
                                    color: AppColors.arcadeAmber,
                                    fontSize: 28,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 6,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),

                          // Action Buttons: Copy Code & Copy Link
                          Row(
                            children: [
                              Expanded(
                                child: TactileArcadeButton(
                                  height: 38,
                                  baseColor: AppColors.arcadeAmber,
                                  onPressed: () => _copyToClipboard(context, widget.roomId, 'Room Code'),
                                  child: const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.copy, size: 16, color: Colors.black),
                                      SizedBox(width: 6),
                                      Text(
                                        'COPY CODE',
                                        style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 11),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TactileArcadeButton(
                                  height: 38,
                                  baseColor: AppColors.electricCyan,
                                  onPressed: () => _copyToClipboard(context, inviteLink, 'Invite Link'),
                                  child: const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.link, size: 16, color: Colors.black),
                                      SizedBox(width: 6),
                                      Text(
                                        'COPY LINK',
                                        style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 11),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 14),
                    const Text(
                      'SEATS & PLAYERS',
                      style: TextStyle(color: Colors.white54, fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 1.2),
                    ),
                    const SizedBox(height: 8),

                    // Skeuomorphic Player Seat Cards
                    Expanded(
                      child: ListView.separated(
                        itemCount: room.meta.gameType.maxPlayers,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final player = room.players.values.firstWhere(
                            (p) => p.seatIndex == index,
                            orElse: () => const RoomPlayer(
                              uid: '',
                              seatIndex: -1,
                              displayName: 'Empty Seat',
                              avatarUrl: '',
                              isHost: false,
                              isReady: false,
                              isConnected: false,
                              lastPing: 0,
                            ),
                          );

                          final isEmpty = player.seatIndex == -1;

                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: SkeuomorphicDecorations.bentoCard(
                              surfaceColor: isEmpty ? AppColors.recessedSlot : const Color(0xFF1F2837),
                              accentColor: isEmpty ? AppColors.consoleBevel : (player.isReady ? AppColors.laserGreen : AppColors.arcadeMagenta),
                              radius: 14,
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor: isEmpty ? Colors.white10 : AppColors.chassisBlack,
                                  child: Text(
                                    isEmpty ? 'P${index + 1}' : player.displayName.substring(0, 1).toUpperCase(),
                                    style: TextStyle(
                                      color: isEmpty ? Colors.white24 : AppColors.electricCyan,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        player.displayName,
                                        style: TextStyle(
                                          color: isEmpty ? Colors.white30 : Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      if (!isEmpty)
                                        Text(
                                          player.isHost ? 'Room Host' : (player.isReady ? 'Ready to Play' : 'Waiting...'),
                                          style: TextStyle(
                                            color: player.isHost ? AppColors.arcadeAmber : (player.isReady ? AppColors.laserGreen : Colors.white54),
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                if (isHost && !isEmpty && !player.isHost)
                                  IconButton(
                                    icon: const Icon(Icons.close, color: AppColors.warningRed, size: 20),
                                    onPressed: () => lobbyRepo.kickPlayer(roomId: widget.roomId, targetUid: player.uid),
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),

                    // Bottom Action Controls
                    if (isHost)
                      TactileArcadeButton(
                        height: 52,
                        baseColor: room.canStart ? AppColors.laserGreen : Colors.white24,
                        onPressed: room.canStart
                            ? () {
                                AudioManager.instance.playVictoryFanfare();
                                lobbyRepo.startMatch(widget.roomId);
                              }
                            : null,
                        child: Text(
                          room.canStart ? 'LAUNCH MATCH' : 'WAITING FOR ALL PLAYERS READY',
                          style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 0.8),
                        ),
                      )
                    else
                      TactileArcadeButton(
                        height: 52,
                        baseColor: isReady ? AppColors.consoleBevel : AppColors.arcadeMagenta,
                        onPressed: () {
                          AudioManager.instance.playPuckHit();
                          lobbyRepo.toggleReady(
                            roomId: widget.roomId,
                            uid: currentProfile.uid,
                            isReady: !isReady,
                          );
                        },
                        child: Text(
                          isReady ? 'CANCEL READY' : 'READY TO PLAY',
                          style: TextStyle(
                            color: isReady ? Colors.white70 : Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 13,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
