# HauntQuest AI

**An offline dark-fantasy mystery adventure for Android.** Explore the Whispering
Manor, uncover an inventor's disappearance, restore her Resonance Engine, and
decide the fate of the Echo.

Prepared for **Kiroween 2026 · Costume Contest**. The intended public repository
name is **`hauntquest-ai`**. These files are a local release preparation; no new
GitHub repository, hosted demo or download URL is claimed here.

[Gameplay guide](docs/GAMEPLAY_GUIDE.md) · [Judge testing guide](docs/JUDGE_TESTING_GUIDE.md) ·
[Kiro workflow](docs/KIRO_WORKFLOW.md) · [Architecture](docs/ARCHITECTURE.md) ·
[Third-party notices](docs/THIRD_PARTY_NOTICES.md)

## The game

A letter from Wren Dabney brings you to Vask Manor, where Ottoline Vask vanished
while investigating a mysterious presence. Follow clues across five illustrated
rooms, question the clockwork caretaker and the voices left behind, and choose
between freedom, containment and guardianship.

- **Five rooms:** Moonlit Entrance Hall, Forgotten Library, Alchemist's Workshop,
  Clocktower Chamber and the Echo Vault.
- **Sixteen playable puzzles:** visible clues, explicit player submissions,
  meaningful incorrect-answer feedback, three hint tiers, persistent drafts and
  solved states, and no repeat rewards. No generated configuration or external
  service is needed.
- **Inventory and investigation:** ten collectible items/clues, item inspection,
  contextual item use, recipe combination, a journal with seventeen discoveries,
  and nine authored evidence connections revealed after their endpoints are known.
- **Branching narrative:** seven shared dialogue nodes, original character
  portraits, skippable typewriter text, remembered decisions and read-only
  transcripts. Three attainable endings have different requirements and reveals.
- **The Whispering Guide:** optional contextual help with subtle, guided and
  direct levels. The shipped companion is **rule-based and entirely offline**.
  A provider-neutral interface exists, but no remote provider or AI-generated
  prose is configured. Guide output never controls progression or rewards.
- **Atmosphere:** original code-drawn scenes, fog and lighting, object feedback,
  finite discovery/puzzle effects, room/page transitions and distinct ending art.
  Twenty original synthesized sound assets cover ambience, interactions,
  footsteps, discoveries, chapters and endings. Every sound puzzle is also visual.
- **Persistence:** versioned autosaves retain room, inventory, consumed items,
  puzzles, drafts, flags, conversations, journal and ending status. Checksummed
  alternating snapshots recover a previous valid save. Version 1 migrates to
  schema 2; malformed/future saves are handled without partially loading state.
  New Game asks before replacing existing progress.
- **Accessibility:** reduced motion (including the OS preference), high contrast,
  text scaling/spacing, labeled controls, list-based room exploration, and master,
  ambient/effects volume and mute. Audio and gameplay tickers pause in background.

| Room | Playable puzzles |
| --- | --- |
| Entrance Hall | Candle Moons; Wake the Caretaker; The Symbol Seal; The Silver Mirror |
| Library | The Whispering Shelf; Torn Recipe; The Missing Runes; The Evidence Board |
| Workshop | Resonance Tuner; Corroded Cabinet; Moonwater Alchemy |
| Clocktower | Stopped Hands; Drive Gears; Constellation Discs |
| Vault | The Resonance Engine; The Echo Frequencies |

## Install and play

For the locally built Android package, use
`build/app/outputs/flutter-apk/app-release.apk`. It is a **release-mode evaluation
APK**, signed with the development certificate unless private signing is supplied.
No account, subscription, API key or network connection is required to play.

1. Copy the APK to an Android 7.0+ device and open it. Permit installation from the
   file source if your device asks; disable that source permission afterward if desired.
2. Alternatively, with Android Platform Tools and USB debugging enabled:
   `adb install -r build/app/outputs/flutter-apk/app-release.apk`.
