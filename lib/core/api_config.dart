// Backend base URLs — update these when deploying to production.
// For Android emulators use 10.0.2.2 instead of localhost.
// For physical devices, use your machine's local IP (e.g. 192.168.x.x).
const String kBaseUrl = 'http://localhost:3000';
const String kWebSocketUrl = 'ws://localhost:3000/ws';

// Set to false to connect to the real running NestJS backend.
const bool kUseMockBackend = false;
