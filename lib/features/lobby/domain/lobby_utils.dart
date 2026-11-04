class LobbyUtils {
  /// Cleanly extracts a room code whether the user pastes a raw code or an invite URL.
  static String extractRoomCode(String input) {
    final clean = input.trim();
    if (clean.contains('lobby/')) {
      final after = clean.split('lobby/').last;
      return after.split('?').first.split('/').first.trim().toUpperCase();
    }
    if (clean.contains('code=')) {
      try {
        final uri = Uri.parse(clean);
        final code = uri.queryParameters['code'];
        if (code != null && code.isNotEmpty) {
          return code.trim().toUpperCase();
        }
      } catch (_) {}
    }
    return clean.replaceAll(RegExp(r'[^A-Za-z0-9]'), '').toUpperCase();
  }

  /// Builds the canonical web invite link for a given room code.
  static String buildInviteLink(String roomCode) {
    return 'https://gamehub-arcade-987.web.app/#/lobby/$roomCode';
  }
}

