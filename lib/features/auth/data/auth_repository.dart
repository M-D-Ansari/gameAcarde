import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../domain/player_profile.dart';

abstract class AuthRepository {
  Stream<PlayerProfile?> get profileStream;
  PlayerProfile? get currentProfile;
  Future<PlayerProfile> signInAnonymously([String? customName]);
  Future<PlayerProfile> linkWithEmailPassword(String email, String password);
  Future<PlayerProfile> signInWithGoogle();
  Future<void> updateDisplayName(String name);
  Future<void> signOut();
}

class FirebaseAuthRepository implements AuthRepository {
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  FirebaseAuthRepository({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  @override
  PlayerProfile? get currentProfile {
    final user = _auth.currentUser;
    if (user == null) return null;
    return PlayerProfile(
      uid: user.uid,
      displayName: user.displayName ?? user.email?.split('@').first ?? 'Player_${user.uid.substring(0, 4)}',
      avatarUrl: user.photoURL ?? 'https://api.dicebear.com/7.x/bottts/png?seed=${user.uid}',
      email: user.email,
      isAnonymous: user.isAnonymous,
      coins: 500,
      gamesPlayed: 0,
      wins: 0,
      elo: 1000,
    );
  }

  @override
  Stream<PlayerProfile?> get profileStream {
    return _auth.authStateChanges().asyncMap((user) async {
      if (user == null) return null;
      try {
        final doc = await _firestore.collection('users').doc(user.uid).get();
        if (doc.exists && doc.data() != null) {
          return PlayerProfile.fromMap(doc.data()!, user.uid);
        }
        final initialProfile = PlayerProfile(
          uid: user.uid,
          displayName: user.displayName ?? user.email?.split('@').first ?? 'Player_${user.uid.substring(0, 4)}',
          avatarUrl: user.photoURL ?? 'https://api.dicebear.com/7.x/bottts/png?seed=${user.uid}',
          email: user.email,
          isAnonymous: user.isAnonymous,
          coins: 500,
          gamesPlayed: 0,
          wins: 0,
          elo: 1000,
        );
        await _firestore.collection('users').doc(user.uid).set(initialProfile.toMap(), SetOptions(merge: true));
        return initialProfile;
      } catch (e) {
        debugPrint('Firestore profile fetch fallback: $e');
        return PlayerProfile(
          uid: user.uid,
          displayName: user.displayName ?? user.email?.split('@').first ?? 'Player_${user.uid.substring(0, 4)}',
          avatarUrl: user.photoURL ?? 'https://api.dicebear.com/7.x/bottts/png?seed=${user.uid}',
          email: user.email,
          isAnonymous: user.isAnonymous,
          coins: 500,
          gamesPlayed: 0,
          wins: 0,
          elo: 1000,
        );
      }
    });
  }

  @override
  Future<PlayerProfile> signInAnonymously([String? customName]) async {
    try {
      final cred = await _auth.signInAnonymously();
      final uid = cred.user!.uid;
      final name = (customName != null && customName.trim().isNotEmpty)
          ? customName.trim()
          : 'Guest_${uid.length >= 4 ? uid.substring(0, 4) : uid}';

      if (customName != null && customName.trim().isNotEmpty) {
        await cred.user!.updateDisplayName(name);
      }

      final profile = PlayerProfile(
        uid: uid,
        displayName: name,
        avatarUrl: 'https://api.dicebear.com/7.x/bottts/png?seed=$uid',
        email: null,
        isAnonymous: true,
        coins: 500,
        gamesPlayed: 0,
        wins: 0,
        elo: 1000,
      );

      try {
        await _firestore.collection('users').doc(uid).set(profile.toMap(), SetOptions(merge: true));
      } catch (_) {}
      return profile;
    } catch (e) {
      debugPrint('Anonymous auth error fallback: $e');
      final fallbackUid = 'guest_${DateTime.now().millisecondsSinceEpoch.remainder(100000)}';
      final name = (customName != null && customName.trim().isNotEmpty)
          ? customName.trim()
          : 'Guest_${fallbackUid.substring(6)}';

      return PlayerProfile(
        uid: fallbackUid,
        displayName: name,
        avatarUrl: 'https://api.dicebear.com/7.x/bottts/png?seed=$fallbackUid',
        email: null,
        isAnonymous: true,
        coins: 500,
        gamesPlayed: 0,
        wins: 0,
        elo: 1000,
      );
    }
  }

  @override
  Future<void> updateDisplayName(String name) async {
    final user = _auth.currentUser;
    if (user != null) {
      await user.updateDisplayName(name);
      try {
        await _firestore.collection('users').doc(user.uid).set({
          'displayName': name,
        }, SetOptions(merge: true));
      } catch (_) {}
    }
  }

  @override
  Future<PlayerProfile> signInWithGoogle() async {
    UserCredential cred;
    if (kIsWeb) {
      final googleProvider = GoogleAuthProvider();
      googleProvider.addScope('email');
      googleProvider.addScope('profile');
      cred = await _auth.signInWithPopup(googleProvider);
    } else {
      final googleSignIn = GoogleSignIn();
      final googleUser = await googleSignIn.signIn();
      if (googleUser == null) throw Exception('Google sign-in was cancelled');
      final googleAuth = await googleUser.authentication;
      final authCred = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      cred = await _auth.signInWithCredential(authCred);
    }

    final user = cred.user!;
    final profile = PlayerProfile(
      uid: user.uid,
      displayName: user.displayName ?? user.email?.split('@').first ?? 'Arcade_${user.uid.substring(0, 4)}',
      avatarUrl: user.photoURL ?? 'https://api.dicebear.com/7.x/bottts/png?seed=${user.uid}',
      email: user.email,
      isAnonymous: false,
      coins: 500,
      gamesPlayed: 0,
      wins: 0,
      elo: 1000,
    );

    try {
      await _firestore.collection('users').doc(user.uid).set(profile.toMap(), SetOptions(merge: true));
    } catch (e) {
      debugPrint('Firestore profile save error: $e');
    }

    return profile;
  }

  @override
  Future<PlayerProfile> linkWithEmailPassword(String email, String password) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('No authenticated guest user found.');

    final credential = EmailAuthProvider.credential(email: email, password: password);
    final linkResult = await user.linkWithCredential(credential);
    final updatedUid = linkResult.user!.uid;

    final updatedProfile = PlayerProfile(
      uid: updatedUid,
      displayName: email.split('@').first,
      avatarUrl: 'https://api.dicebear.com/7.x/bottts/png?seed=$updatedUid',
      email: email,
      isAnonymous: false,
      coins: 500,
      gamesPlayed: 0,
      wins: 0,
      elo: 1000,
    );

    await _firestore.collection('users').doc(updatedUid).set(updatedProfile.toMap(), SetOptions(merge: true));
    return updatedProfile;
  }

  @override
  Future<void> signOut() async {
    await _auth.signOut();
  }
}

// In-Memory Mock Repository for automated tests and offline preview
class MockAuthRepository implements AuthRepository {
  final _controller = StreamController<PlayerProfile?>.broadcast();
  PlayerProfile? _profile;

