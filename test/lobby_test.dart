import 'package:flutter_test/flutter_test.dart';
import 'package:mini_arcade_hub/core/constants/game_types.dart';
import 'package:mini_arcade_hub/features/auth/domain/player_profile.dart';
import 'package:mini_arcade_hub/features/lobby/data/lobby_repository.dart';
import 'package:mini_arcade_hub/features/lobby/domain/lobby_utils.dart';

void main() {
  group('Lobby Creation & Matchmaking Unit Tests', () {
    late MockLobbyRepository repository;
    late PlayerProfile hostUser;
    late PlayerProfile guestUser1;
    late PlayerProfile guestUser2;

    setUp(() {
      repository = MockLobbyRepository();
      hostUser = const PlayerProfile(
        uid: 'host_001',
        displayName: 'HostPlayer',
        avatarUrl: '',
        isAnonymous: true,
        coins: 500,
        gamesPlayed: 10,
        wins: 6,
        elo: 1100,
      );
      guestUser1 = const PlayerProfile(
        uid: 'guest_002',
        displayName: 'GuestOne',
        avatarUrl: '',
        isAnonymous: true,
        coins: 500,
        gamesPlayed: 5,
        wins: 2,
        elo: 1050,
      );
      guestUser2 = const PlayerProfile(
        uid: 'guest_003',
        displayName: 'GuestTwo',
        avatarUrl: '',
        isAnonymous: true,
        coins: 500,
        gamesPlayed: 8,
        wins: 4,
        elo: 1080,
      );
    });

    test('Creating a room generates a valid room code and assigns host to Seat 0', () async {
      final roomId = await repository.createRoom(
        gameType: GameType.airHockey,
        host: hostUser,
      );

      expect(roomId, isNotEmpty);
      expect(roomId.length, greaterThanOrEqualTo(4));

      final room = await repository.watchRoom(roomId).first;
      expect(room, isNotNull);
      expect(room!.meta.roomId, equals(roomId));
      expect(room.meta.hostUid, equals(hostUser.uid));
      expect(room.players.containsKey(hostUser.uid), isTrue);
      expect(room.players[hostUser.uid]!.seatIndex, equals(0));
      expect(room.players[hostUser.uid]!.isHost, isTrue);
    });

    test('Guest joining gets assigned next available seat index', () async {
      final roomId = await repository.createRoom(
        gameType: GameType.ludo,
        host: hostUser,
      );

      // Guest 1 joins
      await repository.joinRoom(roomId: roomId, player: guestUser1);

      var room = await repository.watchRoom(roomId).first;
      expect(room!.players.length, equals(2));
      expect(room.players[guestUser1.uid]!.seatIndex, equals(1));
      expect(room.players[guestUser1.uid]!.isHost, isFalse);

      // Guest 2 joins
      await repository.joinRoom(roomId: roomId, player: guestUser2);

      room = await repository.watchRoom(roomId).first;
      expect(room!.players.length, equals(3));
      expect(room.players[guestUser2.uid]!.seatIndex, equals(2));
    });

    test('Toggle ready updates player state and validates canStart', () async {
      final roomId = await repository.createRoom(
        gameType: GameType.airHockey,
        host: hostUser,
      );
      await repository.joinRoom(roomId: roomId, player: guestUser1);

      var room = await repository.watchRoom(roomId).first;
      expect(room!.players[guestUser1.uid]!.isReady, isFalse);
      expect(room.canStart, isFalse);

      // Guest toggles ready
      await repository.toggleReady(roomId: roomId, uid: guestUser1.uid, isReady: true);

      room = await repository.watchRoom(roomId).first;
      expect(room!.players[guestUser1.uid]!.isReady, isTrue);
      expect(room.canStart, isTrue);
    });

    test('Room Link Code Extraction logic handles both links and raw codes', () {
      expect(LobbyUtils.extractRoomCode('XYZ123'), equals('XYZ123'));
      expect(LobbyUtils.extractRoomCode('  abc789  '), equals('ABC789'));
      expect(LobbyUtils.extractRoomCode('https://gamehub-arcade-987.web.app/#/lobby/ARCADE'), equals('ARCADE'));
      expect(LobbyUtils.extractRoomCode('https://gamehub-arcade-987.web.app/#/lobby/ROOM99/'), equals('ROOM99'));
      expect(LobbyUtils.extractRoomCode('https://gamehub-arcade-987.web.app/#/lobby/ROOM88?seat=1'), equals('ROOM88'));
      expect(LobbyUtils.extractRoomCode('https://gamehub-arcade-987.web.app/join?code=DUEL99'), equals('DUEL99'));

      final link = LobbyUtils.buildInviteLink('TEST55');
      expect(link, equals('https://gamehub-arcade-987.web.app/#/lobby/TEST55'));
    });
  });
}
