# Legacy Sound Packs: Formats and TactileMac Compatibility

This document describes the two legacy JSON families that the importer supports and how TactileMac converts them.

The families are **not interchangeable**. In particular:

1. Both families use `.ogg` files, but their timing semantics differ: legacy arrays are `[start_ms, duration_ms]`; extended V2 pairs are `[start_ms, end_ms]`.
2. Legacy versions use a `version` field; extended V2 uses `config_version`.
3. Legacy keys are numeric Windows virtual-key codes; extended V2 keys are W3C `KeyboardEvent.code` names.
4. Legacy V2 has `soundup` plus `-up` definitions and `{0-N}` ranges; extended V2 has `definitions` and `timing` arrays.

## 1. Legacy formats

### 1.1 V1 schema

From the legacy V1 parser and its embedded demo config:

```json
{
  "id": "custom-sound-pack-1582707445334",
  "name": "CherryMX Blue - PBT keycaps",
  "key_define_type": "single",
  "includes_numpad": false,
  "sound": "sound.ogg",
  "defines": {
    "30": [1203, 192],
    "57": [14881, 188]
  },
  "version": 1
}
```

| Field | Meaning |
| --- | --- |
| `id` | Pack identifier used by the app/store. |
| `name` | Display name. |
| `key_define_type` | `single` or `multi`. |
| `includes_numpad` | Required but marked unused. |
| `sound` | Main audio file; required even for `multi`. |
| `defines` | Numeric legacy key code → definition. |
| `version` | Optional; defaults to 1. |

For `single`, a definition is `[start_ms, duration_ms]` inside `sound`. The legacy player's sprite support plays that slice. For `multi`, a definition is a path to an individual audio file. V1 ignores key-up entirely (`HandleEvent` returns early for `keyup`). `defines` values may be `null` (as in `eg-oreo/config.json`), meaning no sound for that key.

### 1.2 Legacy V2 schema

From the legacy V2 parser and real packs such as `turquoise`, `cream-travel`, `mxblue-travel`, and `cherrymx-black-abs`:

```json
{
  "id": "custom-sound-pack-1720300926821",
  "name": "Turquoise (Full Travel)",
  "key_define_type": "multi",
  "sound": "press/GENERIC_R{0-4}.mp3",
  "soundup": "release/GENERIC.mp3",
  "defines": {
    "14": "press/BACKSPACE.mp3",
    "14-up": "release/BACKSPACE.mp3",
    "28": "press/ENTER.mp3",
    "28-up": "release/ENTER.mp3"
  },
  "version": 2
}
```

Important legacy V2 behavior:

- It fills every standard key with a null definition.
- For every standard key it chooses `defines[down] ?? sound` and `defines[up] ?? soundup`; this is a **global fallback fill**, not just per-defined keys.
- A filename containing `{a-b}` is resolved by choosing one random number in the range and substituting it at load time.
- `HandleEvent` for key-up appends `-up` to the key and looks up the corresponding sprite/file.
- The demo comment says `soundup` is not supported for `single`; however, at least one real pack (`cherrymx-black-abs`) uses a single `sound.ogg` with `-up` timing arrays. TactileMac supports those timed key-up entries rather than discarding them.

Real single-file timing example (`cherrymx-black-abs/config.json`):

```json
"30": [31542, 99],
"30-up": [31657, 77]
```

Both slices are in the same `sound.ogg`.

Real multi range example (`mxblue-travel/config.json`):

```json
"sound": "press/GENERIC_R{0-4}.mp3",
"soundup": "release/GENERIC.mp3",
"defines": {
  "14": "press/BACKSPACE.mp3",
  "28": "press/ENTER.mp3",
  "57": "press/SPACE.mp3"
}
```

The inspected copy contains `GENERIC_R0.mp3` … `GENERIC_R4.mp3` and `release/GENERIC.mp3`, but not the explicit BACKSPACE/ENTER/SPACE files. TactileMac expands the range fallback and uses it for those keys, while warning about the missing explicit files.

### 1.3 Legacy key codes

The legacy key table defines the standard numeric codes and platform remaps. TactileMac's mapping is in `SoundPacks/LegacyKeyMap.swift`. Common examples:

