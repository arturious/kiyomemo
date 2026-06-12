# kiyomemo

[![Latest release](https://img.shields.io/github/v/release/arturious/kiyomemo?display_name=tag&style=flat-square)](https://github.com/arturious/kiyomemo/releases/latest)
[![DMG downloads](https://img.shields.io/endpoint?url=https%3A%2F%2Farturious.github.io%2Fkiyomemo%2Fdmg-downloads.json&style=flat-square)](https://github.com/arturious/kiyomemo/releases)

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