3. Open **HauntQuest AI → Begin Quest**. Read or skip the introduction.
4. Tap room objects, inspect clues, collect items and open puzzle apparatuses.
   Use the inventory's item actions on compatible objects. Read dialogue choices
   before committing; their consequences persist.
5. Use **Journal**, the evidence board, room map and **Whispering Guide** when stuck.
   Hints escalate only on request. **Check** submits a puzzle; reset clears its
   current arrangement without removing solved progress or earned rewards.
6. Leave and reopen the app, then choose **Continue → Resume**. The manor keeps
   one active journey. After finishing, Continue can reopen the earned ending.

If Android reports an incompatible update signature, a differently signed build
is already installed. Preserve that installation if its save matters; uninstalling
it deletes its local journey. The public Android application ID is
`io.github.myproject48.hauntquest`; old development installs using
`com.example.hauntquest` are separate apps and do not share saves.

For a complete, spoiler-marked route and all ending requirements, see the
[gameplay guide](docs/GAMEPLAY_GUIDE.md). Judges can use the compact
[testing checklist and demo route](docs/JUDGE_TESTING_GUIDE.md).

## Build from source

Use a checkout/extracted source folder named `hauntquest-ai`; the internal Dart
package remains `hauntquest`. No GitHub URL is needed to build locally.

Verified toolchain: **Flutter 3.47.7 / Dart 3.13.5**, Android SDK with platform 36,
NDK 28.2.13676358, Java 21 (the project targets JVM 17), Gradle 9.3.1 and AGP 9.1.0.
The Dart SDK constraint is `^3.13.5`. Use the lockfile; do not upgrade dependencies
while reproducing the submission. Python 3 is needed only for asset/notice tools.

```sh
cd hauntquest-ai
flutter doctor -v
flutter pub get
flutter analyze
flutter test
flutter run -d <android-device-id>
flutter build apk --release
```

The universal APK includes ARMv7, ARM64 and x86_64. The canonical output is:

```text
build/app/outputs/flutter-apk/app-release.apk
```

Verify it with `test -s build/app/outputs/flutter-apk/app-release.apk` and, on
macOS, `shasum -a 256 build/app/outputs/flutter-apk/app-release.apk` (Linux:
`sha256sum`). See [release validation](docs/RELEASE_VALIDATION.md) for this build's
exact size, hash and check results. Build outputs are intentionally Git-ignored.
Attach the approved APK to a GitHub Release after publication approval.

### If Android prerequisites are missing

1. Install the specified Flutter SDK, add its `bin` directory to `PATH`, and install
   Android Studio with Android SDK Command-line Tools and Platform Tools.
2. In Android Studio's SDK Manager install Android SDK Platform 36, Build-Tools
   36.0.0, and NDK (Side by side) 28.2.13676358. Or run:
   `sdkmanager "platform-tools" "platforms;android-36" "build-tools;36.0.0" "ndk;28.2.13676358"`.
3. Install JDK 21; use `flutter config --jdk-dir=<your-jdk-directory>` if Flutter
   selects another Java. Set `ANDROID_HOME` to your SDK directory if not detected.
   These are machine-local settings; do not commit `android/local.properties`.
4. Run `flutter doctor --android-licenses`, accept licenses you are entitled to
   accept, then `flutter doctor -v`. Resolve every Android toolchain error.
5. Run `flutter pub get` and `flutter build apk --release` from the project root.
   An internet connection is needed initially to obtain build dependencies, not
   for installed Android gameplay.

