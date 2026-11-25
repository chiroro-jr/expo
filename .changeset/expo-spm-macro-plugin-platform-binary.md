---
'expo': patch
---

Use `expo-modules-macros`'s `getScannerBinaryPath()` in the SwiftPM plugin on non-macOS hosts so Linux and Windows use their platform macro plugin binary instead of the macOS `apple/ExpoModulesMacros` binary.
