# Release validation

Prepared November 1, 2026. This is a local evaluation release; no public repository,
APK host, video, store submission or Devpost entry is claimed.

## Verified checks

| Check | Result |
| --- | --- |
| Flutter / Dart | 3.47.7 stable / 3.13.5 |
| `flutter doctor -v` | Android SDK/JDK/licenses available; no missing Android prerequisites |
| `flutter analyze` | No issues found |
| `flutter test --reporter expanded` | 394 tests passed |
| Android full-game integration | Passed: actual controls through all five rooms to Release the Echo |
| Android save-restore integration | Passed: platform preferences reloaded after rebuilding app/services in the same process |
| Original launcher regeneration | Passed; icons rendered for Android/iOS/macOS/Web/Windows |
| Package license review | 79 resolved SDK/Dart package entries; original license texts retained |
| Native dependency license review | 90 Maven coordinates; Apache-2.0/BSD-3-Clause or Flutter engine notices; 9 archive notice files retained |
| Source hygiene and documentation links | Passed; no obvious secrets, local links resolve, build/secret paths ignored and .kiro retained |
| Release Android / Web builds | Both passed; final metadata below |

Native commands (Android 17 / API 37 ARM64 emulator):

```sh
flutter test integration_test/hall_and_library_test.dart -d emulator-5554 --reporter expanded
flutter test integration_test/restart_restore_test.dart -d emulator-5554 --reporter expanded
```

The full-game integration test does not inject inventory, flags or solved states.
It also flushes saves and verifies no persistence or native audio error. These
are debug-mode instrumented device tests; they are not a human playtest or a
release-mode frame-rate measurement. The restore test stays in one OS process.

## Signing and distribution

The release APK is optimized release code, signed with the installed **Android
Debug** certificate because no private `android/key.properties` was supplied.
APK Signature Scheme v2 verification passes. It is suitable for sideload evaluation,
not a privately signed Play Store release. The README gives exact private signing
steps. Signing keys/passwords are excluded from source.

The application ID is `io.github.myproject48.hauntquest`, version `1.0.0+1`, minimum
API 24, target/compile API 36. The universal APK contains ARMv7, ARM64 and x86_64.
No INTERNET permission is declared in the release manifest. Review tools are
hidden by default; no `HQ_REVIEW_TOOLS=true` define is supplied.

## Remaining human / publication work

- Public repository naming/publication as `hauntquest-ai`, approved push, and actual
  hosted APK/download URL. The existing remote has not been renamed by this work.
- Private signing identity and any store account/release process.
- Real-device sustained FPS/memory, Android 7 minimum-device run, TalkBack,
  headphone/interruption behavior, iOS hardware and additional native platforms.
- Manual cold-process restart and extended human puzzle playtesting.
- Actual demo video, eligibility/ownership review and Devpost submission with real links.

No guaranteed mid-range-device frame rate, public release URL, contest acceptance,
remote AI capability or live website is asserted.

## Local artifact metadata

Paths are relative to the repository root. Both APK copies are byte-identical.

| Artifact | Path | Bytes |
| --- | --- | ---: |
| Canonical release APK | `build/app/outputs/flutter-apk/app-release.apk` | 57698804 |
| Named evaluation APK | `build/release/hauntquest-ai-1.0.0-android-evaluation.apk` | 57698804 |
| Web build directory | `build/web/` | Directory |
| Packaged Web build | `build/release/hauntquest-ai-1.0.0-web.zip` | 15916475 |
| APK checksum | `build/release/APK_SHA256SUMS.txt` | Text |
| Extracted Flutter notices | `build/release/FLUTTER_NOTICES.txt` | Text |

APK SHA-256:

```text
4702ad331bd5e29a2dbf4eb71b34e3b37f03fd9e0ad373438322a10cfb7ddf1f
```

The APK ZIP CRC check passed. All 20 WAV assets are present and all three full
third-party notice assets match their source files byte-for-byte. `aapt dump
badging` confirms package/version, API 24 minimum, target API 36 and all three
ABIs; the APK is not marked debuggable. `apksigner verify --verbose --print-certs`
passes with a v2 signature and the development certificate described above.

Web is build-verified; a complete browser gameplay/caching/offline-install test
was not part of this release pass. Serve the extracted ZIP over HTTP, not `file:`.

CI configuration was added locally; a hosted GitHub Actions run cannot be verified
until the owner approves publication. No public APK/repository URL is invented.
