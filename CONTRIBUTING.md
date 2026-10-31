# Contributing

Use Flutter 3.47.7 / Dart 3.13.5 and the committed lockfile. Read
[ARCHITECTURE.md](docs/ARCHITECTURE.md), the `.kiro/steering/` guidance and the
current release notes before editing. The original spec remains design history.

Keep game rules in the pure-Dart domain layer and solutions/clues in authored
content. UI, effects and optional companion output must never control authoritative
progression. Preserve offline play, accessibility, deterministic validation and
all reachable endings. Do not introduce impossible randomized configurations.

Run `flutter analyze`, `flutter test`, `sh tool/hooks/run.sh scan` and
`python3 tool/check_release.py`. Run native integration tests after progression or
storage changes. Regenerate the progression map with
`dart run tool/generate_progression_graph.dart` when changing content dependencies.
New dependencies/assets need provenance and license review plus updated notices.
Original contributions are accepted under the project's MIT license; do not
submit work you cannot license that way.

Keep `.kiro/`, platform scaffolding, `pubspec.lock` and required generated plugin
registrants. Do not commit build outputs, caches, local SDK paths, `.env`, signing
configuration, keystores or credentials. Never attach private saves to public
issues. No automatic publish/push is part of validation; publication requires
owner approval. Mark story spoilers in issues and pull requests.
