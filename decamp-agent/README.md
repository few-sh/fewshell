# Decamp Agent

A Dart-based agent service for Decamp that provides real-time communication and remote command execution capabilities.

## Features

- 🚀 REST API with shelf
- 🔌 WebSocket support for real-time communication
- 🏥 Health check endpoint
- 🎯 Client-server architecture for remote command execution (planned)

## Getting Started

### Prerequisites

- Dart SDK 3.5.0 or higher

### Installation

```bash
# Install dependencies
dart pub get
```

### Running the Server

```bash
# Run the server (default port: 3123)
dart run bin/server.dart

# Run with custom port
PORT=8080 dart run bin/server.dart
```

## API Endpoints

### REST Endpoints

- `GET /health` - Health check endpoint
  ```json
  {
    "status": "healthy",
    "service": "decamp-agent",
    "timestamp": "2025-11-23T..."
  }
  ```

### WebSocket Endpoint

- `GET /ws` - WebSocket connection for real-time communication

#### WebSocket Message Types

**Ping/Pong:**
```json
// Client → Server
{ "type": "ping" }

// Server → Client
{ "type": "pong", "timestamp": "..." }
```

**Command Execution (planned):**
```json
// Client → Server
{ 
  "type": "command",
  "command": "ls -la"
}

// Server → Client
{
  "type": "command_response",
  "stdout": "...",
  "stderr": "...",
  "exitCode": 0
}
```

## Project Structure

```
decamp-agent/
├── bin/
│   └── server.dart          # Entry point
├── lib/
│   ├── router.dart          # Route definitions
│   └── handlers/
│       ├── health_handler.dart      # Health check
│       └── websocket_handler.dart   # WebSocket logic
├── pubspec.yaml
└── README.md
```

## Future Enhancements

- [ ] Shell command execution from decamp-app client
- [ ] Authentication and authorization
- [ ] Server-Sent Events (SSE) support
- [ ] Process management and monitoring
- [ ] File system operations

## Integration with Decamp App

This agent is designed to work with the Flutter-based `decamp-app` client, enabling remote control and monitoring capabilities.