Reference: [Flutter's Android release instructions](https://docs.flutter.dev/deployment/android).

### Private release signing

The generated evaluation APK is optimized release code, not a Play Store upload
signed with a privately managed release identity. For a durable public signing key:

```sh
keytool -genkeypair -v -keystore <private-location>/hauntquest-upload.jks \
  -storetype JKS -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

Create **local, ignored** `android/key.properties` with `storeFile` (absolute path,
use `/` separators), `storePassword`, `keyAlias`, and `keyPassword`. Enter real
passwords only in that private file; never in source, documentation or command
history. Rebuild with `flutter build apk --release`. Gradle uses private signing
when that file exists and fails on incomplete configuration. Back up the key
privately; updates must use the same identity. No key is created or published by
this repository. Store account, signing ownership and store submission are separate
release steps. An AAB can then be built with `flutter build appbundle --release`.

## Platforms and minimum requirements

| Platform | Status / requirements |
| --- | --- |
| Android | Primary release target. Android 7.0 / API 24 minimum, target API 36. ARMv7, ARM64 or x86_64; touch display. No runtime internet permission or login required. |
| Web | Secondary source target: `flutter build web --release`, serve `build/web/` over HTTP. Browser audio may require a user gesture. Initial loading needs a host/network; no offline-install/PWA caching guarantee. |
| iOS / macOS | Platform scaffolding is present; not distributed or certified for this release. Xcode, CocoaPods and appropriate signing are required. |
| Windows / Linux | Platform scaffolding is present; not built or verified for this release. |

Phone/tablet layouts are tested from 320 dp and with enlarged text. No measured
minimum RAM, GPU or guaranteed frame rate is claimed. Physical-device performance,
TalkBack and interruption/headphone behavior still need device testing.

## Verification and contribution

```sh
flutter analyze
flutter test
flutter test integration_test/hall_and_library_test.dart -d <android-device-id>
flutter test integration_test/restart_restore_test.dart -d <android-device-id>
sh tool/hooks/run.sh scan
python3 tool/check_release.py
```

The first device test plays all five rooms to Release the Echo using actual player
controls, without injecting inventory or enabling review tools. The second rebuilds
services and reloads platform preferences in the same process; a cold process
restart is a separate judge checklist item. Keep the app foregrounded during native
tests. Unit tests cover all three endings and valid narrative branches, puzzle
uniqueness, wrong inputs, seeded state transitions, corruption recovery, settings,
audio failures, accessibility and reduced motion. Release builds hide developer
review tools by default; do not set `HQ_REVIEW_TOOLS=true` for submission.

See [CONTRIBUTING.md](CONTRIBUTING.md). CI runs analysis, tests and an Android release
build. It does not publish anything.

## Kiro and repository structure

Kiro's spec, steering, hook and custom-agent artifacts are included at the root in
`.kiro/`. They document requirements, design, task planning, architecture constraints
and automated checks. [KIRO_WORKFLOW.md](docs/KIRO_WORKFLOW.md) explains the recorded
usage and its limits; no MCP server, Power or runtime Kiro service is claimed.
The initial spec is historical: current release behavior is documented here and in
[ARCHITECTURE.md](docs/ARCHITECTURE.md).

```text
.kiro/             Specs, steering, real hooks and agent configuration
.github/           CI, issue and pull-request templates
assets/content/    Authored story, rooms, items, puzzles, dialogue
assets/audio/      Original generated local PCM audio
lib/app/           Controllers, persistence, audio and guide coordination
lib/domain/        Pure-Dart authoritative engine and rules
lib/content/       Data models, loading and content validation
lib/core/          Design system, illustrations and shared widgets
lib/features/      Flutter screens and controls
test/              Domain, content, UI and tool tests
integration_test/  Compiled on-device journeys
tool/              Asset generation, progression tooling and checks
docs/              Gameplay, judging, architecture, workflow and notices
```

## License and remaining release steps

Original code, narrative and assets are **MIT licensed** after the dependency/asset
review recorded in [THIRD_PARTY_NOTICES.md](docs/THIRD_PARTY_NOTICES.md). Third-party
licenses and copyright notices remain intact. All illustrations and audio are
original; launcher assets have reproducible generators.

The shipped game has one autosaved journey, no manual/cloud save slots, no remote
AI service and no localization beyond English. Device profiling and broader native
platform validation remain open. Public hosting, a GitHub Release/download link,
a demonstration video and the Devpost form still require owner action. No repository
rename, push, hosting deployment or contest submission has been performed by this
release preparation. Use **`hauntquest-ai`** when approving the public repository name.
