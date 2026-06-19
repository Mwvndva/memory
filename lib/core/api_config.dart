// Central configuration for API endpoints and feature flags.
//
// For local Android emulator development, use 10.0.2.2 which maps to the
// host machine's localhost. For a physical device or production, update
// [kBaseUrl] to your server's public address.
// ---------------------------------------------------------------------------
// Endpoint configuration
// ---------------------------------------------------------------------------

/// Base HTTP URL of the NestJS backend.
/// Android emulator maps 10.0.2.2 → host localhost.
const String kBaseUrl = 'http://80.190.82.31:3000';

/// WebSocket endpoint (ws://) used by the chat/notification layer.
/// Must match the @WebSocketGateway({ path: '/ws' }) decorator in the backend.
const String kWebSocketUrl = 'ws://80.190.82.31:3000/ws';

// ---------------------------------------------------------------------------
// Feature flags
// ---------------------------------------------------------------------------

/// When [true], all repositories fall back to locally generated mock data
/// instead of making real network requests. Useful for UI development and
/// automated tests that run without a live backend.
const bool kUseMockBackend = false;
