import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'core/config/firebase_options.dart';
import 'core/routing/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/data/auth_repository.dart';
import 'features/auth/domain/player_profile.dart';
import 'features/lobby/presentation/deep_link_controller.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Multiplatform Firebase initialization (Web, iOS, Android, Windows)
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint('Firebase initialized in mock/fallback mode for platform: $e');
  }

  runApp(
    const ProviderScope(
      child: ArcadeSuiteApp(),
    ),
  );
}

class ArcadeSuiteApp extends ConsumerStatefulWidget {
  const ArcadeSuiteApp({super.key});

  @override
  ConsumerState<ArcadeSuiteApp> createState() => _ArcadeSuiteAppState();
}

class _ArcadeSuiteAppState extends ConsumerState<ArcadeSuiteApp> {
  StreamSubscription<String>? _deepLinkSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // 1. Initial anonymous guest sign-in on first launch (with safe fallback)
      ref.read(authRepositoryProvider).signInAnonymously().catchError((e) {
        debugPrint('Safe fallback for anonymous auth: $e');
        return PlayerProfile.guest('guest_${DateTime.now().millisecondsSinceEpoch.remainder(10000)}');
      });

      // 2. Initialize Deep Link listener for incoming room invites
      final deepLinkService = ref.read(deepLinkControllerProvider);
      _deepLinkSubscription = deepLinkService.onRoomCodeReceived.listen((roomCode) {
        debugPrint('Deep Link received room code: $roomCode');
        appRouter.push('/lobby/$roomCode');
      });
    });
  }

  @override
  void dispose() {
    _deepLinkSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'GameHub Arcade',
      routerConfig: appRouter,
      theme: AppTheme.darkTheme,
      debugShowCheckedModeBanner: false,
    );
  }
}
