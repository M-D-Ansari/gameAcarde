import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/services/audio_manager.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/responsive_arcade_container.dart';
import '../../../../core/widgets/tactile_button.dart';
import 'ludo_board_painter.dart';
import 'ludo_controller.dart';
import '../domain/ludo_rules_engine.dart';

class LudoScreen extends ConsumerStatefulWidget {
  final String roomId;
  final int localSeat;
  final bool isSolo;

  const LudoScreen({
    super.key,
    required this.roomId,
    required this.localSeat,
    this.isSolo = false,
  });

  @override
  ConsumerState<LudoScreen> createState() => _LudoScreenState();
}

class _LudoScreenState extends ConsumerState<LudoScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _diceRollAnim;

  @override
  void initState() {
    super.initState();
    _diceRollAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
  }

  @override
  void dispose() {
    _diceRollAnim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final params = LudoParams(roomId: widget.roomId, isSolo: widget.isSolo);
    final ludoAsync = ref.watch(ludoControllerProvider(params));
    final controller = ref.read(ludoControllerProvider(params).notifier);

    return Scaffold(
      backgroundColor: AppColors.darkSlate,
      appBar: AppBar(
        backgroundColor: AppColors.chassisBlack,
        elevation: 0,
        title: Text(widget.isSolo ? 'Ludo: Royal Match (vs Bots)' : 'Ludo Lobby: ${widget.roomId}'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: ResponsiveArcadeContainer(
        maxWidth: 620,
        child: ludoAsync.when(
          loading: () => const Center(child: CircularProgressIndicator(color: AppColors.electricCyan)),
          error: (err, _) => Center(child: Text('Game Sync Error: $err', style: const TextStyle(color: Colors.red))),
          data: (gameState) {
            final isMyTurn = gameState.currentTurnSeat == widget.localSeat;
            final myTokens = gameState.playerTokens[widget.localSeat] ?? [];

            return SafeArea(
              child: Column(
                children: [
                  // 1. Top Skeuomorphic Turn HUD
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildSeatBadge(gameState.currentTurnSeat, widget.isSolo),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: SkeuomorphicDecorations.recessedSlot(radius: 12),
                          child: Row(
                            children: [
                              const Icon(Icons.timer, color: AppColors.arcadeAmber, size: 16),
                              const SizedBox(width: 6),
                              Text(
                                isMyTurn
                                    ? 'YOUR TURN'
                                    : (widget.isSolo ? 'BOT ROLLING...' : 'WAITING...'),
                                style: TextStyle(
                                  color: isMyTurn ? AppColors.electricCyan : Colors.white60,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // 2. Center Ludo Board with Recessed Wood Bevel
                  Expanded(
                    child: Center(
                      child: AspectRatio(
                        aspectRatio: 1.0,
                        child: Padding(
                          padding: const EdgeInsets.all(10.0),
                          child: Container(
                            decoration: SkeuomorphicDecorations.bentoCard(
                              surfaceColor: const Color(0xFF131A24),
                              accentColor: isMyTurn ? AppColors.electricCyan : AppColors.consoleBevel,
                              radius: 20,
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(18),
                              child: CustomPaint(
                                painter: LudoBoardPainter(
                                  gameState: gameState,
                                  localSeat: widget.localSeat,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // 3. Bottom Skeuomorphic Dice & Token Action Console
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    decoration: const BoxDecoration(
                      color: AppColors.chassisBlack,
                      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                      boxShadow: [
                        BoxShadow(color: Colors.black54, offset: Offset(0, -3), blurRadius: 8),
                      ],
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            // 3D Physical Dice
                            GestureDetector(
                              onTap: (isMyTurn && !gameState.hasRolled)
                                  ? () {
                                      AudioManager.instance.playDiceRoll();
                                      _diceRollAnim.forward(from: 0.0);
                                      controller.rollDice(widget.localSeat);
                                    }
                                  : null,
                              child: RotationTransition(
                                turns: Tween(begin: 0.0, end: 0.25).animate(
                                  CurvedAnimation(parent: _diceRollAnim, curve: Curves.easeOutBack),
                                ),
                                child: _buildPhysical3DDice(
                                  gameState.diceRoll,
                                  isInteractive: isMyTurn && !gameState.hasRolled,
                                ),
                              ),
                            ),

                            // Interactive Token Advance Chips (Tokens 1 to 4)
                            if (gameState.hasRolled && isMyTurn)
                              Row(
                                children: List.generate(4, (index) {
                                  final token = myTokens[index];
                                  final canMove = LudoRulesEngine.canTokenMove(token, gameState.diceRoll);
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 3),
                                    child: TactileArcadeButton(
                                      height: 48,
                                      baseColor: canMove ? AppColors.laserGreen : Colors.white12,
                                      radius: 12,
                                      padding: const EdgeInsets.symmetric(horizontal: 12),
                                      onPressed: canMove
                                          ? () {
                                              AudioManager.instance.playPuckHit();
                                              controller.moveToken(playerSeat: widget.localSeat, tokenIndex: index);
                                            }
                                          : null,
                                      child: Text(
                                        'T${index + 1}',
                                        style: TextStyle(
                                          color: canMove ? Colors.black : Colors.white30,
                                          fontWeight: FontWeight.w900,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                  );
                                }),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          isMyTurn
                              ? (!gameState.hasRolled
                                  ? 'Tap the 3D dice to roll!'
                                  : 'Select a token (T1 - T4) to advance')
                              : (widget.isSolo ? 'Bots calculating moves...' : 'Opponent making turn'),
                          style: const TextStyle(color: Colors.white54, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  // 3D PHYSICAL DICE WITH INSET PIPS
  Widget _buildPhysical3DDice(int value, {required bool isInteractive}) {
    return Container(
      width: 68,
      height: 68,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white, Color(0xFFE2E8F0)],
        ),
        boxShadow: [
          // 3D Drop depth
          BoxShadow(
            color: Colors.black.withOpacity(0.6),
            offset: const Offset(0, 5),
            blurRadius: 4,
          ),
          if (isInteractive)
            BoxShadow(
              color: AppColors.electricCyan.withOpacity(0.5),
              blurRadius: 14,
              spreadRadius: 2,
            ),
        ],
        border: Border(
          top: const BorderSide(color: Colors.white, width: 2),
          bottom: BorderSide(color: Colors.black.withOpacity(0.3), width: 3),
        ),
      ),
      child: Center(
        child: value > 0
            ? Text(
                '$value',
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF0F172A),
                ),
              )
            : const Icon(Icons.casino, color: Color(0xFF0F172A), size: 34),
      ),
    );
  }

  Widget _buildSeatBadge(int currentTurnSeat, bool isSolo) {
    const names = ['Green (You)', 'Yellow Bot', 'Blue Bot', 'Red Bot'];
    const pNames = ['Green', 'Yellow', 'Blue', 'Red'];
    final colors = [
      AppColors.laserGreen,
      AppColors.arcadeAmber,
      AppColors.electricCyan,
      AppColors.warningRed,
    ];

    final color = (currentTurnSeat >= 0 && currentTurnSeat < 4)
        ? colors[currentTurnSeat]
        : Colors.grey;
    final name = (currentTurnSeat >= 0 && currentTurnSeat < 4)
        ? (isSolo ? names[currentTurnSeat] : pNames[currentTurnSeat])
        : 'None';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.18),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color, width: 1.5),
      ),
      child: Text(
        'Turn: $name',
        style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 12),
      ),
    );
  }
}
