# Grokbot Monitor

A small, native macOS menu-bar companion for the Grok Bot desktop app.

The idle menu icon uses the official-style, rotated Grokbot silhouette as a monochrome macOS template image, so the system keeps it legible in light and dark menu bars. When a Grokbot is working, the icon changes to that bot’s avatar color and shape; if several are active, the most recently active bot is shown with a count.

## What it shows

- Live working, waiting-for-you, failed, unread, and idle states
- Weekly usage, plan, reset information, and on-demand limit
- A local timeline of state changes (never message contents)
- Connection and stale-data states
- Optional attention notifications and launch at login
- Native Liquid Glass presentation on macOS 26 and newer, with system materials on older macOS versions

## Privacy and data sources

The app is local-only. It reads the Grokbot roster from `~/Library/Application Support/Grok Bot/sand-client-persistence` and the running app’s public Accessibility labels. It does not read stored credentials, call private APIs, or retain conversation text.

Accessibility access is required for live activity and usage. Without it, the roster, unread state, and cached usage remain available.

## Build and run

Requires macOS 14 or newer and Xcode 16 or newer.

```sh
swift test
./scripts/build-app.sh
open "dist/Grokbot Monitor.app"
```

Create a signed, versioned ZIP and checksum with:

```sh
./scripts/release.sh
```

For reliable launch-at-login registration, move the built app to `/Applications` first.

The About panel shows the bundled version and links to the [GitHub repository](https://github.com/djui/grokbot).

The release build is signed with the first available Apple Development identity (or ad-hoc signed as a fallback). Accessibility permission should be granted to the final `/Applications/Grokbot Monitor.app` installation, not a temporary build path. You can verify its current state with:

```sh
"/Applications/Grokbot Monitor.app/Contents/MacOS/Grokbot" --check-accessibility
```

## Usage refresh

The monitor passively captures usage whenever the Usage & Billing screen is visible. The refresh button is an explicit, user-initiated action that brings Grok Bot forward and opens that screen through Accessibility, then updates the local cache.
