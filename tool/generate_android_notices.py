#!/usr/bin/env python3
"""Audit a Gradle releaseRuntimeClasspath report against cached Maven POMs."""
import argparse
from pathlib import Path
import re
import xml.etree.ElementTree as ET
import zipfile
import subprocess
from concurrent.futures import ThreadPoolExecutor

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('report', type=Path)
parser.add_argument('--cache', type=Path,
                    default=Path.home() / '.gradle/caches/modules-2/files-2.1')
parser.add_argument('--fetch-poms', action='store_true', help='Fetch missing POMs from Google Maven/Maven Central')
args = parser.parse_args()
root = Path(__file__).resolve().parent.parent
artifacts = set()
for line in args.report.read_text().splitlines():
    match = re.search(r'(?:\+---|\\---) ([\w.]+):([\w.-]+):([\w.-]+)(?: -> ([\w.-]+))?', line)
    if match:
        group, artifact, version, selected = match.groups()
        artifacts.add((group, artifact, selected or version))
if not artifacts:
    raise SystemExit('No dependencies found in Gradle report')
pom_cache = root / 'build/license-poms'
pom_cache.mkdir(parents=True, exist_ok=True)
def pom_file(coordinate):
    group, artifact, version = coordinate
    cached = list((args.cache / group / artifact / version).rglob('*.pom'))
    local = pom_cache / f'{group}-{artifact}-{version}.pom'
    if cached:
        return cached[0]
    if local.exists():
        return local
    if not args.fetch_poms or group == 'io.flutter':
        return None
    base = ('https://dl.google.com/dl/android/maven2/' if group.startswith('androidx.')
            else 'https://repo.maven.apache.org/maven2/')
    url = base + group.replace('.', '/') + f'/{artifact}/{version}/{artifact}-{version}.pom'
    try:
        data = subprocess.run(['curl', '--fail', '--silent', '--show-error',
                               '--location', '--max-time', '20', url],
                              check=True, capture_output=True).stdout
        ET.fromstring(data)
        local.write_bytes(data)
        return local
    except Exception as error:
        print(f'POM unavailable for {group}:{artifact}:{version}: {type(error).__name__}')
        return None
coordinates = sorted(artifacts)
with ThreadPoolExecutor(max_workers=8) as pool:
    pom_files = dict(zip(coordinates, pool.map(pom_file, coordinates)))
rows, notices, problems = [], [], []
for group, artifact, version in sorted(artifacts):
    directory = args.cache / group / artifact / version
    if group == 'io.flutter':
        license_name = 'Flutter BSD-3-Clause and combined engine notices'
        source = 'https://github.com/flutter/flutter'
    else:
        pom_path = pom_files[(group, artifact, version)]
        if pom_path is None:
            problems.append(f'Missing POM: {group}:{artifact}:{version}')
            continue
        pom = ET.fromstring(pom_path.read_bytes())
        ns = {'m': 'http://maven.apache.org/POM/4.0.0'}
        declared = [(l.findtext('m:name', namespaces=ns) or '',
                     l.findtext('m:url', namespaces=ns) or '')
                    for l in pom.findall('m:licenses/m:license', ns)]
        # Maven licenses may be inherited from a parent (Guava, for example).
        seen_parents = set()
        while not declared:
            parent = pom.find('m:parent', ns)
            if parent is None:
                break
            coord = tuple(parent.findtext('m:' + key, namespaces=ns) or ''
                          for key in ['groupId', 'artifactId', 'version'])
            if coord in seen_parents:
                break
            seen_parents.add(coord)
            parent_path = pom_file(coord)
            if parent_path is None:
                break
            pom = ET.fromstring(parent_path.read_bytes())
            declared = [(l.findtext('m:name', namespaces=ns) or '',
                         l.findtext('m:url', namespaces=ns) or '')
                        for l in pom.findall('m:licenses/m:license', ns)]
        if not declared or any(not any(k in (n + u).lower() for k in ['apache', 'bsd-3-clause']) for n, u in declared):
            problems.append(f'Review POM license: {group}:{artifact}:{version}: {declared}')
            continue
        license_name = 'BSD-3-Clause' if 'BSD-3-Clause' in str(declared) else 'Apache-2.0'
        source = declared[0][1]
    rows.append(f'| {group}:{artifact} | {version} | {license_name} | {source} |')
    for file in directory.rglob('*'):
        if file.suffix not in {'.jar', '.aar'}:
            continue
        with zipfile.ZipFile(file) as archive:
            for name in archive.namelist():
                if re.search(r'(?:^|/)(?:NOTICE|LICENSE|COPYING)(?:[./_-]|$)', name, re.I):
                    data = archive.read(name).decode('utf-8', errors='replace')
                    notices.append(f'\n=== {group}:{artifact}:{version} / {name} ===\n{data}')
if problems:
    raise SystemExit('\n'.join(problems))
(root / 'docs/licenses/ANDROID_DEPENDENCIES.md').write_text(
    '# Android release dependencies\n\nResolved `releaseRuntimeClasspath` Maven coordinates; '
    'licenses checked against cached POMs. Flutter notices are retained separately.\n\n'
    '| Component | Version | License | License/source URL |\n| --- | --- | --- | --- |\n'
    + '\n'.join(rows) + '\n')
(root / 'docs/licenses/ANDROID_ARCHIVE_NOTICES.txt').write_text(
    'License/notice files retained verbatim from resolved native JAR/AAR archives.\n'
    + ''.join(dict.fromkeys(notices)))
print(f'Audited {len(rows)} Maven components and retained {len(notices)} archive notices.')
