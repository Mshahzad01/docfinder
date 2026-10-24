# DocVault

Offline, path-based document organizer (Flutter Desktop). Files are never copied; only the path and small metadata are stored in a local SQLite database.

## Run
```
flutter pub get
flutter run -d windows
```

## Build (Windows)
```
flutter build windows --release
```
Output: `build\windows\x64\runner\Release\` (copy the whole folder; run `docfinder.exe`).

## Requirements (Windows)
- Visual Studio 2022 with "Desktop development with C++" workload
- Windows **Developer Mode ON** (Settings > For developers) - needed for plugin symlinks
- Linux only: `zenity` or `kdialog` (file picker), `libsqlite3` is bundled

## Structure
```
lib/core            theme, formatters, file types, category styles
lib/data            database, models, repositories (all SQL)
lib/domain          search params + services (file system, library logic, settings)
lib/presentation    providers (Riverpod), screens, widgets, UI actions
```

## Shortcuts
Ctrl+F search - Ctrl+N add - Enter open - Delete remove entry - Esc clear - Up/Down move - Ctrl/Shift+click multi-select
