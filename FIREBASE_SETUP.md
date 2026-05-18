# Van Mate Firebase Setup

The standalone Android app now uses the package ID:

- `com.davidtyler.vanmate`

Because of that, the copied Firebase Android config from the old app is no
longer the correct long-term setup for this standalone app.

## What to create in Firebase

1. In the Firebase project you want Van Mate to use, add a new Android app.
2. Use Android package name: `com.davidtyler.vanmate`
3. Add the SHA-1 used for your debug and release signing if you want the new
   app identity fully registered for Google/Firebase services.

## Files to place in this app afterwards

- Download the new `google-services.json` for `com.davidtyler.vanmate`
  and place it at:
  `van_mate_app/android/app/google-services.json`

- Regenerate FlutterFire config so
  `van_mate_app/lib/firebase_options.dart` matches the new Android app
  registration.

## Suggested commands

Run these from `van_mate_app/` after creating the new Firebase Android app:

```powershell
flutterfire configure
flutter pub get
```
