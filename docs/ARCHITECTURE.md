# Architecture

TactileMac is a native Swift/SwiftUI macOS app. It uses AppKit where required (haptics, global events, menus, file panels) and keeps the audio/input layers independent of SwiftUI.

## Module map

```
TactileMac/
  App/
    TactileMacApp.swift        SwiftUI Window + optional MenuBarExtra
    AppModel.swift             ObservableObject owner; settings, packs, permissions, stats
    AppPaths.swift             Application Support locations, environment override
  Models/
    AppSettings.swift          Versioned Codable settings
    KeyCodeMap.swift           macOS key code ↔ W3C code ↔ sound category
    InputEvent.swift           Normalized input events and UI snapshot
    SoundPack.swift            Native manifest, clips, provenance, installed pack
  Input/
    InputMonitor.swift         Listen-only CGEventTap on a user-interactive thread
  Audio/
    AudioDecoder.swift         AVFoundation probe/decode to interleaved Float32 stereo
    AudioEngine.swift          AudioQueue output, voice mixing, device recovery
  SoundPacks/
    SafePath.swift             Relative-path and symlink validation
    PackValidator.swift        Structural validation, bundle loading, segment resolution
    LegacyKeyMap.swift        Legacy numeric key mapping
    LegacyPackImporter.swift  V1/V2/extended V2 detection and conversion
    PackImportService.swift    Folder/zip staging, validation, copy, normalized manifest
    PackRepository.swift       Built-in and user pack scan
  Haptics/
    HapticEngine.swift         Public NSHapticFeedbackManager only
  Permissions/
    PermissionService.swift    IOHIDCheckAccess, secure input, settings URLs
  Services/
    SettingsStore.swift        Atomic settings persistence and corrupt-file recovery
    FeedbackCoordinator.swift  Dedupe, debounce, rate limits, dispatch
    CapabilityService.swift    IORegistry trackpad capability read
  UI/
    RootView.swift, SidebarView.swift, Theme.swift, PackCard.swift
    KeyboardView.swift, TrackpadView.swift
    Pages/*.swift              Nine workspace pages and contextual settings panels
  Resources/
    BuiltInPacks/{thock,clicky,linear,soft}/
    Assets.xcassets, Notices/
```

## Event flow

```
CGEventTap (listen-only, background run loop)
        │  keyDown/keyUp/flagsChanged/mouseDown/scrollWheel
        ▼
InputMonitor ── normalizes ──► FeedbackCoordinator (locks, no UI work)
                                   │                  │
                     AudioEngine.play()        HapticEngine.tick()
                     (thread-safe)             (main-queue AppKit call)
                                   │
                               UI snapshot on main (throttled for scroll)
```

The event callback never decodes files, writes settings, or performs UI work. It reads only the hardware key code, modifier flags, button number, scroll delta, and continuous/momentum flags. It does not read Unicode text.

### Keyboard deduplication

- `InputMonitor` tracks pressed key codes and suppresses duplicate non-repeat downs.
- `FeedbackCoordinator` tracks pressed codes again, suppresses duplicate downs, and ignores key-up for a key that was not seen down.
- `CGEvent` autorepeat is suppressed unless "Play key-repeat sounds" is enabled.
- `flagsChanged` toggles modifiers; Caps Lock is treated as a press every time because it reports lock state, not key state.
- Secure Event Input is checked at dispatch time. If active, no feedback and no key identity is retained.

### Trackpad filtering

- Clicks are debounced per button (`clickDebounceMs`, default 45 ms).
- Scrolling accumulates precise deltas; a sound is emitted only after a stride (8 precise points or 1 wheel step) and not more often than `scrollMinimumIntervalMs` (default 42 ms). Momentum is off by default. `preciseScrollOnly` excludes discrete mouse wheels.
- Haptic scroll ticks have an independent 120 ms minimum gap.
- Public APIs cannot map a click to the built-in trackpad. This is stated in the UI; click sounds may fire for mouse clicks too.

## Audio engine

`AudioEngine` uses `AudioQueue`, not `AVAudioEngine`. AudioQueue gives a small, explicit mixer with predecoded samples and measured event-to-first-mix times around 2.6–5.1 ms in testing.

