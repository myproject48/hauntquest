# Installation and testing — HauntQuest AI

**Platform:** Android. **Minimum:** Android 7.0 / API 24.  
**Login / API key:** None. **Gameplay network requirement:** None.  
**Language:** English. **Category:** Costume Contest.

## Obtain the build

The local release-mode APK is:

```text
build/app/outputs/flutter-apk/app-release.apk
```

An identical named copy is available locally at:

```text
build/release/hauntquest-ai-1.0.0-android-evaluation.apk
```

A public download URL has not been supplied. The owner must host the approved
APK and place its real link in the Devpost application/test-build field. A local
path cannot serve as that link. Preserve the accompanying notices and checksum.

Verified APK size: **57,698,804 bytes**. SHA-256:

```text
4702ad331bd5e29a2dbf4eb71b34e3b37f03fd9e0ad373438322a10cfb7ddf1f
```

This APK contains optimized release code, is not marked debuggable, and is signed
with the installed Android development certificate. It is a sideload evaluation
build, not a privately signed Play Store upload. If a new signed build is supplied,
revalidate it and update the checksum before distributing it.

## Install

Transfer the APK to a supported Android phone/tablet and open it. If the device
asks, permit installation from the chosen file source. Or, with Android Platform
Tools and an authorized device connected:

```sh
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

Launch **HauntQuest AI**. Its package ID is `io.github.myproject48.hauntquest`.
A signature mismatch means a different signing identity is installed. Uninstalling
that copy removes its local journey; do not do so without deciding to discard it.
Old `com.example.hauntquest` development installs are separate applications.

## Five-minute inspection route

1. Select **Begin Quest**, read or skip the introduction and enter the Moonlit
   Entrance Hall. If a prior journey exists, cancel or deliberately confirm the
   New Game dialog rather than silently overwriting progress.
2. Inspect the portrait to collect the key; open inventory and read Wren's letter.
3. Open the silver candelabra with **Look closer**. Submit a wrong moon sequence
   with **Check**, read the feedback, reset, then submit **Crescent → Half → Full
   → Waning**. Observe the success state and opened hidden door.
4. Use the brass winding key on the dormant automaton, close the object panel and
   finish Tallow's conversation. Choose **Thank him warmly**, then listen to his
   memory. Inspect the journal update and carried lantern.
5. Open the Whispering Guide and request a subtle hint for a discovered topic.
   Its panel explicitly identifies offline, rule-based guidance.
6. Enable mute/reduced motion in Settings and verify the controls remain usable.
   Leave the app and reopen it, then use **Continue → Resume** to inspect saved
   progress. A real cold-process restart should also be checked manually.

The time is an inspection plan, not a measured player-completion statistic.

## Complete gameplay and all endings

Use the spoiler-marked [complete gameplay guide](../GAMEPLAY_GUIDE.md). It gives
all room transitions, item uses, sixteen puzzle solutions and a compassionate
research route that enables the three final choices. No review tools, injected
items or developer intervention are needed.

Restore the Resonance Engine and choose **Release the Echo** for the always-available
final route. **Seal** requires binding knowledge or the alchemy/constellation
research. **Guardian** also depends on evidence, truths, kindness, the listening
promise and rejection of ownership. Disabled choices explain their prerequisites.
Advance the final result with **See what follows**, watch/skip the reveal and
continue to **The End**. A new journey is needed to choose a different final fate.

The manor keeps one autosaved journey. Continue can reopen a completed ending;
there are no manual or cloud save slots. Offline hints are available throughout.

## Build and reproduce checks

From the source root, using Flutter 3.47.7 / Dart 3.13.5 and a configured Android
toolchain:

```sh
flutter pub get
flutter analyze
flutter test
flutter build apk --release
flutter test integration_test/hall_and_library_test.dart -d <android-device-id>
flutter test integration_test/restart_restore_test.dart -d <android-device-id>
```

Native tests should use a disposable foreground emulator. The complete-game test
uses normal controls; the save-reload test recreates services and reads platform
preferences within one process. These do not replace human testing of a cold
process restart, TalkBack or device performance.

The recorded November 1 release checks passed: 394 tests, clean analysis, an Android
five-room journey to Release, platform save reload and Android/Web release builds.
See [the validation report](../RELEASE_VALIDATION.md) for exact scope and limitations.
No native-device traversal of all three endings or sustained frame-rate result is claimed.

Android prerequisites and optional private signing instructions are in the
[root README](../../README.md). The Web build is secondary and build-verified;
this package makes no claim of a hosted or offline-installable Web demo.
