import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final deepLinkControllerProvider = Provider<DeepLinkController>((ref) {
  final controller = DeepLinkController();
  ref.onDispose(() => controller.dispose());
  return controller;
});

class DeepLinkController {
  late final AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSubscription;
  final _targetRoomCodeController = StreamController<String>.broadcast();

  Stream<String> get onRoomCodeReceived => _targetRoomCodeController.stream;

  DeepLinkController() {
    _appLinks = AppLinks();
    _initDeepLinks();
  }

  Future<void> _initDeepLinks() async {
    try {
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        _handleUri(initialUri);
      }
    } catch (e) {
      debugPrint('Deep Link cold-boot parse error: $e');
    }

    _linkSubscription = _appLinks.uriLinkStream.listen(
      (uri) => _handleUri(uri),
      onError: (err) => debugPrint('Deep Link stream exception: $err'),
    );
  }

  void _handleUri(Uri uri) {
    debugPrint('Received Deep Link payload: $uri');

    // Handles:
    // https://gamehub.app/join?code=XYZ123
    // gamehub://join?code=XYZ123
    // gamehub://join/XYZ123
    String? code = uri.queryParameters['code'];
    if (code == null && uri.pathSegments.isNotEmpty) {
      code = uri.pathSegments.last;
    }

    if (code != null && code.trim().length >= 4) {
      _targetRoomCodeController.add(code.trim().toUpperCase());
    }
  }

  void dispose() {
    _linkSubscription?.cancel();
    _targetRoomCodeController.close();
  }
}

