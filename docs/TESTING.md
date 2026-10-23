# Testing

## Environment

- macOS 15.6.1 (24G90), Apple M1 MacBook Pro, 16 GB.
- Xcode 16.4 (16F6), Swift 6.1.2, macOS SDK 15.5.
- Default output: MacBook Pro Speakers, 48 kHz, 512-frame hardware buffer.
- Input Monitoring: **denied** for the development/test context; Accessibility: **false**.
- No Developer ID signing identity or notary profile.

## Commands

```bash
xcodegen generate

# Unit + integration (55 tests, including an OGG-through-engine test)
xcodebuild -project TactileMac.xcodeproj -scheme TactileMac \
  -configuration Debug -destination 'platform=macOS' \
  test -only-testing:TactileMacTests -parallel-testing-enabled NO

# UI tests
xcodebuild -project TactileMac.xcodeproj -scheme TactileMac \
  -configuration Debug -destination 'platform=macOS' \
  test -only-testing:TactileMacUITests -parallel-testing-enabled NO
```

## Results

| Suite | Tests | Result |
| --- | --- | --- |
| `TactileMacTests` (unit/integration) | **55** | **0 failures** |
| `TactileMacUITests` | **7** | **0 failures** |
| Reference pack corpus harness (not committed; requires `.refs`) | **32 packs** | **32 loaded, 0 failures**, 46 warnings |

The reference corpus harness compiled the importer/loader sources and processed:

- 18 legacy packs → 18/18 loaded.
- 14 extended V2 packs → 14/14 loaded.
- Warnings: missing legacy `author` fields, unsupported Windows-only keys (`Insert`, `Pause`, `PrintScreen`, `ScrollLock`, ContextMenu 3677), and six dangling explicit files in `mxblue-travel` that are covered by its `{0-4}` fallback range.

## Automated coverage

- `SettingsTests` — defaults, round-trip persistence, missing/corrupt/newer files, clamping.
- `KeyMappingTests` — physical key codes, event resolution order, legacy codes, mouse release codes, unsupported events.
- `AudioDecodeTests` — WAV and Ogg Vorbis probe/decode, corrupt/empty files.
- `AudioEngineTests` — AudioQueue start, WAV voice mixed, latency measurement, rebuild, **OGG clip loaded and played**.
- `PackValidationTests` — native fixture validity/load, traversal, symlink escape, missing files, bad timing, unsupported keys, out-of-bounds segments.
- `LegacyPackImporterTests` — V1 single/multi, legacy V2 fallback/key-up/range, extended V2 timing/mouse, direct timing arrays, missing files, malformed JSON, unsupported version, unsupported key warnings.
- `ImportServiceTests` — native import, source preservation, extended V2 provenance, V1 segments, traversal/missing/future rejection, duplicate ID, zip/nested root.
- `RepositoryTests` — built-in/user scan, duplicate IDs, raw folder warning.
- `BuiltInPackTests` — all four built-ins validate and fully load.
- `SmokeTests` — product defaults.

UI tests (7):

1. `testWindowLaunchesOnOverview`
2. `testSidebarNavigatesEveryPage`
3. `testPermissionGuidanceIsVisible`
4. `testKeyboardTogglePersistsAcrossRelaunch`
5. `testProfileSelectionUpdatesSelectedProfile`
6. `testSoundPackImportFlow` (uses a DEBUG/`--ui-testing`-only trigger because automating the native open panel is not reliable; it exercises the actual import service, UI state, rescan, and success view)
7. `testSoundPacksPageShowsBuiltInPacks`

## Audio measurements

Measured on this machine by `AudioEngineTests`:

- Device: MacBook Pro Speakers.
- Nominal rate: 48,000 Hz; hardware buffer: 512 frames.
- CoreAudio-reported output components: **14.4 ms** (1.38 ms device + 2.35 ms safety offset + 10.67 ms buffer).
- WAV event → first mixed buffer: **2.58–5.09 ms** across runs.
- Ogg Vorbis event → first mixed buffer: **4.88 ms** in the final run.
- The engine rebuilds successfully after a programmatic `rebuild()`.

These are in-app scheduling measurements plus driver-reported components. They are **not** end-to-end acoustic measurements; DAC, amplifier, speaker/headphone, and room latency are excluded. No human listening test was performed.

## Hardware test status

| Test | Status | Notes |
| --- | --- | --- |
| Real global key-down/up delivery | **Not performed** | Input Monitoring denied; no TCC bypass attempted. |
| Rapid typing, modifier, Caps Lock, key repeat | **Not performed** | Same. |
| Physical trackpad click/scroll | **Not performed** | Same; also requires human interaction. |
| Built-in vs external trackpad click attribution | **Not possible/verified** | No reliable public API identified. |
| Audible keyboard/trackpad sound | **Not performed by ear** | Engine mixing is verified. |
| Built-in trackpad haptic feel | **Not performed** | Haptic-capable hardware detected; API invocation exists; software cannot feel it. |
| External trackpad haptics | **Not performed** | No external trackpad available. |
| Secure Event Input at a password prompt | **Not performed** | Status API implemented, not exercised. |
| Output-device swap / sleep-wake | **Not performed live** | Rebuild path unit-tested via `rebuild()`; CoreAudio listener installed. |
| macOS 14 OGG behavior | **Not verified** | OGG tested on 15.6.1 only. |

## Reference pack compatibility

The actual reference corpus is not vendored (`.refs/` is gitignored); the committed fixtures reproduce the schemas. The local harness is not committed; the committed fixtures reproduce the schemas. All 32 inspected packs validated and fully decoded; this is stronger than only checking JSON syntax because every referenced audio file was decoded.

## Fixtures and licenses

All fixtures are generated by `scripts/generate_fixtures.py` from original tones. The OGG fixture is encoded from that generated WAV. Fixture audio is CC0-1.0. No third-party assets are in the test suite.

## Environment quirks

- Xcode emitted result-bundle staging warnings (`mkstemp`/CAS database) after some UI runs; test execution itself reported success and zero failures.
- The native screen-capture tool lacked Screen Recording permission; UI layout was reviewed using screenshots captured by XCUITest instead.
- XCUITest required the app to be ad-hoc signed; tests ran successfully with local signing.
- No test attempted to bypass TCC or alter system privacy settings.

## Manual acceptance checklist

A human with granted Input Monitoring should:

1. Type in TextEdit and listen for key-down/up sounds, including Space, Return, Delete, modifiers, and rapid repeats.
2. Confirm Secure Event Input pauses feedback in a password field.
3. Click and scroll on the built-in trackpad; confirm the click/scroll choices and throttle feel acceptable.
4. Press **Test haptic** and judge whether the selected pattern is felt; try all three patterns.
5. Import an extended V2 pack and a legacy pack from a folder and a zip; confirm previews and selection.
6. Switch output devices while typing; confirm audio recovers.
7. Relaunch and confirm settings/pack selections persist.
