import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/game_types.dart';
import '../../auth/domain/player_profile.dart';
import '../domain/room_model.dart';

abstract class LobbyRepository {
  Stream<RoomModel?> watchRoom(String roomId);
  Future<String> createRoom({
    required GameType gameType,
    required PlayerProfile host,
    bool isPrivate = false,
    String? passcode,
  });
  Future<void> joinRoom({
    required String roomId,
    required PlayerProfile player,
    String? passcode,
  });
  Future<void> toggleReady({
    required String roomId,
    required String uid,
    required bool isReady,
  });
  Future<void> kickPlayer({
    required String roomId,
    required String targetUid,
  });
  Future<void> startMatch(String roomId);
  Future<void> leaveRoom({
    required String roomId,
    required String uid,
  });
}

/// Production Firestore Lobby Repository for cross-platform real-time sync
class FirestoreLobbyRepository implements LobbyRepository {
  final FirebaseFirestore _firestore;

  FirestoreLobbyRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  String _generateRoomCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // Unambiguous chars
    final rng = Random();
    return List.generate(6, (_) => chars[rng.nextInt(chars.length)]).join();
  }

  @override
  Stream<RoomModel?> watchRoom(String roomId) {
    return _firestore.collection('rooms').doc(roomId).snapshots().map((doc) {
      if (!doc.exists || doc.data() == null) return null;
      return RoomModel.fromRTDB(doc.data()!);
    });
  }

  @override
  Future<String> createRoom({
    required GameType gameType,
    required PlayerProfile host,
    bool isPrivate = false,
    String? passcode,
  }) async {
    final roomId = _generateRoomCode();
    final seed = Random().nextInt(1000000000);
    final now = DateTime.now().millisecondsSinceEpoch;

    final meta = RoomMeta(
      roomId: roomId,
      gameType: gameType,
      status: RoomStatus.waiting,
      isPrivate: isPrivate,
      passcode: passcode,
      hostUid: host.uid,
      seed: seed,
      createdAt: now,
    );

    final hostPlayer = RoomPlayer(
      uid: host.uid,
      seatIndex: 0,
      displayName: host.displayName,
      avatarUrl: host.avatarUrl,
      isHost: true,
      isReady: true,
      isConnected: true,
      lastPing: now,
    );

    final roomDoc = _firestore.collection('rooms').doc(roomId);
    await roomDoc.set({
      'meta': meta.toMap(),
      'players': {
        host.uid: hostPlayer.toMap(),
      },
    });

    return roomId;
  }

  @override
  Future<void> joinRoom({
    required String roomId,
    required PlayerProfile player,
    String? passcode,
  }) async {
    final roomDoc = _firestore.collection('rooms').doc(roomId);
    final snapshot = await roomDoc.get();
    if (!snapshot.exists || snapshot.data() == null) {
      throw Exception('Room $roomId does not exist');
    }

    final room = RoomModel.fromRTDB(snapshot.data()!);
    if (room.isFull && !room.players.containsKey(player.uid)) {
      throw Exception('Room is full (maximum ${room.meta.gameType.maxPlayers} players)');
    }
    if (room.meta.status != RoomStatus.waiting) {
      throw Exception('Game already started');
    }

    int seat = 0;
    final takenSeats = room.players.values.map((p) => p.seatIndex).toSet();
    while (takenSeats.contains(seat) && seat < room.meta.gameType.maxPlayers) {
      seat++;
    }

    final newPlayer = RoomPlayer(
      uid: player.uid,
      seatIndex: seat,
      displayName: player.displayName,
      avatarUrl: player.avatarUrl,
      isHost: false,
      isReady: false,
      isConnected: true,
      lastPing: DateTime.now().millisecondsSinceEpoch,
    );

    await roomDoc.update({
      'players.${player.uid}': newPlayer.toMap(),
    });
  }

  @override
  Future<void> toggleReady({
    required String roomId,
    required String uid,
    required bool isReady,
  }) async {
    await _firestore.collection('rooms').doc(roomId).update({
      'players.$uid.isReady': isReady,
    });
  }

  @override
  Future<void> kickPlayer({
    required String roomId,
    required String targetUid,
  }) async {
    await _firestore.collection('rooms').doc(roomId).update({
      'players.$targetUid': FieldValue.delete(),
    });
  }

  @override
  Future<void> startMatch(String roomId) async {
    await _firestore.collection('rooms').doc(roomId).update({
      'meta.status': RoomStatus.inProgress.name,
      'meta.startedAt': DateTime.now().millisecondsSinceEpoch,
    });
  }

  @override
  Future<void> leaveRoom({
    required String roomId,
    required String uid,
  }) async {
    final roomDoc = _firestore.collection('rooms').doc(roomId);
    final snap = await roomDoc.get();
    if (!snap.exists || snap.data() == null) return;
    final room = RoomModel.fromRTDB(snap.data()!);
    if (room.meta.hostUid == uid) {
      await roomDoc.delete();
    } else {
      await roomDoc.update({
        'players.$uid': FieldValue.delete(),
      });
    }
  }
}

