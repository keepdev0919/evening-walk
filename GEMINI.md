# EveningWalk Gemini Configuration

## Project Overview

This is a Flutter-based mobile application designed for evening walks. It provides users with walking courses, emotional content, and a journaling feature.

> ⚠️ **Note:** This project is being developed by a beginner in Flutter. All code is written with simplicity, maintainability, and future extensibility in mind.


## Tech Stack

*   **Framework:** Flutter
*   **State Management:** Provider 
*   **Location Services:** geolocator
*   **Maps:** Google Maps API
*   **Backend:** Firebase
*   **Authentication:** Google/Kakao SDK

## Code Style & Guidelines

*   🧩 **Designed for Readability**: All code is written so that other developers (and my future self) can easily understand it.
*   🛠️ **Extensibility in Mind**: Widgets, services, and state are structured to allow future expansion (e.g., Riverpod migration).
*   💬 **Comment-First Principle**: 
    - Clear and meaningful comments are added to explain the *purpose* and *behavior* of all complex logic.
    - Each public function includes a short description of its role and parameters.
*   🧪 **Modular Design**:
    - Feature-based folder structure (`features/`) is used.
    - Logic is separated into services, models, and UI for easier testing and scaling.

## How to Run

1.  **Install dependencies:** `flutter pub get`
2.  **Run the app:** `flutter run`
3.  If running on emulator, make sure location permissions are granted.



---

## Collaboration Tips

If you're contributing or reading the code:

- Start from `main.dart` and follow the feature module structure.
- Comments are used heavily. Look for `///` doc comments and inline explanations.
- The app is built to be beginner-friendly. Simplicity is prioritized over cleverness.

