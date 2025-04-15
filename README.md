lib/
├── main.dart
├── app.dart                   # Root widget, routes, and theming
├── core/                      # Shared constants, utils, styles
│   ├── constants.dart
│   ├── validators.dart        # Password strength logic
│   └── theme.dart
├── features/
│   ├── auth/                  # Auth-related screens, logic, state
│   │   ├── data/
│   │   │   └── auth_repository.dart
│   │   ├── domain/
│   │   ├── presentation/
│   │   │   ├── login_screen.dart
│   │   │   ├── register_screen.dart
│   │   │   ├── reset_password_screen.dart
│   │   │   └── verify_email_screen.dart
│   │   └── auth_controller.dart
│
│   ├── game/                  # Game UI + multiplayer logic
│   │   ├── data/
│   │   │   └── websocket_service.dart   # WebSocket client connection & messaging
│   │   ├── presentation/
│   │   │   └── lobby_screen.dart        # Real-time online lobby + invites
│   │   └── game_controller.dart         # (WIP) Game logic handler
│
│   └── home/
│       └── home_screen.dart             # Home screen after login


dart websocket_server.dart

