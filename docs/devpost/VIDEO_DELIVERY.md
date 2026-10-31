# Video production record

The local demo uses the requested eight-chapter, 175-second timeline. It is a
**caption-led edition with original game audio**, not a spoken voice-over.
The screenplay's English narration is supplied as a separate SRT caption file and
as an optional subtitle track in the MP4. No video upload or Devpost submission is
performed by this production workflow.

## Footage provenance

- Gameplay comes from the actual Flutter application running on an Android 17 /
  API 37 ARM64 emulator, through an opt-in instrumented UI playthrough.
- Every item, puzzle submission, dialogue choice and ending in that journey uses
  the normal controls. Inventory, flags and solved states are not injected, and
  review tools are disabled with `HQ_REVIEW_TOOLS=false`.
- Flutter frames are sampled by a RepaintBoundary in the test harness, exported
  through a temporary localhost-only adb tunnel and edited into the video. This
  is not a physical-phone recording or a frame-rate benchmark. Sampling uses ten
  frames per second; the delivery file duplicates frames for a 30 fps timeline.
- Short clips can hold their final frame for reading. Cuts reorder legal gameplay
  excerpts to fit the demonstration; the result is not an uninterrupted playthrough.
- The Kiro section uses actual IDE screenshots of the retained specification,
  steering, hook configuration and dated release-validation report. It is not a
  staged chat, fresh hook invocation or fabricated terminal success output.
- Sound is mixed from the project's original generated WAV files during editing;
  it is not advertised as a live emulator-audio recording. No third-party music,
  stock game artwork, external logos, voice model or generated voice is included.

## Reproduce the local video

Prerequisites: the project's Flutter/Android toolchain, an Android emulator,
Python 3 with Pillow, ffmpeg and ffprobe. The renderer uses locally installed
Georgia/Arial fonts on macOS or DejaVu Sans as a Linux fallback; no font file is
redistributed. All media output stays under Git-ignored `build/video/`.

```sh
sh tool/video/capture_android.sh emulator-5554
# Place actual, clean Kiro IDE captures in build/video/kiro/:
# spec.png, steering.png, hooks.png, tests.png
python3 tool/video/render_demo.py
```

The capture script starts a local frame receiver and removes its adb tunnel when
it exits. The game uses no remote service; the local receiver is development-only
instrumentation outside `lib/`. The test runner uninstalls its temporary app, so
frames are exported while it is running. Use a disposable emulator: automation
starts a new journey through the normal confirmation flow.

The renderer records its exact shot sequence in `timeline.json`, writes English
captions and chapter metadata, and verifies duration, dimensions, chapters and
subtitle presence with ffprobe. A full decode and visual/audio review should be
completed before sharing or uploading any new render.

## Requested chapter sequence

| Start | End | Content |
| --- | --- | --- |
| 00:00 | 00:15 | Introduction and the mystery |
| 00:15 | 00:35 | Main menu and visual atmosphere |
| 00:35 | 01:10 | Five-room exploration, journal and offline Guide |
| 01:10 | 01:40 | Puzzle feedback and inventory/item use |
| 01:40 | 02:00 | Remembered narrative choices and final requirements |
| 02:00 | 02:30 | Actual Kiro spec, steering, hooks and recorded validation |
| 02:30 | 02:45 | Earned Release ending and reveal |
| 02:45 | 02:55 | Conclusion |

## Final local artifacts and validation

| Artifact | Repository-relative path |
| --- | --- |
| Final MP4 | `build/video/hauntquest-ai-kiroween-demo.mp4` |
| English captions | `build/video/hauntquest-ai-english.srt` |
| Poster | `build/video/poster.png` |
| Visual review contact sheet | `build/video/review-contact-sheet.jpg` |
| Frame/capture manifest | `build/video/android/manifest.json` |
| Native playthrough capture result | `build/video/capture-export.log` |
| Media inspection | `build/video/verification.json` |
| Full video/audio decode check | `build/video/full-decode.log` |
| Audio-level check | `build/video/audio-check.log` |
| SHA-256 | `build/video/SHA256SUMS.txt` |

- Duration: **175.000 seconds (2:55)** including titles/fades.
- Video: **1920×1080, H.264, 30 fps**, with eight embedded chapters.
- Audio: **AAC stereo, 48 kHz**, edited original game ambience/effects, with gain
  adjusted for audibility. Measured peak: **-8.0 dBFS**; no clipping indicated.
- Captions: optional English subtitle track plus separate SRT; on-screen titles
  and explanatory captions are also rendered into the picture.
- Size: **10,994,440 bytes**.
- Full video/audio decode passed with no error output. Representative gameplay,
  Guide, settings, Kiro and ending frames were visually reviewed. Transition
  boundaries use brief fades; no black interval of 0.25 seconds was detected.
- The host-exported Android capture test passed through five rooms to the earned
  Release ending. `flutter analyze` reported no issues after the capture-tool edits.
- The temporary frame receiver and adb tunnel were stopped/removed after capture.

SHA-256:

```text
fe9f5937eaf28bc87abf606d53520175113adfde28797271c03b175f164d2347
```

The public YouTube link remains pending owner review and upload. No spoken
voice-over, public upload, native hardware benchmark or additional ending recording
is implied. The original screenplay is retained as the recording plan; this render
uses the documented caption-led adaptation.
