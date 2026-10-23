# Release

## Current artifact in this environment

`./scripts/make_dmg.sh` builds a universal Release app and a drag-install DMG:

```
dist/TactileMac-0.1.0.dmg
SHA-256: 616768b94576d7f94c0ef3c7d44eabce6c807518d3183eee7792fa5b30c17b2d
Size: ~3.5 MB
Architectures: x86_64 arm64
Bundle ID: com.tactilemac.app
Version: 0.1.0 (1)
Minimum macOS: 14.0
```

Verification performed:

- `codesign --verify --deep --strict`: valid on disk, satisfies its Designated Requirement.
- `codesign -dv`: `Signature=adhoc`, `TeamIdentifier=not set`, `Runtime Version=15.5.0`.
- `lipo -archs`: `x86_64 arm64`.
- `spctl -a -vvv`: **rejected**, `source=no usable signature`.
- Notarization: **not attempted/available**. No Developer ID identity and no notary credentials exist in this environment (`security find-identity` returned 0 identities; `notarytool` had no stored credentials).

This is an unsigned/ad-hoc local build, not a trusted distributed release. Do not describe it as signed, notarized, or Gatekeeper-approved.

## Build requirements

- macOS 14+ development host.
- Xcode 16.4 with Swift 6.1.2.
- XcodeGen 2.46.0 (or build the committed `.xcodeproj`).
- No third-party libraries or package downloads.

## Reproducible build

```bash
xcodegen generate
./scripts/make_dmg.sh
```

The script:

1. Cleans `build/release` and `dist/dmg-stage`.
2. Runs `xcodebuild` with `ARCHS="arm64 x86_64"`, `ONLY_ACTIVE_ARCH=NO`, `CODE_SIGN_IDENTITY="-"`, Release configuration.
3. Copies `TactileMac.app` and an `/Applications` symlink into a staging folder.
4. Verifies the ad-hoc signature and reports architectures.
5. Creates `dist/TactileMac-<version>.dmg` with `hdiutil`.
6. Writes a SHA-256 file.

The project has App Sandbox disabled (global event taps and arbitrary user-selected pack imports are not compatible with the sandbox as implemented). Hardened Runtime is enabled for Release.

## Developer ID signing and notarization (not performed)

When credentials are available:

```bash
# 1. Find the Developer ID Application identity
security find-identity -v -p codesigning

# 2. Build with that identity (replace TEAM_ID and identity name)
xcodebuild -project TactileMac.xcodeproj -scheme TactileMac \
  -configuration Release -derivedDataPath build/release \
  -destination 'platform=macOS' ARCHS="arm64 x86_64" ONLY_ACTIVE_ARCH=NO \
  CODE_SIGN_STYLE=Manual DEVELOPMENT_TEAM=TEAM_ID \
  CODE_SIGN_IDENTITY="Developer ID Application: Your Name (TEAM_ID)" build

# 3. Sign helpers (none bundled) and the app with a secure timestamp
codesign --force --options runtime --timestamp \
  --sign "Developer ID Application: Your Name (TEAM_ID)" \
  build/release/Build/Products/Release/TactileMac.app

# 4. Verify
codesign --verify --deep --strict --verbose=2 \
  build/release/Build/Products/Release/TactileMac.app

# 5. Create the DMG (staging app + Applications symlink), then submit
xcrun notarytool submit dist/TactileMac-0.1.0.dmg \
  --keychain-profile "tactilemac-notary" --wait
xcrun stapler staple dist/TactileMac-0.1.0.dmg
xcrun stapler validate dist/TactileMac-0.1.0.dmg
spctl -a -vvv dist/TactileMac-0.1.0.dmg
```

Use `xcrun notarytool store-credentials` once to create the keychain profile. Never commit certificates, API keys, app-specific passwords, or keychain profiles.

The release must be re-signed *after* the final build and before DMG creation; do not sign the staging copy after creating the disk image.

## Signing/entitlements notes

- Bundle ID: `com.tactilemac.app`; changing it resets Input Monitoring approval.
- Hardened Runtime: yes in Release.
- App Sandbox: off.
- No private framework linkage.
- No `com.apple.security.*` sandbox entitlements are required by the current implementation.
- Input Monitoring is a TCC privacy approval, not an entitlement. A Developer ID signature makes the identity stable for that approval.

## Distribution checklist

- [x] Project builds Debug and Release.
- [x] 55 unit/integration tests pass.
- [x] 7 UI tests pass.
- [x] Universal Release binary built.
- [x] DMG created and SHA-256 recorded.
- [x] Built-in audio/icon generated and licensed for redistribution.
- [x] No third-party audio or source copied.
- [ ] Developer ID signature applied.
- [ ] Notarization submitted and stapled.
- [ ] `spctl` accepted on a clean Mac.
- [ ] Human hardware test with Input Monitoring granted (keyboard, trackpad, haptics).
- [ ] Human audible test on speakers/headphones.
- [ ] External trackpad test.

The unchecked items require credentials, human interaction, or hardware not available in this environment.

## Gatekeeper and local testing

Because the current DMG is ad-hoc and not notarized, Gatekeeper rejects it as distributed material. For local testing only, a user may right-click the app and choose Open, or remove the quarantine attribute from a build they made themselves. Do **not** distribute instructions that normalize bypassing Gatekeeper for untrusted binaries; the correct release path is Developer ID plus notarization.

## Versioning

- Marketing version: `0.1.0`.
- Build: `1`.
- Native pack schema: `tactilemac.pack` v1.
- Settings schema: 1.
- Converter version: 1 (`TactileMac.import.json`).
