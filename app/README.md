# Personal — Flutter client

The macOS, Windows, Android and iOS app. It is one codebase with two shells: a desktop sidebar
layout in `lib/ui/` and a one-handed phone layout in `lib/ui/phone/`, sharing everything in
`lib/domain/` and `lib/data/`. Where Mac and Windows differ (title bar, ⌘ vs Ctrl), it goes
through `lib/ui/platform.dart`.

See the [root README](../README.md) for features, downloads and building, and
[`../server/README.md`](../server/README.md) for sync.

```bash
flutter pub get
flutter run -d macos     # or: flutter run -d windows, on a Windows PC
dart run build_runner build --delete-conflicting-outputs   # after changing lib/data/database.dart
flutter test
```
