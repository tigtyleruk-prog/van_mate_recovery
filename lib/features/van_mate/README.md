# Van Mate Feature

This folder contains the standalone Van Mate feature code used by the extracted
app.

## Van-owned feature areas

- `pages/`: primary Van Mate screens
- `widgets/`: feature widgets, dialogs, and the extracted Van tab navigation
- `models/`: route and place models
- `services/`: Van-owned auth, places search, and Firestore route/drop storage
- `helpers/`: feature theme helpers, duplicate matching, and route marker icons

## App-level dependencies

- Firebase bootstrap now lives in `lib/app/van_mate_bootstrap.dart`
- App shell and theme now live under `lib/app`
- Android places channel wiring now lives in the standalone app's `MainActivity.kt`

## Later cleanup

- Create a dedicated Firebase app / package ID if you want side-by-side installs
  with any legacy app that still uses the older package identity.
- Replace the copied shared background asset if Van Mate should ship with fully
  distinct branding later.
