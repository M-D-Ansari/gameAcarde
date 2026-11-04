import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Ultra-Low Latency Centralized Multiplayer Streaming Service.
/// Eliminates document write-contention and lock serialization by allocating
/// independent subcollection streaming channels for each player seat and physics authority:
/// - /rooms/{roomId}/stream/physics   -> Authoritative puck/ball/score stream (Host -> Guest)
/// - /rooms/{roomId}/stream/seat_0   -> Player 1 (Host) live paddle/telemetry stream
/// - /rooms/{roomId}/stream/seat_1   -> Player 2 (Guest) live paddle/telemetry stream
/// - /rooms/{roomId}/stream/seat_2   -> Player 3 live stream
/// - /rooms/{roomId}/stream/seat_3   -> Player 4 live stream
/// - /rooms/{roomId}/stream/game_state -> Instant turn-based / discrete state sync
class MultiplayerSyncService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Dedicated low-latency channel stream listener (subcollection /rooms/{roomId}/stream/{channelId})
  static Stream<Map<String, dynamic>?> watchChannel(String roomId, String channelId) {
    if (roomId == 'solo') return const Stream.empty();
    return _firestore
        .collection('rooms')
        .doc(roomId)
        .collection('stream')
        .doc(channelId)
        .snapshots(includeMetadataChanges: false)
        .map((doc) => doc.exists ? doc.data() : null)
        .handleError((e) {
          debugPrint('watchChannel error ($channelId) for $roomId: $e');
        });
  }

  /// Write directly to a dedicated low-latency channel (subcollection /rooms/{roomId}/stream/{channelId})
  static Future<void> updateChannel(String roomId, String channelId, Map<String, dynamic> data) async {
    if (roomId == 'solo') return;
    try {
      await _firestore
          .collection('rooms')
          .doc(roomId)
          .collection('stream')
          .doc(channelId)
          .set(data, SetOptions(merge: true));
    } catch (e) {
      debugPrint('updateChannel error ($channelId) for $roomId: $e');
    }
  }

  /// Watch specific seat stream (e.g. opponent's paddle, ghost bird, distance, score)
  static Stream<Map<String, dynamic>?> watchSeatStream(String roomId, int seatIndex) {
    return watchChannel(roomId, 'seat_$seatIndex');
  }

  /// Send local seat telemetry (paddle, distance, score, inputs)
  static Future<void> updateSeatStream(String roomId, int seatIndex, Map<String, dynamic> data) {
    return updateChannel(roomId, 'seat_$seatIndex', data);
  }

  /// Authoritative Physics Channel (Host -> Guests) for pucks, balls, score sync
  static Stream<Map<String, dynamic>?> watchPhysicsStream(String roomId) {
    return watchChannel(roomId, 'physics');
  }

  /// Send authoritative physics telemetry from Host
  static Future<void> updatePhysicsStream(String roomId, Map<String, dynamic> data) {
    return updateChannel(roomId, 'physics', data);
  }

  /// Watch live turn-based or discrete game state
  static Stream<Map<String, dynamic>?> watchGameState(String roomId) {
    if (roomId == 'solo') return const Stream.empty();
    return _firestore
        .collection('rooms')
        .doc(roomId)
        .collection('stream')
        .doc('game_state')
        .snapshots(includeMetadataChanges: false)
        .map((doc) => doc.exists ? doc.data() : null)
        .handleError((e) {
          debugPrint('watchGameState error for $roomId: $e');
        });
  }

  /// Update turn-based or discrete game state (writing to stream/game_state and parent doc for lobby)
  static Future<void> updateGameState(String roomId, Map<String, dynamic> state) async {
    if (roomId == 'solo') return;
    try {
      await updateChannel(roomId, 'game_state', state);
      // Non-blocking update to parent doc for room history & lobby state
      _firestore.collection('rooms').doc(roomId).set({
        'gameState': state,
      }, SetOptions(merge: true)).catchError((_) {});
    } catch (e) {
      debugPrint('updateGameState error for $roomId: $e');
    }
  }

  /// Watch fast-tick real-time sync (backward compatible channel)
  static Stream<Map<String, dynamic>?> watchRealtimeSync(String roomId) {
    if (roomId == 'solo') return const Stream.empty();
    return watchChannel(roomId, 'realtime');
  }

  /// Update fast-tick real-time sync (backward compatible channel)
  static Future<void> updateRealtimeSync(String roomId, Map<String, dynamic> syncData) async {
    if (roomId == 'solo') return;
    try {
      await updateChannel(roomId, 'realtime', syncData);
    } catch (e) {
      debugPrint('updateRealtimeSync error for $roomId: $e');
    }
  }
}
