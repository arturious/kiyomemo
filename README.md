# MemoryBar

MemoryBar is a lightweight native macOS menu bar utility for monitoring available
memory and clearing the file cache on demand.

The menu bar badge shows the percentage of free RAM. The popover displays used and
free memory, a compact ASCII-style meter, and a breakdown of wired, compressed,
and purgeable memory.

## Requirements

- macOS 14 or later
- Swift 6 toolchain

## Run

Run the app directly during development:

```bash
swift run MemoryBar
```

Build an ad-hoc signed `.app` bundle:

```bash
./Scripts/build-app.sh
open outputs/MemoryBar.app
```

Open the Swift package in Xcode:

```bash
open Package.swift
```

## Controls

- Click the menu bar badge to open the popover.
- Press `R` while the popover is open to refresh the memory snapshot.
- Press `Return` while the popover is open to clear the file cache.

## Cache Clearing

MemoryBar installs a restricted privileged helper the first time cache clearing
is enabled. macOS asks for an administrator password during installation. After
that, the app sends the helper its only supported command and the helper runs the
built-in `/usr/sbin/purge` utility without asking for a password again.

`purge` clears the disk file cache. It does not terminate applications or release
their private memory. macOS continues to manage memory compression and paging.

## Distribution Notes

The current build script creates an ad-hoc signed development bundle. Before
public distribution:

- sign the app with a Developer ID certificate and notarize it;
- replace the local helper installer with `SMAppService`;
- review the privileged helper lifecycle and add an uninstall path;
- decide whether to distribute through the Mac App Store or as a notarized
  direct download.