- Output format: Float32, interleaved stereo, nominal default-device sample rate.
- Callback thread: a dedicated `.userInteractive` run loop with a keep-alive timer, so SwiftUI layout cannot starve audio.
- Queue: three buffers of `audioBufferFrames` (default 256; 128/256/512/1024 selectable).
- Decoding: AVFoundation opens each file and converts to interleaved stereo Float32 at the source rate. Decoding happens on pack load, never in the event callback.
- Mixing: up to 32 voices. Each voice has a start/end frame, independent pitch rate (`sourceRate / outputRate × 2^(semitones/12)`), linear interpolation with fractional phase, and a per-voice gain. The oldest voice is evicted when the pool is full.
- Limiter: final samples pass through `tanh`, preventing hard clipping when voices overlap.
- Resampling: per-voice ratio handles source-rate and output-rate changes; no re-encoding is done.
- Device changes: a CoreAudio property listener on `kAudioHardwarePropertyDefaultOutputDevice` schedules a debounced queue rebuild. Wake from sleep calls the same path. `AudioQueueStop/Dispose` and generation checks guard stale state.
- Idle behavior: the queue stays running and renders silence while monitoring is enabled. This is cheap but not zero-cost; it is documented rather than claiming an idle-release optimization that is not implemented.
- Failure isolation: a failed queue, missing pack, or missing event results in no sound; it never crashes the input tap or disables haptics.

### Latency reporting

- **Measured in-app**: coordinator receives a timestamp when a sound is enqueued; the AudioQueue callback records when the voice is first mixed. Displayed as event → first mixed buffer. This is a real measurement but excludes the DAC/amplifier/drivers/room.
- **Reported by CoreAudio**: hardware buffer frames, device latency, and safety offset summed. This is driver-reported, not acoustically measured.
- The app explicitly says no end-to-end acoustic latency measurement was performed.

Measured on the test machine (MacBook Pro Speakers, 48 kHz, 512-frame hardware buffer):
- CoreAudio-reported output component: **14.4 ms**.
- WAV event-to-first-mix: **2.8–5.1 ms** across runs.
- Ogg Vorbis event-to-first-mix: **0.4 ms** in the engine integration test.

## Sound-pack pipeline

1. **Stage**: folder contents or a zip are copied into `Application Support/TactileMac/Imports/<UUID>`. Symlinks are rejected, file counts and total size are bounded, and zip entry names are checked before extraction.
2. **Locate** a single pack root (`tactilemac.pack.json` or `config.json`).
3. **Detect** native / legacy V1 / legacy V2 / extended V2.
4. **Convert** third-party schemas into an in-memory native `PackManifest`; never rewrite the source `config.json`.
5. **Validate** event names, relative paths, extensions, clip counts, gains/pitch, and segment syntax.
6. **Decode-prove** every referenced audio file and resolve every segment to frames; warn/clamp/skip only with recorded warnings.
7. **Install**: copy the source tree unchanged, write `tactilemac.pack.json` (third-party imports only) and `tactilemac.import.json` provenance atomically; reject duplicate IDs.
8. **Scan**: `PackRepository` lists built-in and user packs, validates manifests, and surfaces issues/warnings.
9. **Load**: the selected keyboard and trackpad packs are decoded on a background queue, installed in the engine, and activated. Preview loads a pack on demand if necessary.

Native packs require all files to exist and validate. Legacy and extended V2 conversion drops only definitions whose files are absent or unsupported, records a warning for each, and fails the import if no usable event remains.

## Haptics

- `NSHapticFeedbackManager.defaultPerformer.perform(_:performanceTime: .now)` with `.generic`, `.alignment`, or `.levelChange`.
- There is no public intensity parameter, arbitrary waveform API, or capability query. The UI offers a pattern picker and explicitly says intensity is not available.
- Hardware presence is read from public IORegistry services. On this machine `AppleMultitouchDevice` reports `ActuationSupported=1`, `ForceSupported=1`, `TrackpadEmbedded=1`.

## Persistence and failure behavior

- Settings are JSON at `~/Library/Application Support/TactileMac/settings.json`, schema-versioned.
- Writes are atomic and debounced; app termination flushes.
- An unreadable settings file is backed up as `settings.invalid-<timestamp>.json` and defaults are restored with a UI warning.
- A settings file from a newer schema is rejected rather than silently downgraded.
- Removing a user pack deletes its installed copy only; the original import source is untouched.
- Built-in packs are locked.

## UI composition

- `WindowGroup("TactileMac", id: "main")` plus an optional `MenuBarExtra` bound to a persisted toggle.
- Wide layout: 220 pt sidebar, flexible center, 336 pt contextual settings panel. Below 1180 pt, the settings panel stacks under the center inside a single scroll view.
- Keyboard/trackpad visuals are explicitly labeled simulated. They do not display typed characters or claim raw touch data.
- Every control mutates `AppModel` state or opens a real file panel/system settings page; there are no decorative toggles.
- Semantic colors and `@Environment(\.colorScheme)` branches provide light/dark support; the app icon and built-in packs are generated assets.
