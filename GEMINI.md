
# EveningWalk Gemini Configuration

## Project Overview

This is a Flutter-based mobile application designed for evening walks. It provides users with walking courses, emotional content, and a journaling feature.

## Key Features

*   **Course Setting:** Users can set a destination within a 1.2km radius of their current location.
*   **Interactive Events:** The app provides event cards with questions and missions based on the chosen walking companion (alone, couple, or friend).
*   **Journaling:** Users can record their thoughts and feelings after each walk.

## Tech Stack

*   **Framework:** Flutter
*   **State Management:** Provider (Riverpod planned)
*   **Location Services:** geolocator
*   **Maps:** Google Maps API
*   **Backend:** Firebase
*   **Authentication:** Google/Kakao SDK

## How to Run

1.  **Install dependencies:** `flutter pub get`
2.  **Run the app:** `flutter run`

## Project Structure

*   `lib/`: Main application code
*   `assets/`: Images and environment configuration
*   `ios/`, `android/`: Platform-specific code
*   `pubspec.yaml`: Project dependencies and configuration
