# Project Media — Devpost image gallery

Prepared from actual Android application and Kiro IDE captures. No reconstructed game interface, invented model response or external game artwork is used.

## Upload set

- **15 PNG files**, numbered in recommended upload order.
- **1800 × 1200 pixels**, exactly **3:2**, RGB.
- Every image is below **5,000,000 bytes**; the largest is **990,548 bytes**.
- Image **01** is the recommended cover.
- Image **13** contains an ending spoiler and shows the earned Release route.
- Images **14–15** show actual Kiro development evidence; test counts are from the dated release report.

## Local files

| File/folder | Purpose |
| --- | --- |
| `build/devpost-gallery/images/` | The 15 upload-ready PNGs only |
| `build/devpost-gallery/hauntquest-ai-project-media.zip` | Download package: images, captions and manifest |
| `build/devpost-gallery/contact-sheet.jpg` | Preview of the full gallery; not an additional upload image |
| `build/devpost-gallery/CAPTIONS.md` | Suggested captions and alt text |
| `build/devpost-gallery/manifest.json` | Dimensions, sizes, hashes and original capture references |

Extract the ZIP and upload the numbered PNGs from `images/`; do not upload the ZIP itself. The 5 MB limit is checked for each individual image, not the archive. No upload or Devpost submission has been performed.

## Recommended sequence

| Order | Filename | Caption |
| --- | --- | --- |
| 01 | `01-hauntquest-ai-cover.png` | An offline Flutter mystery with five rooms, sixteen puzzles and three attainable endings. |
| 02 | `02-five-haunted-rooms.png` | Moonlit Entrance Hall · Forgotten Library · Alchemist’s Workshop · Clocktower Chamber · Echo Vault |
| 03 | `03-explore-and-discover.png` | Examine the portrait, recover the brass key and carry its meaning into the next encounter. |
| 04 | `04-library-and-workshop.png` | The library and workshop connect written clues, a torn recipe and a forgotten recording. |
| 05 | `05-clocktower-and-vault.png` | The clocktower’s mechanisms open the way to the Resonance Engine in the vault. |
| 06 | `06-puzzles-and-feedback.png` | Deliberate inputs and deterministic validation. Incorrect arrangements give meaningful feedback. |
| 07 | `07-puzzles-unlock-progress.png` | Clues support the solution. Solving the candelabra changes the Hall and opens its hidden door. |
| 08 | `08-inventory-and-item-use.png` | Use the recovered brass key on Tallow. His lantern becomes part of your journey. |
| 09 | `09-branching-conversations.png` | Original character portraits frame player replies. The story records the choices you make. |
| 10 | `10-discovery-journal.png` | The journal preserves discoveries and conversations. Evidence connections appear when their clues are known. |
| 11 | `11-whispering-guide-offline.png` | Contextual, spoiler-aware help. This release is offline and rule-based; no live AI service is connected. |
| 12 | `12-accessibility-and-sound.png` | Reduced motion, reading controls, mute and separate sound levels keep the mystery adjustable. |
| 13 | `13-final-choice-and-ending.png` | Final options depend on story requirements. Shown here: the earned Release ending. |
| 14 | `14-kiro-development-evidence.png` | Actual Kiro IDE capture. The retained .kiro directory contains the project’s requirements, design, tasks, steering and hook configurations. |
| 15 | `15-recorded-release-validation.png` | The dated release record reports 394 passing tests and clean analysis, plus Android gameplay and save-reload checks. No new hosted CI run is implied. |

## Provenance and reproduction

The screenshots come from the real instrumented Android playthrough used for the local video. Full captures are retained within frames; the Guide card crops only the modal detail. The Kiro images crop editor chrome while preserving source/report content. These are edited gallery layouts, not physical-device performance evidence.

The Whispering Guide is explicitly described as offline and rule-based. Only the Release ending is shown as recorded; no additional ending footage or fresh hosted CI result is claimed. The image manifest identifies the exact source capture for each card.

Generate again from the retained captures with:

```sh
python3 tool/media/generate_gallery.py
```

This uses Pillow for sizing, original typography/mattes and framing. Outputs remain under Git-ignored `build/`; captions and the reproducible generator remain in source.
