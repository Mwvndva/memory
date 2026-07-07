// Central configuration for API endpoints and feature flags.
//
// For local Android emulator development, use 10.0.2.2 which maps to the
// host machine's localhost. For a physical device or production, update
// [kBaseUrl] to your server's public address.
// ---------------------------------------------------------------------------
// Endpoint configuration
// ---------------------------------------------------------------------------

// Base HTTP URL of the NestJS backend.
// Provide at build/run time using --dart-define=API_URL and --dart-define=WS_URL.
// Android emulator maps 10.0.2.2 → host localhost when developing locally.

//DEVELOPMENT
// const String kBaseUrl = String.fromEnvironment(
// 	'API_URL',
// 	defaultValue: 'http://localhost:3000',
// );

// /// WebSocket endpoint used by the chat/notification layer. Provide using
// /// --dart-define=WS_URL; default points to local emulator.
// const String kWebSocketUrl = String.fromEnvironment(
// 	'WS_URL',
// 	defaultValue: 'ws://localhost:3000/ws',
// );
const String kBaseUrl = String.fromEnvironment(
	'API_URL',
	defaultValue: 'https://api.mymemoriestoday.site',
);

const String kWebSocketUrl = String.fromEnvironment(
	'WS_URL',
	defaultValue: 'wss://api.mymemoriestoday.site/ws',
);


// ---------------------------------------------------------------------------
// Feature flags
// ---------------------------------------------------------------------------

/// When [true], all repositories fall back to locally generated mock data
/// instead of making real network requests. Useful for UI development and
/// automated tests that run without a live backend.
const bool kUseMockBackend = false;

String formatImageUrl(String url) {
  if (url.startsWith('http://localhost:') || url.startsWith('http://127.0.0.1:')) {
    final uri = Uri.parse(url);
    final baseUri = Uri.parse(kBaseUrl);
    return url.replaceFirst(uri.authority, baseUri.authority);
  }
  return url;
}