| Numeric code | W3C | Notes |
| --- | --- | --- |
| 1 | Escape | |
| 2–11 | Digit1–Digit0 | |
| 14 | Backspace | |
| 15 | Tab | |
| 16–25 | KeyQ…KeyP | |
| 28 | Enter | |
| 29 | ControlLeft | |
| 30–38 | KeyA…KeyL | |
| 42 | ShiftLeft | |
| 54 | ShiftRight | |
| 56 | AltLeft | |
| 57 | Space | |
| 58 | CapsLock | |
| 59–68 | F1–F10 | |
| 69 | NumLock | |
| 71–83 | Numpad7…NumpadDecimal | |
| 87–93 | F11–F15 | |
| 3597 | NumpadEqual | Legacy `=`/Clear ambiguity |
| 3612 | NumpadEnter | |
| 3613 | ControlRight | |
| 3637 | NumpadDivide | |
| 3639 | F13 | Chosen from the Darwin remapper rather than PrintScreen |
| 3653 | F15 | |
| 3655/3657/3663/3665 | Home/PageUp/End/PageDown | |
| 3666 | Help | Mac key code 114; PC Insert has no direct Mac key |
| 3667 | Delete | Forward delete |
| 3675/3676 | MetaLeft/MetaRight | Command |
| 3677 | Unsupported | ContextMenu |
| 57416/57419/57421/57424 | ArrowUp/Left/Right/Down | |
| 60999–61011 | Navigation/numpad variants | Windows-specific aliases; documented choices in code |

Ambiguities exist in the legacy ecosystem: one table labels 3639 as PrintScreen while the Darwin remapper swaps it with F13; extended values 61000–61011 differ between implementations. TactileMac chooses a physical Mac mapping, and reports any code it cannot map. It does not silently drop the definition.

For legacy **mouse** packs, definitions use codes `1`, `2`, `3` for left/right/middle. The extended V2 converter documents zero-padded codes (`"01"`, `"02"`) as releases. TactileMac detects these as releases and skips them with a warning because trackpad feedback is triggered on button-down only.

## 2. Extended V2

### 2.1 Schema

From the extended V2 format documentation, validator, converter, and sample configs:

```json
{
  "config_version": "2",
  "id": "keyboad-cherrymx-black-abs",
  "name": "CherryMX Black - ABS keycaps",
  "author": "Example Author",
  "definition_method": "single",
  "audio_file": "sound.ogg",
  "definitions": {
    "KeyA": {
      "timing": [[31542.0, 31627.0], [31627.0, 31712.0]]
    },
    "Space": {
      "timing": [[51541.0, 51684.5]]
    },
    "MouseLeft": {
      "timing": [[47.0, 84.0], [105.0, 177.0]]
    }
  },
  "options": {
    "recommended_volume": 1.0,
    "random_pitch": false
  },
  "icon": "black.jpg",
  "tags": []
}
```

Fields:

| Field | Meaning |
| --- | --- |
| `config_version` | String or number; `2` is current; >2 is rejected with "requires a newer version". |
| `id`, `name`, `author` | Identity/metadata; validator requires `name` and `author` (or the legacy `m_author` field). |
| `definition_method` | `single` (one `audio_file`) or `multi` (per-key `audio_file`). |
| `audio_file` | Main file for single packs. |
| `definitions` or `defs` | Key/button → `{ "timing": [[start_ms, end_ms], …] }`. The validator also accepts a direct timing array. |
| `options.recommended_volume` | 0…2 starting volume. |
| `options.random_pitch` | Boolean; the extended format describes ±10–15% pitch variation. |
| `soundpack_type` | `"Keyboard"` or `"Mouse"` override. |
| `icon`, `tags`, `description`, `version`, `created_at` | Metadata/UI. |

Key names follow W3C `KeyboardEvent.code`: `KeyA`…`KeyZ`, `Digit0`…`Digit9`, `Space`, `Enter`, `Escape`, `Backspace`, `ShiftLeft`, `ControlRight`, `AltLeft`, arrows, F1–F12, `Numpad*`, etc. Mouse packs use `MouseLeft`, `MouseRight`, `MouseMiddle`, `WheelUp`, `WheelDown`, `Button4`, `Button5`.

### 2.2 Timing and variants

- Extended V2 timing pairs are **[start, end] in milliseconds**, with fractional values allowed.
- Multiple pairs are playback variations. The extended V2 documentation says the app picks a random segment per press.
- The schema has no distinct key-up field in the documented V2 format; TactileMac maps extended V2 timing to key-down events.
- The extended V2 multi→single conversion concatenates audio files into one WAV. TactileMac does **not** do that: its runtime supports per-event files and segments, so it preserves the original audio and references.

### 2.3 Actual extended V2 corpus

The inspected `soundpacks/` directory has 10 keyboard packs and 4 mouse packs:
- Keyboard: CherryMX Black/Blue/Brown/Red (ABS/PBT), EG Crystal Purple, EG Oreo, Topre Purple Hybrid PBT.
- Mouse: Chat, Ping, Vibrate, Wooden.

All 14 keyboard/mouse configs load with TactileMac. The supported definitions map to 95 keyboard events per keyboard pack; mouse packs map to two button events. Warnings are limited to Windows-only names (`Insert`, `Pause`, `PrintScreen`, `ScrollLock`), which do not have a matching physical Mac key in this implementation.

## 3. OGG and other audio formats

