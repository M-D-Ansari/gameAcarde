import 'package:go_router/go_router.dart';
import '../../features/games/air_hockey/presentation/air_hockey_screen.dart';
import '../../features/games/banana_monkey/presentation/banana_monkey_screen.dart';
import '../../features/games/bowling/presentation/bowling_screen.dart';
import '../../features/games/color_rush/presentation/color_rush_screen.dart';
import '../../features/games/flappy_bird/presentation/flappy_bird_screen.dart';
import '../../features/games/ludo/presentation/ludo_screen.dart';
import '../../features/games/snakes_ladders/presentation/snakes_ladders_screen.dart';
import '../../features/games/stack_animals/presentation/stack_animals_screen.dart';
import '../../features/games/stick_football/presentation/stick_football_screen.dart';
import '../../features/games/street_dash/presentation/street_dash_screen.dart';
import '../../features/games/table_tennis/presentation/table_tennis_screen.dart';
import '../../features/games/tictactoe/presentation/tic_tac_toe_screen.dart';
import '../../features/lobby/presentation/screens/home_screen.dart';
import '../../features/lobby/presentation/screens/match_lobby_screen.dart';

final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const HomeScreen(),
    ),
    GoRoute(
      path: '/lobby/:roomId',
      builder: (context, state) {
        final roomId = state.pathParameters['roomId'] ?? '';
        return MatchLobbyScreen(roomId: roomId);
      },
    ),
    // 1. Tic Tac Toe
    GoRoute(
      path: '/games/tic_tac_toe/:roomId',
      builder: (context, state) {
        final roomId = state.pathParameters['roomId'] ?? 'solo';
        final seat =
            int.tryParse(state.uri.queryParameters['seat'] ?? '0') ?? 0;
        final isSolo =
            state.uri.queryParameters['solo'] == 'true' || roomId == 'solo';
        return TicTacToeScreen(roomId: roomId, localSeat: seat, isSolo: isSolo);
      },
    ),
    // 2. Snakes & Ladders
    GoRoute(
      path: '/games/snakes_and_ladders/:roomId',
      builder: (context, state) {
        final roomId = state.pathParameters['roomId'] ?? 'solo';
        final seat =
            int.tryParse(state.uri.queryParameters['seat'] ?? '0') ?? 0;
        final isSolo =
            state.uri.queryParameters['solo'] == 'true' || roomId == 'solo';
        return SnakesLaddersScreen(
            roomId: roomId, localSeat: seat, isSolo: isSolo);
      },
    ),
    // 3. Ludo
    GoRoute(
      path: '/games/ludo/:roomId',
      builder: (context, state) {
        final roomId = state.pathParameters['roomId'] ?? 'solo';
        final seat =
            int.tryParse(state.uri.queryParameters['seat'] ?? '0') ?? 0;
        final isSolo =
            state.uri.queryParameters['solo'] == 'true' || roomId == 'solo';
        return LudoScreen(roomId: roomId, localSeat: seat, isSolo: isSolo);
      },
    ),
    // 4. Bowling
    GoRoute(
      path: '/games/bowling/:roomId',
      builder: (context, state) {
        final roomId = state.pathParameters['roomId'] ?? 'solo';
        final seat =
            int.tryParse(state.uri.queryParameters['seat'] ?? '0') ?? 0;
        final isSolo =
            state.uri.queryParameters['solo'] == 'true' || roomId == 'solo';
        return BowlingScreen(roomId: roomId, localSeat: seat, isSolo: isSolo);
      },
    ),
    // 5. Flappy Bird
    GoRoute(
      path: '/games/flappy_bird/:roomId',
      builder: (context, state) {
        final roomId = state.pathParameters['roomId'] ?? 'solo';
        final seat =
            int.tryParse(state.uri.queryParameters['seat'] ?? '0') ?? 0;
        final seed =
            int.tryParse(state.uri.queryParameters['seed'] ?? '12345') ?? 12345;
        final isSolo =
            state.uri.queryParameters['solo'] == 'true' || roomId == 'solo';
        return FlappyBirdScreen(
            roomId: roomId, seed: seed, localSeat: seat, isSolo: isSolo);
      },
    ),
    // 6. Table Tennis
    GoRoute(
      path: '/games/table_tennis/:roomId',
      builder: (context, state) {
        final roomId = state.pathParameters['roomId'] ?? 'solo';
        final seat =
            int.tryParse(state.uri.queryParameters['seat'] ?? '0') ?? 0;
        final isSolo =
            state.uri.queryParameters['solo'] == 'true' || roomId == 'solo';
        return TableTennisScreen(
            roomId: roomId, localSeat: seat, isSolo: isSolo);
      },
    ),
    // 7. Air Hockey
    GoRoute(
      path: '/games/air_hockey/:roomId',
      builder: (context, state) {
        final roomId = state.pathParameters['roomId'] ?? 'solo';
        final seat =
            int.tryParse(state.uri.queryParameters['seat'] ?? '0') ?? 0;
        final isHost =
            state.uri.queryParameters['host'] == 'true' || roomId == 'solo';
        final isSolo =
            state.uri.queryParameters['solo'] == 'true' || roomId == 'solo';
        return AirHockeyScreen(
            roomId: roomId, seatIndex: seat, isHost: isHost, isSolo: isSolo);
      },
    ),
    // 8. Stick Football
    GoRoute(
      path: '/games/stick_football/:roomId',
      builder: (context, state) {
        final roomId = state.pathParameters['roomId'] ?? 'solo';
        final seat =
            int.tryParse(state.uri.queryParameters['seat'] ?? '0') ?? 0;
        final isSolo =
            state.uri.queryParameters['solo'] == 'true' || roomId == 'solo';
        return StickFootballScreen(
            roomId: roomId, localSeat: seat, isSolo: isSolo);
      },
    ),
    // 9. Stack Animals
    GoRoute(
      path: '/games/stack_animals/:roomId',
      builder: (context, state) {
        final roomId = state.pathParameters['roomId'] ?? 'solo';
        final seat =
            int.tryParse(state.uri.queryParameters['seat'] ?? '0') ?? 0;
        final isSolo =
            state.uri.queryParameters['solo'] == 'true' || roomId == 'solo';
        return StackAnimalsScreen(
            roomId: roomId, localSeat: seat, isSolo: isSolo);
      },
    ),
    // 10. Banana Monkey
    GoRoute(
      path: '/games/banana_monkey/:roomId',
      builder: (context, state) {
        final roomId = state.pathParameters['roomId'] ?? 'solo';
        final seat =
            int.tryParse(state.uri.queryParameters['seat'] ?? '0') ?? 0;
        final isSolo =
            state.uri.queryParameters['solo'] == 'true' || roomId == 'solo';
        return BananaMonkeyScreen(
            roomId: roomId, localSeat: seat, isSolo: isSolo);
      },
    ),
    // 11. Color Rush
    GoRoute(
      path: '/games/color_rush/:roomId',
      builder: (context, state) {
        final roomId = state.pathParameters['roomId'] ?? 'solo';
        final seat =
            int.tryParse(state.uri.queryParameters['seat'] ?? '0') ?? 0;
        final isSolo =
            state.uri.queryParameters['solo'] == 'true' || roomId == 'solo';
        return ColorRushScreen(roomId: roomId, localSeat: seat, isSolo: isSolo);
      },
    ),
    // 12. Street Dash
    GoRoute(
      path: '/games/street_dash/:roomId',
      builder: (context, state) {
        final roomId = state.pathParameters['roomId'] ?? 'solo';
        final seat =
            int.tryParse(state.uri.queryParameters['seat'] ?? '0') ?? 0;
        final isSolo =
            state.uri.queryParameters['solo'] == 'true' || roomId == 'solo';
        return StreetDashScreen(
            roomId: roomId, localSeat: seat, isSolo: isSolo);
      },
    ),
  ],
);
