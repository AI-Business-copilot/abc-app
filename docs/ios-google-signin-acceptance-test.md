# iOS Acceptance Test — Google Sign-In

This machine is Windows: `xcodebuild` is absent and the Flutter engine cache has no iOS
artifacts (`bin/cache/artifacts/engine/ios` does not exist). iOS therefore could **not** be
compiled or run here — everything below was verified by inspection against the actual
`app_links` 7.0.0 and Flutter engine sources. This document is the checklist to run on a Mac.

## One entry fixes both platforms

Android and iOS share a single redirect URL and a single Supabase allowlist entry:

| | Android | iOS |
|---|---|---|
| Deep link registered in | `android/app/src/main/AndroidManifest.xml` `<intent-filter>` | `ios/Runner/Info.plist` `CFBundleURLTypes` |
| Handed to Flutter by | `app_links` → `onNewIntent` | `app_links` → `scene(_:openURLContexts:)` |
| Consumed by | `supabase_flutter` `_handleDeeplink` | **the same** `_handleDeeplink` |

`supabase_flutter` 2.18.3 exposes an identical `uriLinkStream` on both platforms, so the Dart
layer contains **zero** platform branching. The redirect URL is:

```
io.supabase.abcapps://login-callback
```

### Prerequisite — Supabase Dashboard (do this first)

**Authentication → URL Configuration → Redirect URLs**, add:

```
io.supabase.abcapps://login-callback
```

Optionally `io.supabase.abcapps://**` to tolerate path variants.

> Custom schemes do **not** qualify for RFC 8252 loopback exemptions. Supabase validates
> `redirect_to` against the allowlist; a custom scheme has a non-loopback hostname, so it must
> be explicitly allowlisted. Until it is, the redirect silently falls back to the project
> `SiteURL` (`http://localhost:5173`) — which on a phone means *the phone itself*, so the OAuth
> code never reaches the app.

Verify it took effect (expect the scheme echoed back, **not** the `http://localhost:5173` fallback):

```powershell
$key="<anon key>"; $enc=[uri]::EscapeDataString("io.supabase.abcapps://login-callback")
& curl.exe -s -i -H "apikey: $key" `
  "https://vhivkicmqwjiypvbssbv.supabase.co/auth/v1/verify?token=nonexistent&redirect_to=$enc&type=magiclink" |
  Select-String "^location:"
```

## Already verified by inspection on Windows

| Check | Result |
|---|---|
| `Info.plist` has `CFBundleURLTypes` with `CFBundleURLSchemes` = `io.supabase.abcapps` | ✅ already present |
| `Info.plist` has `LSApplicationQueriesSchemes` incl. `io.supabase.abcapps` | ✅ added |
| `Info.plist` `UIApplicationSceneManifest` → `UISceneDelegateClassName` = `$(PRODUCT_MODULE_NAME).SceneDelegate` | ✅ already present |
| `SceneDelegate.swift` extends `FlutterSceneDelegate` | ✅ already correct |
| `AppDelegate.swift` implements `FlutterImplicitEngineDelegate` + `didInitializeImplicitFlutterEngine` → `GeneratedPluginRegistrant.register` | ✅ matches Flutter's own UIScene template |
| `app_links` 7.0.0 iOS plugin handles `scene(_:openURLContexts:)` **and** `scene(_:willConnectTo:options:)` (cold start) | ✅ verified in source |
| `ios/Podfile` absent | ✅ normal — Flutter generates it on the first Mac build |

`LSApplicationQueriesSchemes` matters because `url_launcher_ios` 6.4.2 calls
`UIApplication.shared.canOpenURL(url)`; on iOS 9+ that returns `false` for any scheme not
listed. `supabase_flutter` calls `launchUrl` (not `canLaunchUrl`), so the OAuth launch itself
is not gated by this — but `url_launcher`'s internals and any future `canLaunchUrl` check are.

## Mac acceptance test

### 0. First build on a Mac

```bash
cd abc-app
flutter pub get
flutter build ios --no-codesign
# Flutter runs `pod install` automatically; a Podfile will be generated on first build.
```

If the build fails on `pod install`, run it manually:

```bash
cd ios && pod install && cd ..
```

### 1. Backend must be running

The app calls `/api/auth/me` after the Supabase session is established. Start the backend and
confirm it is healthy:

```bash
curl http://localhost:5000/api/health   # -> {"status":"OK"}
```

On a **physical iPhone**, the simulator's `localhost` is the phone itself. Point the app at the
Mac's LAN IP:

```bash
flutter run -d <iphone-device-id> --dart-define=API_BASE_URL=http://<MAC_LAN_IP>:5000/api
```

(Use the **iOS Simulator** instead if you only need to validate the OAuth redirect, not the
backend calls — `localhost` works there.)

### 2. Cold start — app NOT running

1. Force-quit the app (swipe up from the app switcher).
2. Open **Safari** on the device.
3. Navigate to the app and tap **"Tiếp tục với Google"**.
4. Complete the Google consent screen.
5. **Expected:** the app cold-starts from the `io.supabase.abcapps://login-callback` link and
   lands on `HomeScreen`.

> The URL arrives in `connectionOptions.urlContexts` on a cold start. `app_links` 7.0.0 handles
> `scene(_:willConnectTo:options:)` → `scene(_:openURLContexts:)`, so this path is covered —
> but it is the path most likely to regress, so test it explicitly.

### 3. Warm start — app in the background

1. Open the app once, then press the Home button (do **not** force-quit).
2. Tap **"Tiếp tục với Google"** and complete the consent screen.
3. **Expected:** the existing app process is foregrounded and lands on `HomeScreen`.

### 4. Full OAuth round trip

1. From a clean state (sign out in the app, or uninstall/reinstall), tap **"Tiếp tục với Google"**.
2. Complete the Google consent screen.
3. **Expected:** the app returns to the foreground and shows `HomeScreen` — not the login
   screen, and no error banner.

### 5. Log capture

Watch for the deep link and the PKCE exchange while running steps 2–4:

```bash
flutter run -d <iphone-device-id> --dart-define=API_BASE_URL=http://<MAC_LAN_IP>:5000/api
```

Look for in the Xcode console:

- `supabase.supabase_flutter: INFO: handle deeplink uri`
- `supabase.supabase_flutter: INFO: ***** Supabase init completed *****`
- **No** `AuthException`

`AuthException(message: Code verifier could not be found in local storage.)` means the PKCE
verifier was not persisted — on iOS it lives in `NSUserDefaults` under
`supabase.auth.token-code-verifier`. A `AuthApiException(invalid flow state, no valid flow
state found)` means the exchange reached Supabase but the flow was not recognised (usually a
stale or synthetic auth code).

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| Browser opens, app never comes back | Redirect URL not allowlisted | Add `io.supabase.abcapps://login-callback` to Supabase Redirect URLs |
| App opens but stays on the login screen | `/api/auth/me` failed (backend unreachable) | Start the backend; use `--dart-define=API_BASE_URL=...` with the Mac's LAN IP |
| `Code verifier could not be found in local storage` | PKCE verifier not persisted | Check the app is not clearing `NSUserDefaults` on launch |
| `canOpenURL` returns `false` | `LSApplicationQueriesSchemes` missing | Confirm the key is in the built app's `Info.plist` |

To inspect the built `Info.plist` (not the source one):

```bash
plutil -p build/ios/iphonesimulator/Runner.app/Info.plist | grep -A6 LSApplicationQueriesSchemes
```
