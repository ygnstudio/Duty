# Duty

A macOS menu bar utility that lets you **lock file extensions to specific applications** and automatically restores them when other apps try to take over.

> **Example**: You want `.md` files to always open with Obsidian, `.pdf` with Preview, and `.json` with VS Code. Duty monitors these associations and restores them if any app changes them.

![](screenshots/04_main_with_data_real.png)

## Why Duty?

macOS lets apps register themselves as default handlers for file types — often without asking. An app update might silently claim `.pdf` or `.txt`. Duty solves this by:

- Letting you **choose which extensions to protect** (not all system types)
- **Periodically checking** if your preferred defaults have changed
- **Automatically restoring** them when they do
- Keeping a **history** of every change and recovery

## Features

- 🛡 **Lock file extensions** to specific apps
- 📄 **Per-file protection** — clear "Always Open With" overrides on individual files
- 🔄 **Auto-restore** changed associations (configurable interval)
- 📋 **Built-in catalog** of 60+ common file types with Chinese and English names
- 📊 **Change history** — see what changed and when it was restored
- 🚀 **Launch at login** with no Dock icon (menu bar only)
- 🌐 **Bilingual UI** — Simplified Chinese and English

## Requirements

- macOS 14 (Sonoma) or later

That's it. Duty works entirely through macOS Launch Services APIs — **no third-party tools required**.

### Optional: duti

[duti](https://github.com/moretension/duti) is an optional enhancement. Duty only uses it to recognize rare file extensions that the system itself cannot resolve. Most users never need it.

```bash
brew install duti
```

If you try to add an unregistered extension without duti installed, Duty offers an in-place install guide. You can also install it anytime from **Settings → Enhancements**.

## Quick Start

### Download (Recommended)

Grab the latest `Duty.dmg` from [GitHub Releases](https://github.com/ygnstudio/Duty/releases), mount it, and drag `Duty.app` to `/Applications`.

### Build from Source

```bash
git clone https://github.com/ygnstudio/Duty.git
cd Duty
./build_app.sh
open Duty.app
```

Or open the project in Xcode and press `⌘R`.

### Usage

1. Click the **shield icon** in the menu bar to open Duty
2. Click **Add File Type** to search for extensions you want to manage
3. Select a default app for each extension
4. Toggle **Lock** to enable automatic protection
5. The app runs in the background — close the window, protection continues

| Action | Behavior |
|--------|----------|
| Left-click menu bar icon | Open / focus main window |
| Right-click menu bar icon | Open or Quit |
| Close main window | App keeps running (protection active) |
| Quit from menu | App fully exits (protection stops) |

## Project Structure

```
Sources/Duty/
├── DutyApp.swift                # App entry point
├── AppState.swift               # Global state management
├── Models/                      # Data models
├── Services/
│   ├── AssociationService.swift # UTI resolution + default app read/write
│   ├── ProtectionService.swift  # File-monitoring + auto-restore
│   ├── ExtensionCatalog.swift   # Built-in file type database
│   ├── CommandRunner.swift      # Safe process execution
│   ├── DutiDetector.swift       # Optional duti component detection
│   └── PersistenceController.swift # Local JSON storage
├── Views/                       # SwiftUI views
├── Utilities/                   # Helpers
└── Resources/                   # JSON catalog + localizations
```

## How It Works

Duty reads default app associations directly from the Launch Services secure plist (bypassing the daemon's stale cache) and writes them via `NSWorkspace.setDefaultApplication(at:toOpen:)`, falling back to the low-level `LSSetDefaultRoleHandlerForContentType` API. The optional duti component is only used to resolve UTIs for rare extensions unknown to `UTType`.

```
File extension → UTI → Default App (read via LS secure plist / Launch Services)
                     → Set App (write via NSWorkspace, fallback LS API)
```

The "lock" is **detection-based**, not a system-level block. Duty watches the Launch Services plist for changes and restores locked associations as soon as another app takes them over (with a timer-based fallback).

## Building

```bash
# Command line
swift build --disable-sandbox
swift run --disable-sandbox

# Or use Xcode
open Package.swift
```

## License

MIT — see [LICENSE](LICENSE)
