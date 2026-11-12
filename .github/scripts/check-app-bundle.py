#!/usr/bin/env python3
"""Check an archived Playerz.app for what App Store Connect rejects on upload.

    .github/scripts/check-app-bundle.py <Playerz.app> <marketing version> <build number>

Adapted from agrent-ios's check of the same name. A rejection arrives as an
email minutes after a green workflow, with an ITMS code and no link back to
the run; everything here is decidable from the bundle on the runner, so the
run goes red instead and says which.

It reads the PROCESSED Info.plist inside the product: the value after
build-setting substitution is what Apple sees.
"""
import pathlib, plistlib, sys

if len(sys.argv) != 4:
    print('usage: check-app-bundle.py <Playerz.app> <marketing version> <build number>')
    sys.exit(2)
app, marketing, build = pathlib.Path(sys.argv[1]), sys.argv[2], sys.argv[3]

if not (app / 'Info.plist').is_file():
    print('::error::%s has no Info.plist, so nothing was checked.' % app)
    sys.exit(1)
info = plistlib.loads((app / 'Info.plist').read_bytes())
problems = []

def expect(key, want, why):
    got = info.get(key)
    if got != want:
        problems.append('%s is %r, expected %r — %s' % (key, got, want, why))

expect('CFBundleIdentifier', 'bg.playerz.app', 'the App Store Connect record is keyed on it')
expect('CFBundleShortVersionString', marketing, 'MARKETING_VERSION in project.yml')
expect('CFBundleVersion', build, 'the build number this run set; a repeat is refused')
expect('ITSAppUsesNonExemptEncryption', False,
       'absent, every build waits on the export-compliance questionnaire')
expect('PlayerzServerURL', 'https://playerz.bg',
       'a Release build has no field to type a server into')

# The Google button exists only with the app's iOS client (SessionModel).
# Without it a TestFlight build has no way in: production refuses passwords.
client = info.get('PlayerzGoogleClientID') or ''
if not client.endswith('.apps.googleusercontent.com'):
    problems.append('PlayerzGoogleClientID is %r — set PLAYERZ_GOOGLE_CLIENT_ID in project.yml, '
                    'or the build cannot sign anyone in' % client)

for key, value in info.items():
    if isinstance(value, str) and '$(' in value:
        problems.append('%s still contains an unresolved build setting: %r' % (key, value))

if 'UILaunchScreen' not in info and 'UILaunchStoryboardName' not in info:
    problems.append('no UILaunchScreen / UILaunchStoryboardName')

icon = info.get('CFBundleIcons', {}).get('CFBundlePrimaryIcon', {}).get('CFBundleIconName')
if icon != 'AppIcon':
    problems.append('CFBundleIcons.CFBundlePrimaryIcon.CFBundleIconName is %r — the '
                    'AppIcon set did not compile in' % icon)
if not (app / 'Assets.car').is_file():
    problems.append('no Assets.car — the asset catalog (and the icon) is missing')

# ITMS-91053: required-reason APIs need a manifest at the bundle root.
if not (app / 'PrivacyInfo.xcprivacy').is_file():
    problems.append('no PrivacyInfo.xcprivacy at the bundle root (ITMS-91053)')

# DebugLaunch signs in from environment variables; it is `#if DEBUG` and must
# not reach a phone. Its variable names are the marker (positive control: a
# Debug build's binary contains them).
for binary in [p for p in app.iterdir() if p.name in ('Playerz', 'Playerz.debug.dylib')]:
    if b'PLAYERZ_EMAIL' in binary.read_bytes():
        problems.append('%s contains DebugLaunch (PLAYERZ_EMAIL): a Debug build' % binary.name)

if problems:
    print('\n'.join(problems))
    print('::error::This bundle would be refused, or would not work. Fix the above before uploading.')
    sys.exit(1)
print('%s: bg.playerz.app %s (%s), playerz.bg, Google client, icon, privacy manifest, '
      'no DebugLaunch.' % (app.name, marketing, build))