/// RTDB Repository as secondary option
class FirebaseLobbyRepository implements LobbyRepository {
  final FirebaseDatabase _database;

  FirebaseLobbyRepository({FirebaseDatabase? database})
      : _database = database ?? FirebaseDatabase.instance;

  String _generateRoomCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rng = Random();
    return List.generate(6, (_) => chars[rng.nextInt(chars.length)]).join();
  }

  @override
  Stream<RoomModel?> watchRoom(String roomId) {
    return _database.ref('rooms/$roomId').onValue.map((event) {
      if (!event.snapshot.exists || event.snapshot.value == null) return null;
      final data = event.snapshot.value as Map<dynamic, dynamic>;
      return RoomModel.fromRTDB(data);
    });
  }

  @override
  Future<String> createRoom({
    required GameType gameType,
    required PlayerProfile host,
    bool isPrivate = false,
    String? passcode,
  }) async {
    final roomId = _generateRoomCode();
    final seed = Random().nextInt(1000000000);
    final now = DateTime.now().millisecondsSinceEpoch;

    final meta = RoomMeta(
      roomId: roomId,
      gameType: gameType,
      status: RoomStatus.waiting,
      isPrivate: isPrivate,
      passcode: passcode,
      hostUid: host.uid,
      seed: seed,
      createdAt: now,
    );

    final hostPlayer = RoomPlayer(
      uid: host.uid,
      seatIndex: 0,
      displayName: host.displayName,
      avatarUrl: host.avatarUrl,
      isHost: true,
      isReady: true,
      isConnected: true,
      lastPing: now,
    );

    final roomRef = _database.ref('rooms/$roomId');
    await roomRef.set({
      'meta': meta.toMap(),
      'players': {
        host.uid: hostPlayer.toMap(),
      },
    });

    return roomId;
  }

  @override
  Future<void> joinRoom({
    required String roomId,
    required PlayerProfile player,
    String? passcode,
  }) async {
    final roomRef = _database.ref('rooms/$roomId');
    final snapshot = await roomRef.get();
    if (!snapshot.exists || snapshot.value == null) {
      throw Exception('Room does not exist');
    }

    final data = snapshot.value as Map<dynamic, dynamic>;
    final room = RoomModel.fromRTDB(data);

    if (room.isFull && !room.players.containsKey(player.uid)) {
      throw Exception('Room is full');
    }
    if (room.meta.status != RoomStatus.waiting) {
      throw Exception('Game already in progress');
    }

    int seat = 0;
    final takenSeats = room.players.values.map((p) => p.seatIndex).toSet();
    while (takenSeats.contains(seat) && seat < room.meta.gameType.maxPlayers) {
      seat++;
    }

    final newPlayer = RoomPlayer(
      uid: player.uid,
      seatIndex: seat,
      displayName: player.displayName,
      avatarUrl: player.avatarUrl,
      isHost: false,
      isReady: false,
      isConnected: true,
      lastPing: DateTime.now().millisecondsSinceEpoch,
    );

    await roomRef.child('players/${player.uid}').set(newPlayer.toMap());
  }

  @override
  Future<void> toggleReady({
    required String roomId,
    required String uid,
    required bool isReady,
  }) async {
    await _database.ref('rooms/$roomId/players/$uid/isReady').set(isReady);
  }

  @override
  Future<void> kickPlayer({
    required String roomId,
    required String targetUid,
  }) async {
    await _database.ref('rooms/$roomId/players/$targetUid').remove();
  }

  @override
  Future<void> startMatch(String roomId) async {
    final updates = {
      'meta/status': RoomStatus.inProgress.name,
      'meta/startedAt': DateTime.now().millisecondsSinceEpoch,
    };
    await _database.ref('rooms/$roomId').update(updates);
  }

  @override
  Future<void> leaveRoom({
    required String roomId,
    required String uid,
  }) async {
    final roomRef = _database.ref('rooms/$roomId');
    final snapshot = await roomRef.get();
    if (!snapshot.exists || snapshot.value == null) return;

    final room = RoomModel.fromRTDB(snapshot.value as Map<dynamic, dynamic>);
    if (room.meta.hostUid == uid) {
      await roomRef.remove();
    } else {
      await roomRef.child('players/$uid').remove();
    }
  }
}

// In-Memory Mock Repository for automated tests and offline preview
class MockLobbyRepository implements LobbyRepository {
  final Map<String, RoomModel> _rooms = {};
  final Map<String, StreamController<RoomModel?>> _controllers = {};

