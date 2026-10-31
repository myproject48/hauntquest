# Kiroween 2026 rules review and missing items

**Checked:** November 1, 2026. **Selected category:** Costume Contest.
Source: [official Kiroween 2026 rules](https://kiroween.devpost.com/rules), especially
sections 1, 3 and 4. The project-supplied guides were cross-checked against that page.
The overview/FAQ could not be fetched in this pass; no extra requirement is inferred
from them. This is a submission-readiness report, not an eligibility certification.

## Rules checkpoints

The rules call for a functioning Kiro-built application; an accessible application
or test-build URL; a public open-source GitHub repository containing root `.kiro`
without ignoring it; an English description and Kiro write-up; category selection;
and a public YouTube demonstration showing the functioning target application,
preferably under three minutes. Access must remain available through judging.
Entrants must satisfy eligibility, ownership, timing, licensing and regional-use
conditions and disclose incorporated pre-existing work. [Official rules](https://kiroween.devpost.com/rules).

Submission closes **December 4, 2026, 2:00 p.m. PST** (22:00 UTC; December 5,
01:00 in Istanbul). The development period begins October 30, 2026, 9:00 a.m.
Pacific Time; judging ends January 29, 2027. Confirm current dates before handoff.
[Timing source](https://kiroween.devpost.com/rules).

## Missing mandatory submission items

| Item | Evidence available locally | Still required |
| --- | --- | --- |
| Final public GitHub URL | Source, MIT license, notices, `.kiro` and English docs | Owner-approved publication of the final revision; signed-out verification; actual URL in the form |
| Working application/test-build URL | Verified local Android release APK and checksum | Approved hosting/download; signed-out installation check; actual URL in the form |
| Public YouTube demo URL | 2:55 screenplay only | Actual recording, export, public upload and verified URL |
| Completed submission form | Project/category/copy/testing/Kiro text prepared | Owner's entrant fields, final review and manual submission |
| Entrant attestations | Repository history and original-source/license records | Owner confirmation of eligibility, dates, ownership, permissions and disclosures |

**Status: not yet ready to submit.** The three public links and owner/form actions
above are unresolved. No link is fabricated, and the existence of a Git remote
or local artifact is not marked as a completed public submission.

## Prepared and evidenced

The selected category is Costume Contest. English submission copy and Kiro
explanation are in this folder. The root license and notices are present locally;
`.kiro` specs, steering, actual hooks and agent configuration remain included and
unignored. Recorded Android integration reached an ending through normal controls,
and the release APK exists. See [claims evidence](CLAIMS_AND_EVIDENCE.md) and
[release validation](../RELEASE_VALIDATION.md) for the exact test/build scope.

Eligibility and development-period compliance cannot be proven solely by commit
timestamps. The earliest local commit is dated October 31, 2026, but that does not
establish when every asset was created or whether the entrant satisfies the rules.
No team, startup, student, prior-participation or bonus eligibility is assumed.
Optional bonus materials are not reported as missing base-submission items.

## Additional quality tasks, not missing base-submission links

The current APK is development-signed and should be described as an evaluation
build. Private signing ownership, physical-device profiling, manual cold restart,
TalkBack, hardware audio routing and further human playtesting remain separate
release-quality tasks. The Web build has no verified live deployment.

No automatic Devpost submission, GitHub push, repository rename, video upload or
hosting deployment was performed. The owner must approve publication and submit
manually after resolving the missing items.
