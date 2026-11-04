import 'package:flutter/foundation.dart';
import '../../../core/constants/game_types.dart';

enum RoomStatus {
  waiting,
  inProgress,
  finished,
}

@immutable
class RoomPlayer {
  final String uid;
  final int seatIndex;
  final String displayName;
  final String avatarUrl;
  final bool isHost;
  final bool isReady;
  final bool isConnected;
  final int lastPing;

  const RoomPlayer({
    required this.uid,
    required this.seatIndex,
    required this.displayName,
    required this.avatarUrl,
    required this.isHost,
    required this.isReady,
    required this.isConnected,
    required this.lastPing,
  });

  RoomPlayer copyWith({
    String? uid,
    int? seatIndex,
    String? displayName,
    String? avatarUrl,
    bool? isHost,
    bool? isReady,
    bool? isConnected,
    int? lastPing,
  }) {
    return RoomPlayer(
      uid: uid ?? this.uid,
      seatIndex: seatIndex ?? this.seatIndex,
      displayName: displayName ?? this.displayName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      isHost: isHost ?? this.isHost,
      isReady: isReady ?? this.isReady,
      isConnected: isConnected ?? this.isConnected,
      lastPing: lastPing ?? this.lastPing,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'seatIndex': seatIndex,
      'displayName': displayName,
      'avatarUrl': avatarUrl,
      'isHost': isHost,
      'isReady': isReady,
      'isConnected': isConnected,
      'lastPing': lastPing,
    };
  }

  factory RoomPlayer.fromMap(Map<dynamic, dynamic> map, String uid) {
    return RoomPlayer(
      uid: uid,
      seatIndex: (map['seatIndex'] as num?)?.toInt() ?? 0,
      displayName: map['displayName'] as String? ?? 'Player',
      avatarUrl: map['avatarUrl'] as String? ?? '',
      isHost: map['isHost'] as bool? ?? false,
      isReady: map['isReady'] as bool? ?? false,
      isConnected: map['isConnected'] as bool? ?? true,
      lastPing: (map['lastPing'] as num?)?.toInt() ?? 0,
    );
  }
}

@immutable
class RoomMeta {
  final String roomId;
  final GameType gameType;
  final RoomStatus status;
  final bool isPrivate;
  final String? passcode;
  final String hostUid;
  final int seed;
  final int createdAt;
  final int? startedAt;

  const RoomMeta({
    required this.roomId,
    required this.gameType,
    required this.status,
    required this.isPrivate,
    this.passcode,
    required this.hostUid,
    required this.seed,
    required this.createdAt,
    this.startedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'roomId': roomId,
      'gameType': gameType.id,
      'status': status.name,
      'isPrivate': isPrivate,
      'passcode': passcode,
      'hostUid': hostUid,
      'seed': seed,
      'createdAt': createdAt,
      'startedAt': startedAt,
    };
  }

  factory RoomMeta.fromMap(Map<dynamic, dynamic> map) {
    final statusStr = map['status'] as String? ?? 'waiting';
    return RoomMeta(
      roomId: map['roomId'] as String? ?? '',
      gameType: GameType.fromId(map['gameType'] as String? ?? 'ludo'),
      status: RoomStatus.values.firstWhere(
        (s) => s.name == statusStr,
        orElse: () => RoomStatus.waiting,
      ),
      isPrivate: map['isPrivate'] as bool? ?? false,
      passcode: map['passcode'] as String?,
      hostUid: map['hostUid'] as String? ?? '',
      seed: (map['seed'] as num?)?.toInt() ?? 123456,
      createdAt: (map['createdAt'] as num?)?.toInt() ?? 0,
      startedAt: (map['startedAt'] as num?)?.toInt(),
    );
  }
}

@immutable
class RoomModel {
  final RoomMeta meta;
  final Map<String, RoomPlayer> players;

  const RoomModel({
    required this.meta,
    required this.players,
  });

  bool get isFull => players.length >= meta.gameType.maxPlayers;
  bool get canStart => players.length >= 2 && players.values.every((p) => p.isReady || p.isHost);

  factory RoomModel.fromRTDB(Map<dynamic, dynamic> map) {
    final metaMap = map['meta'] as Map<dynamic, dynamic>? ?? {};
    final playersMap = map['players'] as Map<dynamic, dynamic>? ?? {};

    final Map<String, RoomPlayer> parsedPlayers = {};
    playersMap.forEach((uid, pData) {
      if (pData is Map) {
        parsedPlayers[uid.toString()] = RoomPlayer.fromMap(pData, uid.toString());
      }
    });

    return RoomModel(
      meta: RoomMeta.fromMap(metaMap),
      players: parsedPlayers,
    );
  }
}