- Legacy packs use `.ogg` (Vorbis) and `.mp3`; extended V2 packs use `.ogg` (keyboard) and `.mp3` (mouse in the inspected set).
- TactileMac does not bundle an OGG decoder. It uses AVFoundation/AudioToolbox, which on macOS 15.6.1 successfully decoded:
  - a real 51.7 s stereo 44.1 kHz Ogg Vorbis pack file (2,280,385 frames);
  - a generated Ogg Opus file (48 kHz mono);
  - MP3, FLAC, and WAV.
- An `.ogg` extension is not treated as proof of codec compatibility. Every referenced file is opened, probed, and read during validation. Unsupported containers/codecs fail with an error naming the file.
- `.aif`, `.aiff`, `.m4a`, and `.caf` were intentionally not accepted because they were not tested for this release.
- Native support on older macOS versions is not verified by this work. The target is macOS 14.0; testing was on macOS 15.6.1.

## 4. Key mapping rules used by the importer

- Extended V2 names are looked up directly in the W3C table.
- Legacy numeric codes are mapped through `LegacyKeyMap`.
- Legacy keys may end in `-up`; leading-zero mouse codes are releases.
- Exact key mappings become `key.down.<W3C>` / `key.up.<W3C>` events.
- Legacy V2 multi fallback creates down/up events for every known physical Mac key, using `sound`/`soundup` or their expanded ranges.
- Unsupported keys/codes are listed in import warnings; they are never silently discarded without a record.
- Missing files are warned about; a definition that cannot resolve is skipped. Import fails if no usable event remains.

## 5. Compatibility matrix

| Structure | TactileMac behavior |
| --- | --- |
| Legacy V1 single (`[start, duration]`, one file) | Imported directly; key-down events; key-up absent as in V1. |
| Legacy V1 multi (one file per code) | Imported directly; no invented fallback. |
| Legacy V1 key-up attempts | Not played (V1 behavior). |
| Legacy V2 multi + `soundup` + `-up` | Imported; exact down/up mappings plus global fallback fill. |
| Legacy V2 `{0-N}` file ranges | Expanded to every existing file as variations. |
| Legacy V2 single + `-up` timing arrays | Imported as timed key-up events in the shared file. |
| Legacy V2 single + `soundup` | `soundup` ignored for single, as the legacy demo comments describe; warning emitted if present. |
| Legacy mouse codes `1/2/3`, zero-padded releases | Mapped to left/right/middle clicks; releases skipped with a warning. |
| Extended V2 single + `[start, end]` timing | Imported; converted to native `startMs`/`durationMs`; key-down events. |
| Extended V2 multi/per-key `audio_file` | Imported without concatenation; per-event files preserved. |
| Extended V2 `defs` alias / direct timing array | Accepted. |
| Extended V2 `config_version` >2 | Rejected with an upgrade message. |
| Extended V2 unsupported Windows-only key names | Warned and skipped. |
| Missing/unreadable audio | Warned; definition skipped; import fails if nothing usable remains. |
| Zip traversal / symlinks | Rejected before installation. |
| Pack icon | Imported; missing icon is a warning. |
| Original `config.json` | Never rewritten. |

## 6. License findings

- The inspected legacy and extended V2 codebases are MIT-licensed.
- The inspected repositories do **not** include a separate license for their audio recordings. The legacy source tree's audio folder contains community/curated assets; the extended V2 sample packs include the same families. MIT on the code does not establish redistribution rights for those recordings.
- TactileMac therefore bundles **none** of their audio. Test fixtures are original synthesized tones; the OGG fixture is encoded from our own WAV.
- The extended V2 documentation says packs support OGG/WAV/MP3/FLAC; the validator accepts those extensions. Our runtime's tested format set is OGG Vorbis/Opus, WAV, MP3, FLAC via AVFoundation.
- If a user imports a third-party pack, the pack remains in their Application Support folder; TactileMac does not redistribute it.

## 7. Test fixtures

Committed under `TactileMacTests/Fixtures` (all audio generated by `scripts/generate_fixtures.py`, CC0-1.0):

- `NativePack` — native schema, WAV.
- `LegacyV1Single` — one file, `[start, duration]`, null definition.
- `LegacyV1Multi` — per-key files.
- `LegacyV2Multi` — fallback + `-up` + `soundup`.
- `LegacyV2Single` — single-file timed key-up.
- `LegacyV2Range` — `{0-2}` filename range.
- `ExtendedV2` — V2 `[start, end]`, mouse mapping, OGG.
- `ExtendedV2Mouse` — mouse/wheel.
- `Invalid/*` — traversal, missing file, malformed JSON, out-of-bounds segment, future version.

The local reference-corpus harness validated 32/32 actual packs.

## 8. What is not claimed

- Not every community pack is valid; some contain dangling file references or Windows-only keys.
- TactileMac is not byte-for-byte compatible with the legacy formats. It converts supported structures into its own model.
- It does not execute imported content.
- It does not claim that its mapping choices for ambiguous legacy extended codes are identical to every historical legacy build.
