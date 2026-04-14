# pai

A new Flutter project.

## Windows Google sign-in

Windows Google sign-in uses a desktop OAuth client with a loopback redirect:

```text
http://127.0.0.1:53171/oauth2redirect
```

Build or run Windows with the desktop OAuth client id:

```powershell
flutter run -d windows --dart-define=PAI_WINDOWS_GOOGLE_CLIENT_ID=YOUR_DESKTOP_CLIENT_ID.apps.googleusercontent.com
flutter build windows --release --dart-define=PAI_WINDOWS_GOOGLE_CLIENT_ID=YOUR_DESKTOP_CLIENT_ID.apps.googleusercontent.com
```

The redirect port can be changed with `--dart-define=PAI_WINDOWS_GOOGLE_REDIRECT_PORT=53171`, but the Google OAuth redirect and the app build must use the same port.

## Apple builds

iOS, iPadOS, and macOS all use the same Flutter app code. For Google sign-in on Apple platforms, create iOS and macOS OAuth clients in Firebase/Google Cloud, then add each client URL scheme to the matching `Info.plist`:

- `ios/Runner/Info.plist`
- `macos/Runner/Info.plist`

The URL scheme is the OAuth client's reversed client id, usually the `REVERSED_CLIENT_ID` value from a fresh `GoogleService-Info.plist`.

Build with the Apple Google client id:

```sh
flutter build ios --release --dart-define=PAI_APPLE_GOOGLE_CLIENT_ID=YOUR_IOS_CLIENT_ID.apps.googleusercontent.com
flutter build macos --release --dart-define=PAI_APPLE_GOOGLE_CLIENT_ID=YOUR_MACOS_CLIENT_ID.apps.googleusercontent.com
```

If a backend/server OAuth client is required later, also pass `--dart-define=PAI_APPLE_GOOGLE_SERVER_CLIENT_ID=YOUR_SERVER_CLIENT_ID.apps.googleusercontent.com`.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
