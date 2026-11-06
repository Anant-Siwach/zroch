# Zroch

A dynamic notch island for macOS, written in Swift/SwiftUI. Inspired by notch apps like Perch; a base to customize.

## Build & run

```sh
./build.sh          # builds Zroch.app in this folder
./build.sh --run    # builds, quits any running copy, launches it
```

Requires macOS 14+. AI Chat requires macOS 26 with Apple Intelligence enabled.

## Features

| Tab | What it does |
|---|---|
| Home | Music controls (Apple Music + Spotify), calendar events & reminders, weather; swipe left (or tap the dots) for a camera mirror |
| Tray | Drop files on the notch to shelve them; drag out, open, reveal, AirDrop |
| Timer | Preset/custom countdown with notification + sound, stopwatch with laps |
| Clipboard | Text history (pin, search, delete; password-manager copies ignored) and snippets |
| Notes | Multiple rich-text notes: bold ⌘B, italic ⌘I, underline ⌘U, strikethrough, bullets |
| AI Chat | On-device Apple Intelligence chat (Foundation Models) |

Closed notch shows live activities: album art + visualizer while music plays, countdown while a timer runs.
Settings (gear in notch, or menu bar icon): launch at login, hover delay, haptics, tab management,
weather units/city, timer presets, clipboard size, non-notch Mac options.

## Layout

- `Sources/Zroch/App` – entry point, app delegate, preferences/storage helpers
- `Sources/Zroch/Notch` – the floating panel, hover tracking, notch shape, root view
- `Sources/Zroch/Services` – music, weather, calendar, camera, clipboard, tray, timer, notes, AI
- `Sources/Zroch/Views` – one view per tab + settings

Data is saved to `~/Library/Application Support/Zroch/`.
The app is ad-hoc signed, so macOS may re-ask for permissions after a rebuild.

## Licence

MIT (see `LICENSE`).
