lib/
├── main.dart
├── app.dart                   # Root widget, routes, and theming
├── core/                      # Shared constants, utils, styles
│   ├── constants.dart
│   ├── validators.dart        # Password strength logic, etc.
│   └── theme.dart
├── features/
│   ├── auth/                  # Auth-related screens, logic, state
│   │   ├── data/              # Firebase Auth API logic
│   │   │   └── auth_repository.dart
│   │   ├── domain/            # Abstract interfaces or models (optional)
│   │   ├── presentation/      # UI files: login, register, etc.
│   │   │   ├── login_screen.dart
│   │   │   ├── register_screen.dart
│   │   │   ├── verify_email_screen.dart
│   │   │   └── reset_password_screen.dart
│   │   └── auth_controller.dart  # State controller (with Riverpod, Provider, etc.)
│
│   ├── game/                  # Game UI + logic
│   │   ├── data/              # GameService, WebSocket logic
│   │   ├── presentation/      # GameBoard, Lobby, Invite screens
│   │   └── game_controller.dart
│
│   └── home/                  # Home screen after login
│       └── home_screen.dart
