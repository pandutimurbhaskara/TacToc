# TactileMac Native Sound-Pack Format

TactileMac uses its own explicit schema. It is similar in spirit to legacy packs but is not byte-compatible. Third-party formats are converted at import time and never used directly by the runtime.

## Folder layout

```
my-pack/
  tactilemac.pack.json
  sounds/
    press_1.wav
    release_1.wav
    click.ogg
  icon.png            (optional, PNG/JPEG, ≤2 MB)
  README.md           (optional, ignored by the player)
```

File names are case-sensitive on disk. All audio paths are relative to the pack root. Absolute paths, `..`, and symlinks are rejected. Supported audio extensions are `.ogg`, `.wav`, `.mp3`, and `.flac`; every file is decoded by AVFoundation during validation and loading.

## Manifest

```json
{
  "schema": "tactilemac.pack",
  "schemaVersion": 1,
  "id": "my-pack",
  "name": "My Pack",
  "author": "Your Name",
  "description": "Optional description",
  "license": "CC0-1.0",
  "icon": "icon.png",
  "recommendedVolume": 0.8,
  "pitchVariation": 0.1,
  "events": {
    "key.down.default": [
      { "file": "sounds/press_1.wav" },
      { "file": "sounds/press_2.wav", "gain": 0.9 }
    ],
    "key.up.default": [
      { "file": "sounds/release_1.wav" }
    ],
    "key.down.space": [
      { "file": "sounds/space.wav" }
    ],
    "trackpad.click.left": [
      { "file": "sounds/click.ogg" }
    ],
    "trackpad.scroll.up": [
      { "file": "sounds/shared.ogg", "startMs": 120, "durationMs": 45 }
    ]
  }
}
```

### Manifest fields

| Field | Required | Meaning |
| --- | --- | --- |
| `schema` | yes | Must be `tactilemac.pack`. |
| `schemaVersion` | yes | `1`. A higher version is rejected with a clear message. |
| `id` | yes | Stable identifier: letters, digits, `.`, `_`, `-`; max 80. Must be unique among installed packs. |
| `name` | yes | Display name. |
| `author` | yes | Attribution. |
| `description` | no | UI description. |
| `license` | no | Informational license string for the pack. |
| `icon` | no | Relative PNG/JPEG path; missing icon is a warning, not a failure. |
| `recommendedVolume` | no | 0…2; informational, not forced over user volume. |
| `pitchVariation` | no | 0…2 semitones added to the user pitch variation for this pack. |
| `events` | yes | Event key → array of clip references (1…32 per event). |

### Clip reference

| Field | Required | Meaning |
| --- | --- | --- |
| `file` | yes | Relative audio path. |
| `startMs` | no | Start offset in milliseconds. |
| `durationMs` | no | Segment duration in milliseconds. |
| `gain` | no | Linear gain, 0…4 (default 1). |
| `pitchSemitones` | no | Fixed pitch offset, ±12 semitones. |

`startMs` and `durationMs` must either both be present or both absent. A segment starting beyond the end of the file is skipped with a warning; a segment extending past the file end is shortened with a warning. At least one playable clip must remain.

## Event keys

The coordinator resolves events in priority order: **exact key name → category → default**. For example, pressing A looks for:

```
key.down.KeyA
key.down.letter
key.down.default
```

### Keyboard

- `key.down.<suffix>` and `key.up.<suffix>`.
- Suffixes can be:
  - `default`
  - a category: `letter`, `number`, `punctuation`, `modifier`, `function`, `navigation`, `numpad`, `space`, `enter`, `backspace`, `escape`, `other`
  - an exact W3C `KeyboardEvent.code` name supported by the app, e.g. `KeyA`, `Digit1`, `Space`, `Enter`, `Backspace`, `Escape`, `ShiftLeft`, `MetaLeft`, `ArrowUp`, `F1`, `Numpad0`, `NumpadEnter`, `Delete`.

The mapping table is in `TactileMac/Models/KeyCodeMap.swift`. Key codes are physical macOS virtual key codes, so the mapping does not depend on the current keyboard layout.

### Trackpad

- `trackpad.click.left`, `trackpad.click.right`, `trackpad.click.middle`, `trackpad.click.default`
- `trackpad.scroll.up`, `trackpad.scroll.down`, `trackpad.scroll.default`

Trackpad clicks play on button-down. Release events are not part of this schema. Scroll events are rate-limited by the app; a pack does not need to throttle itself.

## Validation limits

- Events: ≤2000; total clips ≤5000; unique audio files ≤200; clip variations per event ≤32.
- Audio file: ≤200 MB; decoded duration ≤600 seconds; maximum pack tree 500 MB / 2000 files at import.
- Pack ID safety and path safety are enforced before any file is read.
- Unknown event keys, invalid clip fields, missing files, unreadable decoders, and unsafe paths fail validation/import with actionable messages.

## Import behavior

- Imports are staged in `~/Library/Application Support/TactileMac/Imports/`.
- The original source tree is copied unchanged. The runtime never reads or rewrites a third-party `config.json`.
- A third-party import gets:
  - `tactilemac.pack.json` — normalized runtime manifest.
  - `tactilemac.import.json` — source format, converter version, source config path, import date, detected version, warnings.
- A native pack keeps its own `tactilemac.pack.json`; it does not receive provenance automatically.
- Duplicate IDs are rejected. Remove the old pack first.
- Importing is not sandboxed; it is path-validated, size-bounded, and never executes imported content.

## Built-in packs

`TactileMac/Resources/BuiltInPacks/{thock,clicky,linear,soft}` are generated by `scripts/generate_builtin_packs.py`. They use the same schema and are read-only in the UI.
