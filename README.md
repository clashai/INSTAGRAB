# InstaGrab

Clipboard watcher that auto-downloads Instagram reels to your gallery.

## Features

- **Clipboard monitoring** — Toggle a watcher that detects Instagram URLs when you copy them
- **Accessibility service** — Background detection even when app is closed (Android)
- **Auto-download** — Videos are downloaded and saved to your gallery automatically
- **Download history** — See all your past downloads with retry option for failures
- **Notifications** — Get notified when downloads start and complete

## Setup

### Prerequisites

- Flutter SDK 3.0+
- Android SDK (via Android Studio or command-line tools)

### Install & Run

```bash
# Install dependencies
flutter pub get

# Run on connected device
flutter run

# Build release APK
flutter build apk --release
```

The release APK will be at `build/app/outputs/flutter-apk/app-release.apk`.

## How It Works

1. **Toggle the watcher** — Tap the toggle on the home screen to start monitoring your clipboard
2. **Copy an Instagram link** — Copy any Instagram reel/post/IGTV URL
3. **Auto-download** — The app detects the URL, extracts the video, and saves it to your gallery
4. **Or paste manually** — Use the input field to paste a URL directly

## Supported URL Formats

- `https://www.instagram.com/reel/...`
- `https://www.instagram.com/p/...`
- `https://www.instagram.com/tv/...`
- `https://instagr.am/...`

## Architecture

```
lib/
├── main.dart                    # App entry point
├── models/
│   └── download_item.dart       # Download data model
├── screens/
│   └── home_screen.dart         # Main screen
├── services/
│   ├── clipboard_service.dart   # Platform channel for clipboard
│   ├── download_service.dart    # Video download pipeline
│   ├── history_service.dart     # Local storage for history
│   ├── instagram_service.dart   # URL extraction & video scraping
│   └── notification_service.dart # Local notifications
└── widgets/
    ├── download_card.dart       # Download history card
    └── status_bar.dart          # Watcher toggle widget

android/app/src/main/kotlin/com/instagrab/app/
├── MainActivity.kt                      # Flutter activity
├── InstaGrabAccessibilityService.kt      # Accessibility service for background monitoring
├── ClipboardService.kt                  # Clipboard management
└── ClipboardCaptureActivity.kt          # Captures clipboard via accessibility
```

## Limitations

- Only works with **public** Instagram posts/reels
- Background clipboard monitoring requires the foreground service notification on Android
- iOS does not support background clipboard monitoring (Apple restriction)
