# Publication and submission checklists

**Local preparation date:** November 1, 2026. Checked items refer only to the
recorded local evidence. Unchecked publication items remain owner actions.
Do not tick them because a draft, screenplay or build folder exists.

## Public GitHub repository

- [ ] Approve the intended repository name **hauntquest-ai** and the final diff.
- [ ] Confirm the actual destination and permission to publish/push; no rename or
      push is authorized by this document.
- [ ] Commit all intended source and documents, including currently untracked files.
- [ ] Publish the approved final revision and verify it is accessible while signed out.
- [x] Root MIT license prepared following the recorded asset/dependency review.
- [x] Full third-party notices and original asset provenance retained locally.
- [x] `.kiro/specs`, `.kiro/steering`, real `.kiro/hooks` and `.kiro/agents` retained locally.
- [x] Local ignore/hygiene checks preserve `.kiro` and exclude build outputs/signing secrets.
- [x] English README, gameplay guide, architecture and judge instructions prepared.
- [ ] Verify GitHub detects the license and displays the final files, including `.kiro`.
- [ ] Reproduce installation/build from a clean checkout of the published revision.
- [ ] Put only the verified actual public repository URL into Devpost.

No new repository URL is invented here. A readable older remote is not proof that
the final changes or the new intended name have been published.

## Android APK or live demo

- [x] Release-mode Android APK built and verified in the recorded release pass.
- [x] Canonical APK exists at `build/app/outputs/flutter-apk/app-release.apk`.
- [x] APK SHA-256/size recorded in [installation instructions](INSTALLATION_AND_TESTING.md).
- [x] Android integration reached Release the Echo through five rooms with normal controls.
- [x] Three-ending reachability is covered by automated narrative tests.
- [x] Platform preference-reload integration passed; its same-process limit is disclosed.
- [x] Development signing is disclosed; private signing instructions exist in the root README.
- [ ] Choose the exact distribution APK; if it changes, rerun verification and update its hash.
- [ ] Test the distributed APK on the recording/judging device, including offline startup,
      Continue, mute, reduced motion and a complete legal route.
- [ ] Manually test a cold process restart; do not treat same-process reload as this check.
- [ ] Host the actual approved build with notices and checksum; test the download signed out.
- [ ] Add the real working build/application URL to Devpost; maintain judge access.
- [ ] If choosing Web instead, deploy and test it in a supported browser before calling it live.

The Web ZIP is build-verified only. A hosted website is optional if the APK is the
chosen accessible test build. A Play Store listing is not claimed by this package.

## YouTube demonstration

- [x] [Detailed 2:55 screenplay](DEMO_SCREENPLAY.md) prepared.
- [x] Record actual Android gameplay and actual Kiro project evidence (instrumented emulator capture).
- [x] Prepare English on-screen narration and SRT captions; this edition has no spoken voice-over.
- [x] Disclose gameplay excerpts and the actual device/emulator type.
- [x] Clearly identify the Guide as offline/rule-based and Kiro as development assistance.
- [x] Keep only original artwork/audio and captions; remove external logos and unrelated UI.
- [x] Confirm no private paths, credentials, email, notifications or account details are visible.
- [x] Verify the exported duration is below three minutes, including the final fade.
- [ ] Upload the reviewed export to YouTube and make it publicly visible.
- [ ] Check the video from a signed-out browser and paste its real URL into Devpost.

Do not use this screenplay, a local video path or an unuploaded draft as a demo link.

## Final hackathon compliance handoff

Use [RULES_REVIEW.md](RULES_REVIEW.md) for the checked source and unresolved items.
This checklist organizes the handoff; it does not certify eligibility.

- [ ] Owner reviews eligibility, representation, regional restrictions and conflicts.
- [ ] Owner confirms work dates, originality, ownership and any pre-existing work disclosure.
- [x] Project name and **Costume Contest** category specified in this local package.
- [x] English project description, technology tags and Kiro explanation prepared.
- [ ] Ensure the description and video match the exact distributed revision.
- [ ] Supply the verified public GitHub URL with open-source license and root `.kiro`.
- [ ] Supply the verified working application/test-build URL and testing instructions.
- [ ] Supply the verified public YouTube URL.
- [ ] Decide whether any optional bonus applies; none is asserted here.
- [ ] Review the complete Devpost form, required entrant fields and preview.
- [ ] Submit manually before the official deadline and retain the confirmation.

No Devpost form has been populated or submitted by this preparation.