  MockAuthRepository([PlayerProfile? initial]) {
    _profile = initial ?? PlayerProfile.guest('mock_user_001');
    _controller.add(_profile);
  }

  @override
  Stream<PlayerProfile?> get profileStream => _controller.stream;

  @override
  PlayerProfile? get currentProfile => _profile;

  @override
  Future<PlayerProfile> signInAnonymously([String? customName]) async {
    final uid = 'guest_mock_${DateTime.now().millisecondsSinceEpoch % 10000}';
    final name = (customName != null && customName.trim().isNotEmpty)
        ? customName.trim()
        : 'Guest_${uid.substring(uid.length - 4)}';

    _profile = PlayerProfile(
      uid: uid,
      displayName: name,
      avatarUrl: 'https://api.dicebear.com/7.x/bottts/png?seed=$uid',
      email: null,
      isAnonymous: true,
      coins: 500,
      gamesPlayed: 0,
      wins: 0,
      elo: 1000,
    );
    _controller.add(_profile);
    return _profile!;
  }

  @override
  Future<void> updateDisplayName(String name) async {
    if (_profile != null) {
      _profile = _profile!.copyWith(displayName: name);
      _controller.add(_profile);
    }
  }

  @override
  Future<PlayerProfile> signInWithGoogle() async {
    _profile = const PlayerProfile(
      uid: 'google_user_001',
      displayName: 'Google Arcade Pro',
      avatarUrl: 'https://api.dicebear.com/7.x/bottts/png?seed=google_user_001',
      email: 'arcade.pro@gmail.com',
      isAnonymous: false,
      coins: 1000,
      gamesPlayed: 12,
      wins: 9,
      elo: 1250,
    );
    _controller.add(_profile);
    return _profile!;
  }

  @override
  Future<PlayerProfile> linkWithEmailPassword(String email, String password) async {
    if (_profile == null) throw Exception('No guest session');
    _profile = _profile!.copyWith(
      email: email,
      displayName: email.split('@').first,
      isAnonymous: false,
    );
    _controller.add(_profile);
    return _profile!;
  }

  @override
  Future<void> signOut() async {
    _profile = null;
    _controller.add(null);
  }
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  try {
    return FirebaseAuthRepository();
  } catch (_) {
    return MockAuthRepository();
  }
});

final authStateProvider = StreamProvider<PlayerProfile?>((ref) {
  final repo = ref.watch(authRepositoryProvider);
  return repo.profileStream;
});