  StreamController<RoomModel?> _getController(String roomId) {
    return _controllers.putIfAbsent(
      roomId,
      () => StreamController<RoomModel?>.broadcast(),
    );
  }

  @override
  Stream<RoomModel?> watchRoom(String roomId) {
    final controller = _getController(roomId);
    Future.microtask(() => controller.add(_rooms[roomId]));
    return controller.stream;
  }

  @override
  Future<String> createRoom({
    required GameType gameType,
    required PlayerProfile host,
    bool isPrivate = false,
    String? passcode,
  }) async {
    final roomId = 'TEST${Random().nextInt(90) + 10}';
    final meta = RoomMeta(
      roomId: roomId,
      gameType: gameType,
      status: RoomStatus.waiting,
      isPrivate: isPrivate,
      passcode: passcode,
      hostUid: host.uid,
      seed: 42,
      createdAt: DateTime.now().millisecondsSinceEpoch,
    );
    final hostPlayer = RoomPlayer(
      uid: host.uid,
      seatIndex: 0,
      displayName: host.displayName,
      avatarUrl: host.avatarUrl,
      isHost: true,
      isReady: true,
      isConnected: true,
      lastPing: DateTime.now().millisecondsSinceEpoch,
    );

    final room = RoomModel(
      meta: meta,
      players: {host.uid: hostPlayer},
    );

    _rooms[roomId] = room;
    _getController(roomId).add(room);
    return roomId;
  }

  @override
  Future<void> joinRoom({
    required String roomId,
    required PlayerProfile player,
    String? passcode,
  }) async {
    final room = _rooms[roomId];
    if (room == null) throw Exception('Room not found');

    int seat = 0;
    final taken = room.players.values.map((p) => p.seatIndex).toSet();
    while (taken.contains(seat) && seat < room.meta.gameType.maxPlayers) {
      seat++;
    }

    final newPlayer = RoomPlayer(
      uid: player.uid,
      seatIndex: seat,
      displayName: player.displayName,
      avatarUrl: player.avatarUrl,
      isHost: false,
      isReady: false,
      isConnected: true,
      lastPing: DateTime.now().millisecondsSinceEpoch,
    );

    final updated = Map<String, RoomPlayer>.from(room.players)
      ..[player.uid] = newPlayer;
    _rooms[roomId] = RoomModel(meta: room.meta, players: updated);
    _getController(roomId).add(_rooms[roomId]);
  }

  @override
  Future<void> toggleReady({
    required String roomId,
    required String uid,
    required bool isReady,
  }) async {
    final room = _rooms[roomId];
    if (room == null || !room.players.containsKey(uid)) return;
    final updatedPlayers = Map<String, RoomPlayer>.from(room.players);
    updatedPlayers[uid] = updatedPlayers[uid]!.copyWith(isReady: isReady);
    _rooms[roomId] = RoomModel(meta: room.meta, players: updatedPlayers);
    _getController(roomId).add(_rooms[roomId]);
  }

  @override
  Future<void> kickPlayer({required String roomId, required String targetUid}) async {
    final room = _rooms[roomId];
    if (room == null) return;
    final updated = Map<String, RoomPlayer>.from(room.players)..remove(targetUid);
    _rooms[roomId] = RoomModel(meta: room.meta, players: updated);
    _getController(roomId).add(_rooms[roomId]);
  }

  @override
  Future<void> startMatch(String roomId) async {
    final room = _rooms[roomId];
    if (room == null) return;
    final updatedMeta = RoomMeta(
      roomId: room.meta.roomId,
      gameType: room.meta.gameType,
      status: RoomStatus.inProgress,
      isPrivate: room.meta.isPrivate,
      hostUid: room.meta.hostUid,
      seed: room.meta.seed,
      createdAt: room.meta.createdAt,
      startedAt: DateTime.now().millisecondsSinceEpoch,
    );
    _rooms[roomId] = RoomModel(meta: updatedMeta, players: room.players);
    _getController(roomId).add(_rooms[roomId]);
  }

  @override
  Future<void> leaveRoom({required String roomId, required String uid}) async {
    final room = _rooms[roomId];
    if (room == null) return;
    final updated = Map<String, RoomPlayer>.from(room.players)..remove(uid);
    _rooms[roomId] = RoomModel(meta: room.meta, players: updated);
    _getController(roomId).add(_rooms[roomId]);
  }
}

final lobbyRepositoryProvider = Provider<LobbyRepository>((ref) {
  try {
    return FirestoreLobbyRepository();
  } catch (e) {
    debugPrint('Using mock lobby repository fallback: $e');
    return MockLobbyRepository();
  }
});

final roomStreamProvider =
    StreamProvider.autoDispose.family<RoomModel?, String>((ref, roomId) {
  final repo = ref.watch(lobbyRepositoryProvider);
  return repo.watchRoom(roomId);
});
