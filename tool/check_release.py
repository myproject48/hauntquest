#!/usr/bin/env python3
"""Validate public-source hygiene, licensing inventory and documentation links."""
from pathlib import Path
import json
import re
import subprocess
import sys

root = Path(__file__).resolve().parent.parent
errors = []
required = ['README.md', 'LICENSE', 'docs/GAMEPLAY_GUIDE.md',
            'docs/KIRO_WORKFLOW.md', 'docs/ARCHITECTURE.md',
            'docs/JUDGE_TESTING_GUIDE.md', 'docs/THIRD_PARTY_NOTICES.md',
            'docs/licenses/DEPENDENCIES.md', 'docs/licenses/DEPENDENCY_LICENSES.txt',
            'docs/licenses/FLUTTER_ENGINE_LICENSES.txt',
            'docs/licenses/ANDROID_DEPENDENCIES.md',
            'docs/licenses/ANDROID_ARCHIVE_NOTICES.txt']
for name in required:
    if not (root / name).is_file():
        errors.append(f'Missing release file: {name}')
for name in ['specs', 'steering', 'hooks', 'agents']:
    directory = root / '.kiro' / name
    if not directory.is_dir() or not any(directory.rglob('*')):
        errors.append(f'Missing .kiro/{name} evidence')
for path in (root / 'assets/content').glob('*.json'):
    json.loads(path.read_text())
for path in (root / '.kiro/hooks').glob('*.json'):
    hook = json.loads(path.read_text())
    if not hook.get('hooks'):
        errors.append(f'Empty hook configuration: {path.relative_to(root)}')

# Scan only files that would be published, including not-yet-staged work.
tracked = subprocess.check_output(['git', 'ls-files', '-z'], cwd=root).split(b'\0')
untracked = subprocess.check_output(['git', 'ls-files', '--others', '--exclude-standard', '-z'], cwd=root).split(b'\0')
paths = {p.decode() for p in tracked + untracked if p}
for name in sorted(paths):
    path = root / name
    if not path.is_file():
        continue  # tracked deletions
    if re.search(r'(^|/)(build|\.dart_tool|\.idea|Pods|ephemeral)/|\.(apk|aab|jks|keystore|pyc)$|(^|/)(local|key)\.properties$|(^|/)\.env(?:\.|$)', name):
        errors.append(f'Private/generated artifact would be published: {name}')
    if name.startswith(('docs/licenses/',)):
        continue  # third-party notices are retained verbatim
    if path.suffix in {'.md', '.dart', '.py', '.sh', '.json', '.yaml', '.yml', '.kts'}:
        text = path.read_text(errors='replace')
        if re.search(r'/(Users|home)/[^/\s]+/(StudioProjects|FlutterDev|Library)/|/(opt/homebrew|Applications/Kiro\.app)/?', text):
            errors.append(f'Machine-specific path in {name}')
    if path.suffix == '.md' and (name == 'README.md' or name.startswith('docs/') or name.startswith('.kiro/specs/')):
        for target in re.findall(r'\[[^\]]*\]\(([^)]+)\)', path.read_text()):
            if '://' in target or target.startswith(('#', 'mailto:')):
                continue
            target = target.split('#')[0].split(' "')[0].strip('<>')
            if target and not (path.parent / target).exists():
                errors.append(f'Broken local link in {name}: {target}')

probes = [str(p.relative_to(root)) for p in (root / '.kiro').rglob('*') if p.is_file()]
ignored = subprocess.run(['git', 'check-ignore', '--no-index', '--', *probes], cwd=root,
                         capture_output=True, text=True)
if ignored.returncode not in (0, 1):
    errors.append('Could not validate .kiro ignore rules')
elif ignored.stdout.strip():
    errors.append('.kiro evidence would be ignored: ' + ignored.stdout.strip())
for name in ['build/app/outputs/flutter-apk/app-release.apk', 'android/key.properties', '.env', 'private.jks']:
    result = subprocess.run(['git', 'check-ignore', '--no-index', '--', name], cwd=root, capture_output=True)
    if result.returncode != 0:
        errors.append(f'Private/generated path is not ignored: {name}')
if len(list((root / 'assets/audio').glob('*.wav'))) != 20:
    errors.append('Expected 20 licensed original sound assets')
inventory = (root / 'docs/licenses/DEPENDENCIES.md').read_text() if (root / 'docs/licenses/DEPENDENCIES.md').exists() else ''
lock_names = re.findall(r'^  (\w+):$', (root / 'pubspec.lock').read_text(), re.M)
for package in lock_names:
    if f'| {package} |' not in inventory:
        errors.append(f'Dependency missing from notices: {package}')
if errors:
    print('\n'.join(errors))
    sys.exit(1)
print(f'Release source checks passed: {len(paths)} files, .kiro retained, local links and notices complete.')
