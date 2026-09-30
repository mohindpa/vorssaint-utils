#!/usr/bin/env python3
"""Bound each native CI phase and terminate its process group on timeout."""
import os
from pathlib import Path
import signal
import subprocess
import sys
phase = sys.argv[1]
base = ['xcodebuild', '-project', 'iPadOnSteroids.xcodeproj', '-scheme', 'iPadOnSteroids']
if phase == 'device':
    command = base + ['-configuration', 'Release', '-destination', 'generic/platform=iOS', '-derivedDataPath', '.build-device', 'build', 'CODE_SIGNING_ALLOWED=NO']
    limit = 360
else:
    destination = 'platform=iOS Simulator,id=' + os.environ['SIMULATOR_ID']
    common = base + ['-destination', destination, '-derivedDataPath', '.build-native', 'CODE_SIGNING_ALLOWED=NO', 'ONLY_ACTIVE_ARCH=YES']
    if phase == 'build':
        command = common + ['build-for-testing']; limit = 360
    elif phase in ['unit', 'ui']:
        result = 'UnitResults.xcresult' if phase == 'unit' else 'UIResults.xcresult'
        target = 'iPadOnSteroidsTests' if phase == 'unit' else 'iPadOnSteroidsUITests'
        command = common + ['-resultBundlePath', result, '-parallel-testing-enabled', 'NO', '-only-testing:' + target, 'test-without-building']
        limit = 480 if phase == 'unit' else 600
    else:
        raise SystemExit('Unknown phase: ' + phase)
print('Native phase:', phase, 'timeout seconds:', limit, flush=True)
process = subprocess.Popen(command, start_new_session=True)
try:
    code = process.wait(timeout=limit)
except subprocess.TimeoutExpired:
    print('Native phase timed out:', phase, file=sys.stderr, flush=True)
    os.killpg(process.pid, signal.SIGTERM)
    try:
        process.wait(timeout=15)
    except subprocess.TimeoutExpired:
        os.killpg(process.pid, signal.SIGKILL)
        process.wait()
    raise SystemExit(124)
raise SystemExit(code)
