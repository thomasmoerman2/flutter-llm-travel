# App

## Overview
This package contains the Flutter client application for the monorepo.

## Prerequisites
- Flutter SDK 3.10.4 or newer (Dart included).
- Platform toolchains as needed:
  - iOS: Xcode and CocoaPods (macOS only).
  - Android: Android Studio and Android SDK.
  - Web: Chrome (or another Flutter-supported browser).

## Environment Configuration
Create or update a `.env` file in this directory with the following keys:
- `API_BASE_URL` (default: `http://localhost:5005`)
- `MAPBOX_ACCESS_TOKEN` (required for map features)
- `ENV` (recommended: `development` or `production`)
- `DEBUG` (`true` or `false`)

## Install Dependencies
```sh
flutter pub get
```

## Start (Development)
```sh
flutter run
```

To run on a specific device:
```sh
flutter run -d <device-id>
```

If you prefer npm scripts:
```sh
npm run dev
```

## Build (Release)
Choose the target platform you need:

```sh
flutter build ios
flutter build apk
flutter build appbundle
flutter build web
```

## Run (Release)
```sh
flutter run --release
```

## References
- Mapbox setup: `MAPBOX.md`
- Offline behavior: `OFFLINE.md`
- Backend payload guidance: `BACKEND_PAYLOAD.md`
