import 'dart:async';
import 'package:firebase_database/firebase_database.dart';

class PresenceManager {
  final FirebaseDatabase _database;
  StreamSubscription<DatabaseEvent>? _connectionSubscription;
  String? _activeRoomId;
  String? _activeUid;

  PresenceManager({FirebaseDatabase? database})
      : _database = database ?? FirebaseDatabase.instance;

  void initializeUserPresence(String uid) {
    _activeUid = uid;
    final userStatusRef = _database.ref('presence/$uid');
    final connectedRef = _database.ref('.info/connected');

    _connectionSubscription?.cancel();
    _connectionSubscription = connectedRef.onValue.listen((event) {
      final isConnected = event.snapshot.value as bool? ?? false;
      if (isConnected) {
        // Prepare onDisconnect trigger before updating live state
        userStatusRef.onDisconnect().update({
          'online': false,
          'lastSeen': ServerValue.timestamp,
        });

        userStatusRef.update({
          'online': true,
          'lastSeen': ServerValue.timestamp,
        });

        // If currently in an active room, ensure room seat is hooked to onDisconnect
        if (_activeRoomId != null) {
          _bindRoomDisconnect(_activeRoomId!, uid);
        }
      }
    });
  }

  void bindRoom(String roomId, String uid) {
    _activeRoomId = roomId;
    _activeUid = uid;
    _bindRoomDisconnect(roomId, uid);
  }

  void unbindRoom() {
    if (_activeRoomId != null && _activeUid != null) {
      final playerRef =
          _database.ref('rooms/$_activeRoomId/players/$_activeUid');
      playerRef.onDisconnect().cancel();
      _activeRoomId = null;
    }
  }

  void _bindRoomDisconnect(String roomId, String uid) {
    final playerRef = _database.ref('rooms/$roomId/players/$uid');
    playerRef.onDisconnect().update({
      'isConnected': false,
      'lastPing': ServerValue.timestamp,
    });
  }

  void dispose() {
    _connectionSubscription?.cancel();
    unbindRoom();
  }
}
