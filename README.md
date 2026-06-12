<div align="center">
  <h1>kiyomemo</h1>

  <a href="https://github.com/arturious/kiyomemo/releases/latest"><img alt="release" src="https://img.shields.io/github/v/release/arturious/kiyomemo?display_name=tag&label=release&color=blue"></a>
  <a href="https://github.com/arturious/kiyomemo/releases"><img alt="DMG downloads" src="https://img.shields.io/endpoint?url=https%3A%2F%2Farturious.github.io%2Fkiyomemo%2Fdmg-downloads.json"></a>
  <a href="LICENSE"><img alt="license" src="https://img.shields.io/badge/license-GPL%20v3-blue"></a>
</div>

kiyomemo is a lightweight native macOS menu bar utility for monitoring memory
usage and clearing the file cache on demand.

![Kiyomemo demo](docs/kiyomemo-demo.gif)

## Install

Install with curl:

```sh
curl -fsSL https://arturious.github.io/kiyomemo/install | bash
```

Install with Homebrew:

```sh
brew install --cask arturious/tap/kiyomemo
```

Or download the latest `.dmg` manually from
[Releases](../../releases/latest), open it, and drag
`Kiyomemo.app` into `Applications`.

kiyomemo checks GitHub Releases for verified updates and can install new
versions automatically.

## Cache Clearing

kiyomemo uses the built-in macOS `/usr/sbin/purge` utility. It clears the disk
file cache without terminating applications or releasing their private memory.

## License

Copyright (C) 2026 arturious.

kiyomemo is distributed under the [GNU General Public License v3.0](LICENSE).
