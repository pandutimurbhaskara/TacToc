# Feasibility and Verified Capabilities

Testing environment:

- macOS 15.6.1 (24G90), Apple M1 MacBook Pro (`MacBookPro17,1`), 16 GB.
- Xcode 16.4 (16F6), Swift 6.1.2, macOS SDK 15.5.
- XcodeGen 2.46.0.
- Default output: MacBook Pro Speakers, 48 kHz, 512-frame hardware buffer.
- Input Monitoring TCC status for the development/test context: **denied**. Accessibility trust: **false**.
- No Developer ID code-signing identity and no notary credentials.

## Verified by execution

| Capability | Status | Evidence |
| --- | --- | --- |
| Native SwiftUI app builds and launches as a full window | Verified | Debug and Release builds succeeded; UI tests launched the window; window registered at 1280×794. |
| Three-column UI, navigation, settings panels | Verified | 7 UI tests: window, all nine pages, permission guidance, profile selection, toggle persistence, sound-pack import flow, pack list. |
| Settings persist across relaunch | Verified | UI test toggled keyboard sounds off, relaunched, observed off. |
| AudioQueue engine starts, accepts a decoded WAV, mixes it, and rebuilds | Verified | `AudioEngineTests`; event-to-first-mix 2.6–5.1 ms; reported output latency 14.4 ms. |
| Ogg Vorbis file decodes to PCM | Verified | Real 51.7 s stereo 44.1 kHz legacy pack OGG; `AVAudioFile` frame count 2,280,385. |
| Ogg Vorbis reaches AudioQueue and plays | Verified | Engine integration test loaded an extended V2 fixture, decoded its OGG, played `key.down.KeyA`, and observed first mix. |
| Ogg Opus, MP3, FLAC, WAV decode | Verified on this OS | Generated Ogg Opus, MP3/FLAC/WAV probes; real MP3/OGG pack assets loaded by the corpus harness. Not assumed for every `.ogg`. |
| Native pack validation, path traversal rejection, symlink rejection, segment bounds | Verified | Unit tests / import tests. |
| Legacy V1 single/multi conversion | Verified | Committed fixtures + 18/18 actual legacy packs loaded. |
| Legacy V2 fallback, `-up` files, single-file timed key-up, `{0-N}` ranges | Verified | Committed fixtures + real `cherrymx-black-abs`, `mxblue-travel`; 18/18 legacy packs loaded. |
| Extended V2 `[start,end]` conversion, mouse/wheel mapping | Verified | Committed fixtures + 14/14 extended V2 packs loaded. |
| Full reference corpus | Verified | 32/32 packs converted and fully decoded; 46 warnings, 0 failures. |
| Import preserves source `config.json`; writes normalized manifest/provenance | Verified | `ImportServiceTests`; UI import test. |
| Zip import with nested pack root | Verified | Unit test using `ditto`-created zip. |
| Haptic-capable trackpad detection via public IORegistry | Verified | `AppleMultitouchDevice` reports `ActuationSupported=1`, `ForceSupported=1`, `TrackpadEmbedded=1`. |
| Public haptic API object is available | Verified | `NSHapticFeedbackManager.defaultPerformer` instantiated on this machine. |
| Release build universal arm64+x86_64, hardened runtime, DMG | Verified | `lipo -archs` = `x86_64 arm64`; `codesign` Runtime Version 15.5.0; DMG created. |
| Ad-hoc signing only; not notarized | Verified | `codesign`: `Signature=adhoc`, `TeamIdentifier=not set`; `spctl` rejects DMG with `no usable signature`. |

## Implemented but not physically verified

| Capability | Status | Why |
| --- | --- | --- |
| Delivery of real global keyboard events | Not verified | Input Monitoring is denied in this environment. The app detects status and does not start the tap until granted. |
| Audible keyboard/trackpad sounds | Not verified by ear | The engine is tested to mix and output; no human listening test was performed. |
| Physical keyboard press/release behavior and rapid typing | Not verified | Same permission limitation. |
| Real trackpad click/scroll event delivery | Not verified | Requires granted Input Monitoring and human interaction; not performed. |
| Physical haptic sensation | Not verified | Software cannot detect whether a person felt the actuator; no in-person test was performed. |
| External Magic Trackpad haptics | Not verified | No external trackpad was available for testing. |
| Secure Event Input behavior at a real password prompt | Not verified | The status API is implemented and polled; no protected prompt was exercised. |
| Output-device switching during playback with real headphones/Bluetooth | Not verified | Queue rebuild is implemented and unit-tested by calling `rebuild()`, not with a live device swap. |
| Sleep/wake recovery | Not verified | Notification path exists; no sleep/wake test was run. |
| OGG support on macOS 14 | Not verified | All OGG testing was on macOS 15.6.1. The app fails gracefully if the OS decoder rejects a file. |

## Deliberately not implemented / not claimed

- No private `MultitouchSupport` actuator access. Public AppKit haptics only. Research is documented; no private code is in the production path.
- No haptic intensity slider. Public AppKit exposes three patterns, not arbitrary strength.
- No claim that public APIs expose physical touch count, position, pressure, force stages, or arbitrary gestures. Trackpad audio is limited to button-down and precise scroll.
- No built-in trackpad-vs-mouse click attribution. Click audio may play for any pointing device.
- No media-key capture, no NSEvent gesture claim, no UI element hover detection, no Accessibility tree access.
- No output-device picker; the app follows the system default and rebuilds on change.
- No idle audio-queue shutdown; the queue renders silence while enabled. This is documented.
- No Developer ID signing or notarization; credentials absent.

## Technical risks

1. **Input Monitoring and app identity.** Changing the bundle identifier or signing identity can reset TCC approval. A distributed build should keep a stable Developer ID and bundle ID.
2. **Private/undocumented trackpad capabilities.** Not used; public haptic presets may not satisfy users who expect intensity control.
3. **OGG support is OS-version dependent.** The app probes every file; import failures are explicit.
4. **Ambiguous legacy key codes.** A small number of extended codes have conflicting historical meanings; unsupported/ambiguous definitions are reported.
5. **Haptic hardware variation.** External trackpads and older Macs may differ; the UI reports what IORegistry exposes and never claims physical confirmation.
