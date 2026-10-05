# KatsinaSub Mobile App — Flutter Project

This is a complete, working Flutter app — not a mockup — that proves
the full loop (register → login → wallet → every service → live chat
→ push notifications → logout) against the real KatsinaSub backend,
using the exact same accounts as the website.

## Your project's exact values (already set up — just use these)

| What | Value |
|---|---|
| Website domain | `katsinasub.com` |
| Mobile API base URL (already set in the code) | `https://katsinasub.com/api/v1/mobile` |
| Android package name | `com.katsinasub.app` |
| Firebase Project ID | `katsinasub` |
| Firebase Android app registered? | ✅ Yes (`google-services.json` already downloaded) |
| Firebase Service Account JSON | ✅ Already pasted into Admin → Settings |
| Database migrations run? | ✅ Yes (`api_tokens`, `device_tokens` tables exist) |

If any of these are wrong (e.g. the domain isn't exactly
`katsinasub.com`), fix `lib/services/api_service.dart` → `baseUrl`
before building.

## Setup — do this once Android Studio + Flutter are installed

1. Open a terminal (Command Prompt) and run:
   ```
   flutter create --org com.katsinasub vtu_mobile_app
   cd vtu_mobile_app
   ```
2. Copy `pubspec.yaml` and the whole `lib/` folder from this package
   into the new `vtu_mobile_app` folder, overwriting the defaults
   Flutter created.
3. Open `android/app/build.gradle` and find the line starting with
   `applicationId`. Make sure it reads exactly:
   ```
   applicationId "com.katsinasub.app"
   ```
4. Copy the `google-services.json` file (downloaded earlier from
   Firebase) into `android/app/google-services.json` (same folder as
   `build.gradle`).
5. Open `android/build.gradle` (the top-level one, NOT the one inside
   `app/`) and add this inside the `dependencies { }` block:
   ```
   classpath 'com.google.gms:google-services:4.5.0'
   ```
6. Open `android/app/build.gradle` again and add this as the very
   first line of the file:
   ```
   apply plugin: 'com.google.gms.google-services'
   ```
7. **App name and icon** — `flutter create` names the app after the
   folder (`vtu_mobile_app`) and gives it the default Flutter icon.

   **If you're building through the GitHub Actions pipeline** (see
   SETUP-GITHUB-CI.md) — this is already handled for you automatically
   by `scripts/patch-android.sh`, which every build runs: it generates
   the real launcher icon from `assets/logo.png` and sets the app's
   display name to "Katsinasub" in `AndroidManifest.xml` (and
   `ios/Runner/Info.plist`, if building for iOS). Nothing to do here —
   just push and let the workflow build.

   **If you're building locally instead** (ran `flutter create .`
   yourself, no CI), do the same two things by hand: run
   `flutter pub get` then `dart run flutter_launcher_icons` for the
   icon (reads `assets/logo.png`), and in
   `android/app/src/main/AndroidManifest.xml` change
   `android:label="vtu_mobile_app"` to `android:label="Katsinasub"`.

   Either way, **uninstall any previous build from the phone first**
   before installing the new one — Android caches the old icon/name for
   the same package otherwise.
8. **Fingerprint unlock needs two small native edits** (skip this step
   and fingerprint just won't be offered — everything else, including
   the 5-minute PIN lock, still works without it):
   - Open `android/app/src/main/kotlin/.../MainActivity.kt` and make it
     extend `FlutterFragmentActivity` instead of `FlutterActivity`:
     ```kotlin
     import io.flutter.embedding.android.FlutterFragmentActivity
     class MainActivity: FlutterFragmentActivity()
     ```
   - Open `android/app/src/main/res/values/styles.xml` (and the
     `values-night/styles.xml` if present) and make sure both
     `LaunchTheme` and `NormalTheme` inherit from a `Theme.AppCompat.*`
     parent (Flutter's default templates already do this in recent
     versions — just don't remove it).
   - For iOS, open `ios/Runner/Info.plist` and add:
     ```xml
     <key>NSFaceIDUsageDescription</key>
     <string>Ana amfani da Face ID/fingerprint don sauri budewa maimakon rubuta PIN.</string>
     ```
8. Run:
   ```
   flutter pub get
   ```
9. Connect an Android phone by USB (with USB debugging enabled in the
   phone's Developer Options), or start an emulator from Android
   Studio, then run:
   ```
   flutter run
   ```

## Building the installable APK (once testing looks good)

```
flutter build apk --release
```
The finished file appears at
`build/app/outputs/flutter-apk/app-release.apk` — this is the actual
file people install to try the app before it goes on Google Play.

## What's included — full feature parity with the website

- **Splash screen** — shows on app open with the logo, "Katsinasub",
  and "Dev. By Ks. D. S. Ltd" (2 seconds, then goes to Login or
  Dashboard). Add your real logo at `assets/logo.png` (see
  `assets/PUT_LOGO_HERE.txt`) — works fine without it too, just shows
  a plain "KS" mark until you do.
- Auth: Login, Register, Forgot Password
- Dashboard: wallet balance, notification bell with unread badge, a
  12-tile Services grid, and a side drawer for account-level features
- Purchases: Data, Airtime (rate calc + mismatch dialog), Cable TV
  (verify-then-pay), Electricity (verify-then-pay), Exam Pins, Bulk
  SMS, Recharge Card Printing, Data Card Printing
- Verification: NIN, BVN (with history), Email, Phone
- Wallet: Wallet Summary (totals + history), Fund Wallet
  (Paystack/Monnify via in-app checkout, virtual account, manual
  fund), Bonus Transfer, Airtime to Cash
- Account: Account Settings, Referral, Notifications, Live Chat with
  admin
- **App lock** — locks with the same PIN as the website after 5
  minutes in the background, or every cold start. Fingerprint unlock
  can be turned on in Account Settings > Security (needs the PIN once
  to enable); if the enrolled fingerprint on the phone is ever changed,
  fingerprint unlock turns itself back off and the PIN is required
  again to re-enable it
- **Push notifications** — chat replies, order updates, and admin
  broadcasts pop up on the phone even when the app is closed (already
  configured for this project — see `../MOBILE-PUSH-SETUP.md`)

## What's intentionally NOT in this app

- Pricing/API-Access/Documentation screens — those are for developer/
  reseller accounts, not this consumer app (prices already show live
  on every purchase screen)
- Admin/staff tools — a completely separate app for whoever runs the
  platform, not a customer
- App icon, splash screen, custom branding colors
- Publishing to Google Play / Apple App Store (a later step, once
  testing is done)
- The iPhone build itself (the code supports iOS, but Apple requires
  a Mac to actually compile it — see the earlier conversation about
  options for this)
