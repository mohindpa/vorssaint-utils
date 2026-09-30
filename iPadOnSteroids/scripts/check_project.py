#!/usr/bin/env python3
"""Structural validation only; not a Swift compiler or Xcode substitute."""
from pathlib import Path
import plistlib
import re
import xml.etree.ElementTree as ET
root = Path(__file__).resolve().parents[1]
project = (root / 'iPadOnSteroids.xcodeproj/project.pbxproj').read_text()
ids = re.findall(r'^([A-F0-9]{24}) =', project, re.M)
assert len(ids) == len(set(ids)), 'Duplicate object IDs'
refs = set(re.findall(r'\b[A-F0-9]{24}\b', project))
assert refs == set(ids), f'Dangling project references: {refs - set(ids)}'
for path in [*root.glob('App/*.swift'), *root.glob('Tests/*.swift')]:
    assert f'path = "{path.name}";' in project, f'Missing source {path}'
scheme = ET.parse(root / 'iPadOnSteroids.xcodeproj/xcshareddata/xcschemes/iPadOnSteroids.xcscheme')
for ref in scheme.findall('.//BuildableReference'):
    assert ref.attrib['BlueprintIdentifier'] in refs
privacy = plistlib.loads((root / 'App/PrivacyInfo.xcprivacy').read_bytes())
assert privacy['NSPrivacyTracking'] is False
assert len(privacy['NSPrivacyAccessedAPITypes']) == 2
assert 'PrivacyInfo.xcprivacy' in project
assert 'IPHONEOS_DEPLOYMENT_TARGET = 17.0' in project
assert 'TARGETED_DEVICE_FAMILY = 2' in project
print(f'PASS: {len(ids)} unique project objects; no dangling references; all Swift files included; scheme XML and privacy plist parse; iPadOS target configured')
