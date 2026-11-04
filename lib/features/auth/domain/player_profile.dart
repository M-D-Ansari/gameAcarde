import 'package:flutter/foundation.dart';

@immutable
class PlayerProfile {
  final String uid;
  final String displayName;
  final String avatarUrl;
  final String? email;
  final bool isAnonymous;
  final int coins;
  final int gamesPlayed;
  final int wins;
  final int elo;

  const PlayerProfile({
    required this.uid,
    required this.displayName,
    required this.avatarUrl,
    this.email,
    required this.isAnonymous,
    required this.coins,
    required this.gamesPlayed,
    required this.wins,
    required this.elo,
  });

  double get winRate => gamesPlayed == 0 ? 0.0 : (wins / gamesPlayed);

  PlayerProfile copyWith({
    String? uid,
    String? displayName,
    String? avatarUrl,
    String? email,
    bool? isAnonymous,
    int? coins,
    int? gamesPlayed,
    int? wins,
    int? elo,
  }) {
    return PlayerProfile(
      uid: uid ?? this.uid,
      displayName: displayName ?? this.displayName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      email: email ?? this.email,
      isAnonymous: isAnonymous ?? this.isAnonymous,
      coins: coins ?? this.coins,
      gamesPlayed: gamesPlayed ?? this.gamesPlayed,
      wins: wins ?? this.wins,
      elo: elo ?? this.elo,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'displayName': displayName,
      'avatarUrl': avatarUrl,
      'email': email,
      'isAnonymous': isAnonymous,
      'coins': coins,
      'gamesPlayed': gamesPlayed,
      'wins': wins,
      'elo': elo,
    };
  }

  factory PlayerProfile.fromMap(Map<String, dynamic> map, String uid) {
    return PlayerProfile(
      uid: uid,
      displayName: map['displayName'] as String? ?? 'Player_${uid.substring(0, 4)}',
      avatarUrl: map['avatarUrl'] as String? ?? 'https://api.dicebear.com/7.x/bottts/png?seed=$uid',
      email: map['email'] as String?,
      isAnonymous: map['isAnonymous'] as bool? ?? true,
      coins: (map['coins'] as num?)?.toInt() ?? 500,
      gamesPlayed: (map['gamesPlayed'] as num?)?.toInt() ?? 0,
      wins: (map['wins'] as num?)?.toInt() ?? 0,
      elo: (map['elo'] as num?)?.toInt() ?? 1000,
    );
  }

  factory PlayerProfile.guest(String uid) {
    return PlayerProfile(
      uid: uid,
      displayName: 'Guest_${uid.length >= 4 ? uid.substring(0, 4) : uid}',
      avatarUrl: 'https://api.dicebear.com/7.x/bottts/png?seed=$uid',
      isAnonymous: true,
      coins: 500,
      gamesPlayed: 0,
      wins: 0,
      elo: 1000,
    );
  }
}

