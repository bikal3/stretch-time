# StretchTime

Interval timer for stretching and workouts — one Flutter codebase for Android, iOS and web.

## Run

```sh
flutter run -d chrome        # web
flutter run                  # connected phone / simulator
flutter test                 # timer logic tests
```

## Build

```sh
flutter build web --release  # output: build/web — upload to any static host (Netlify, GitHub Pages, Cloudflare Pages)
flutter build apk --release  # Android APK  (Play Store: flutter build appbundle)
flutter build ipa            # iOS (needs an Apple Developer account for signing)
```

App icons come from `assets/icon.png`; regenerate with `dart run flutter_launcher_icons`.

## Code

- `lib/workout.dart` — workout model, plan builder, timer engine, built-in presets (pure Dart, tested)
- `lib/app_state.dart` — settings, saved & recent workouts (persisted with shared_preferences)
- `lib/main.dart` — home screen
- `lib/run_screen.dart` — running timer, voice/sound/vibration cues
- `lib/sheets.dart` — value editor, presets sheet, exercises editor, settings
