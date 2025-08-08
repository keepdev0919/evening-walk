# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

"저녁 산책" (Evening Walk) is a Flutter-based mobile app that combines location-based technology with emotional content to provide users with meaningful walking experiences. The app offers destination-oriented walks with customized events and reflection recording capabilities.

## Key Development Commands

### Flutter Development
```bash
# Install dependencies
flutter pub get

# Run the app in development mode
flutter run

# Run specific platform
flutter run -d android
flutter run -d ios

# Build for production
flutter build apk
flutter build ios

# Run tests
flutter test

# Format code
flutter format .

# Analyze code (uses flutter_lints ^5.0.0)
flutter analyze

# Clean build artifacts
flutter clean
```

### Environment Setup
- Environment variables are loaded from `assets/config/.env`
- Google Maps API key is configured via `GOOGLE_MAPS_API_KEY` in the .env file
- Firebase configuration is handled automatically via `google-services.json`

## Architecture Overview

### Core Structure
The app follows a feature-based architecture with clear separation of concerns:

```
lib/src/features/
├── auth/           # Authentication (Google, Kakao)
├── home/           # Main dashboard
├── profile/        # User profile management
└── walk/           # Core walking functionality
    ├── application/        # Business logic and services
    │   ├── data/          # Static data (questions JSON)
    │   └── services/      # Core services
    └── presentation/       # UI components
        ├── screens/       # Full-screen views
        ├── utils/         # UI utilities
        └── widgets/       # Reusable components
```

### Key Service Layer Components

**WalkStateManager** (`lib/src/features/walk/application/services/walk_state_manager.dart`)
- Central state management for walk sessions
- Handles waypoint and destination logic
- Manages user location updates and event triggers
- Coordinates photo capture and question delivery

**Event Handlers**
- `WaypointEventHandler`: Manages intermediate waypoint logic
- `DestinationEventHandler`: Handles destination arrival events
- `WaypointQuestionProvider`: Delivers mate-specific questions from JSON files

### Authentication Flow
- Firebase Auth integration with Google and Kakao SDK
- Auth state is checked in `main.dart` with automatic routing
- Supports both social login providers

### Data Architecture
- Uses Firebase for backend services (Firestore, Storage, Analytics)
- Local state management through service classes
- Static content (questions) stored in JSON files under `lib/src/features/walk/application/data/`

### Map Integration
- Google Maps Flutter plugin for location visualization
- Real-time location tracking via geolocator
- Custom marker creation and waypoint generation
- 1.2km radius constraint for destination selection

### Mate System
The app supports three types of walking companions:
- 혼자 (Alone): Solo walking with self-reflection questions
- 연인 (Couple): Couple activities and balance games  
- 친구 (Friend): Friend missions and social activities

Questions and events are dynamically loaded based on the selected mate type from corresponding JSON files.

## Testing and Quality

- Linting configured with `flutter_lints: ^5.0.0`
- Analysis options in `analysis_options.yaml` use standard Flutter recommendations
- Test files located in `test/` directory

## Firebase Integration

- Firebase Core, Auth, Firestore, Storage, and Analytics configured
- Firebase App Check available but currently commented out in main.dart
- Google services configured via `android/app/google-services.json`
- Application ID: `com.ikjun.walk`

## Platform Configuration

### Android
- Min SDK: 23
- Target SDK: Flutter default
- Core library desugaring enabled for modern Java APIs
- Firebase BoM 34.0.0 for dependency management

### Development Notes

- The app uses Material Design but with `useMaterial3: false`
- Environment loading happens at app startup via flutter_dotenv
- Debug print statements are used throughout for development tracing
- Image picker integration for photo capture functionality