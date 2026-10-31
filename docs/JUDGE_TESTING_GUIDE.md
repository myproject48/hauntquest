# Judge testing guide

**Project:** HauntQuest AI · **Category:** Costume Contest · **Language:** English.
No login, API key, payment or online AI service is required. Android is the
submission target. This guide describes the local build, not a published download.

## Install

Use `build/app/outputs/flutter-apk/app-release.apk` from the source build, or the
owner-provided copy once distributed. Check its SHA-256 against
[RELEASE_VALIDATION.md](RELEASE_VALIDATION.md). Minimum Android 7.0 / API 24.

```sh
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

The evaluation APK contains optimized release code and uses a development signing
certificate unless the owner supplies private signing. It is not a Play Store
upload. A signature mismatch means another signing identity is installed; do not
uninstall a saved journey without accepting that its data will be lost.

## Small testing checklist

- [ ] Launch offline; select **Begin Quest** and read or skip the introduction.
- [ ] Tap the portrait, inspect the key/letter and solve Candle Moons from its clue.
- [ ] Enter a wrong answer on another puzzle; confirm feedback and no lost reward.
- [ ] Wake Tallow with the key, choose a reply and finish the linked dialogue.
- [ ] Inspect inventory, journal, evidence connections and contextual Guide hints.
- [ ] Enable mute and reduced motion; confirm puzzles remain usable and hints work.
- [ ] Start an unfinished puzzle, close/force-stop the app through Android, relaunch,
      choose **Continue → Resume**, and confirm progress and settings survived.
- [ ] Select New Game and cancel; verify the current journey remains intact.
- [ ] Complete the five-room route below and reach a final ending without review tools.
- [ ] Reopen the completed autosave; verify the same ending is retained.

For force-stop testing wait briefly after an action so its autosave completes;
watch for an autosave error before closing. A sudden interrupted write should
recover the last complete snapshot, not a mixture of states.

## Complete-game testing

Follow the spoiler-marked [GAMEPLAY_GUIDE.md](GAMEPLAY_GUIDE.md). It gives every
room, item use, puzzle answer and conversation choice, including the prerequisites
for all three endings. A complete journey can be played with sound muted and the
network disabled. No developer intervention, injected flags or hidden menu is needed.

For the fastest ending, restore the Resonance Engine and choose **Release the
Echo**; it is always available there. To inspect every puzzle and unlock the
other final options, follow the complete compassionate/research route. Each final
choice commits a distinct ending. A separate New Game is required for another fate.

## Suggested demo video (under three minutes)

Record actual Android gameplay and disclose cuts/time jumps; this is a recording
plan, not a claim that a video has been made.

| Time | Show |
| --- | --- |
| 0:00–0:20 | Title, original manor artwork and Begin Quest |
| 0:20–0:45 | Portrait discovery, inventory inspection, a wrong/correct puzzle answer |
| 0:45–1:10 | Tallow's portrait and a branching reply; journal update |
| 1:10–1:35 | Cuts between five distinct rooms, mirror/star/frequency apparatuses |
| 1:35–1:55 | Whispering Guide tiers, reduced motion/mute, Continue restoring progress |
| 1:55–2:25 | Engine restoration, final choices and one earned ending reveal |
| 2:25–2:50 | Kiro spec/steering/hooks/agent files, test result and truthful offline-AI explanation |

## Reproduce automated checks

```sh
flutter pub get
flutter analyze
flutter test
flutter test integration_test/hall_and_library_test.dart -d <android-device-id>
flutter test integration_test/restart_restore_test.dart -d <android-device-id>
python3 tool/check_release.py
sh tool/hooks/run.sh scan
```

The full-game native test drives real controls from arrival to an ending. It does
not grant items or inject story flags. The restore integration test reboots app
services and reloads platform preferences **in the same OS process**; the manual
cold-start item above is additional coverage. Tests can replace the installed
test app's journey. Use a disposable emulator for automation, and keep it foregrounded.

[RELEASE_VALIDATION.md](RELEASE_VALIDATION.md) records commands/results and actual
verification limits. Device frame-rate profiling, screen-reader walkthroughs and
hardware interruption/routing checks are not implied by widget tests.

## Submission handoff checklist for the owner

The [official Kiroween rules](https://kiroween.devpost.com/rules), checked
November 1, 2026, require a working app/test-build URL, a public open-source GitHub
repository including root `.kiro/`, an English description/Kiro write-up, a public
YouTube demo shorter than three minutes, and category identification. Review the
current rules before submitting; this preparation does not submit the form.

- [ ] Approve the public name **hauntquest-ai**, inspect the source diff and licenses.
- [ ] Approve any GitHub publish/push; this preparation has not renamed or pushed a repo.
- [ ] Publish the approved APK with notices and checksum; supply its real accessible URL.
- [ ] Record/upload the actual demo and supply its real YouTube URL.
- [ ] Complete the Devpost form with the real repository/build/video links and this Kiro write-up.
- [ ] Verify dates, eligibility, ownership and category; disclose any pre-existing work.

No placeholder GitHub, video or deployment URL is presented as a live submission.
