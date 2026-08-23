# Inductive Automation Homebrew Tap

This public tap tracks stable Inductive Automation macOS downloads and their vendor-published SHA-256 values.

## Install

```sh
brew tap johnseth97/inductive-automation
brew install --cask ignition-designer-launcher
```

## Catalogue

`data/stable-macos-artifacts.json` is generated from IA's release catalogue and the per-build download tables. It includes every stable macOS artifact currently offered, including historical versions, exact URLs, and IA-published SHA-256 values. Nightly, snapshot, beta, RC, and other early-access builds are excluded.

The repository currently provides the verified Apple Silicon Designer Launcher cask. Versioned casks for all archive artifacts are generated only after each artifact family has had its installation layout verified; a URL and checksum are not enough to safely claim a Homebrew `app`, `pkg`, or installer artifact.

## Automation

The daily workflow refreshes the catalogue and opens a pull request when IA changes it. It never downloads historical installers during collection.
