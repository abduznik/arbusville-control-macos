# Arbusville Control — macOS

Native macOS window for the dashd homelab dashboard. A thin Cocoa + WKWebView
shell (~200 lines of Objective-C, no dependencies) compiled into a universal
`.app` and packaged as a `.dmg`.

The UI itself lives on the server, so this app only needs to reach it — nothing
is installed locally and no daemon runs.

## Install

Download `ArbusvilleControl-macos.dmg`, open it, drag the app to Applications.

It is signed ad-hoc, not notarized, so the first launch needs one of:

- right-click the app → **Open** → **Open**, or
- `xattr -dr com.apple.quarantine "/Applications/Arbusville Control.app"`

## Server address

Defaults to the tailnet address `http://100.119.139.93:8770`. If Tailscale is
not running on the Mac:

- **⌘ ,** (or the app menu → *Set server…*) and enter the LAN address
  `http://10.0.0.11:8770`.

## Behaviour worth knowing

- The webview uses a **non-persistent data store**, so a page cached by an older
  build can never be served after an update, and every launch loads a unique URL.
- ⌘R reloads.
- If the server does not answer, or the page loads but renders nothing, a native
  dialog appears with the address, a reason, and Retry / Change server / Quit.
  A blank window is never the failure mode.

## Build

`.github/workflows/macos.yml` runs on a `macos-14` runner:

```
clang -fobjc-arc -O2 -arch arm64 -arch x86_64 -mmacosx-version-min=11.0 \
  -framework Cocoa -framework WebKit src/DashApp.m
```

Then the icon is generated from `assets/dashd.png` with `sips` + `iconutil`,
the bundle is ad-hoc signed, and `hdiutil` produces the DMG. Push to `main` or
run the workflow manually to get the artifact.
