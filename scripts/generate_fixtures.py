#!/usr/bin/env python3
"""Generate legally clean test fixtures from original synthesized tones."""
from __future__ import annotations

import json
import math
import shutil
import subprocess
import wave
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parent.parent
FIXTURES = ROOT / "TactileMacTests" / "Fixtures"
RATE = 44100


def tone(duration: float, frequencies: list[tuple[float, float]]) -> np.ndarray:
    n = int(RATE * duration)
    t = np.arange(n) / RATE
    out = np.zeros(n)
    for freq, weight in frequencies:
        out += weight * np.sin(2 * math.pi * freq * t)
    fade = int(RATE * 0.003)
    out[:fade] *= np.linspace(0, 1, fade)
    out[-fade:] *= np.linspace(1, 0, fade)
    out /= max(1e-9, np.max(np.abs(out)))
    return out * 0.65


def write_wav(path: Path, samples: np.ndarray) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    stereo = np.stack([samples, samples * 0.95], axis=1)
    pcm = (np.clip(stereo, -1, 1) * 32767).astype("<i2")
    with wave.open(str(path), "wb") as handle:
        handle.setnchannels(2)
        handle.setsampwidth(2)
        handle.setframerate(RATE)
        handle.writeframes(pcm.tobytes())


def write_json(path: Path, value: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, indent=2) + "\n", encoding="utf-8")


def main() -> None:
    if FIXTURES.exists():
        shutil.rmtree(FIXTURES)
    audio = FIXTURES / "Audio"
    audio.mkdir(parents=True)
    master = tone(0.36, [(440.0, 1.0), (880.0, 0.35)])
    # Make the first 200 ms distinguishable so segment tests are meaningful.
    n = len(master)
    master[: int(0.10 * RATE)] = tone(0.10, [(440.0, 1.0)])
    master[int(0.10 * RATE): int(0.20 * RATE)] = tone(0.10, [(880.0, 1.0)])
    write_wav(audio / "tone.wav", master)
    write_wav(audio / "click-low.wav", tone(0.12, [(220.0, 1.0), (440.0, 0.25)]))
    write_wav(audio / "click-high.wav", tone(0.10, [(1320.0, 1.0), (660.0, 0.3)]))
    write_wav(audio / "release.wav", tone(0.07, [(1760.0, 0.6)]))

    ogg = audio / "tone.ogg"
    result = subprocess.run(
        ["/opt/homebrew/bin/ffmpeg", "-v", "error", "-y", "-i", str(audio / "tone.wav"), "-ac", "2", "-c:a", "vorbis", "-strict", "-2", str(ogg)],
        capture_output=True,
        text=True,
    )
    if result.returncode != 0 or not ogg.exists() or ogg.stat().st_size == 0:
        raise SystemExit(f"Ogg Vorbis fixture generation failed: {result.stderr}")

    native = FIXTURES / "NativePack"
    shutil.copytree(audio, native / "sounds")
    write_json(native / "tactilemac.pack.json", {
        "schema": "tactilemac.pack",
        "schemaVersion": 1,
        "id": "fixture-native",
        "name": "Fixture Native",
        "author": "TactileMac Tests",
        "license": "CC0-1.0",
        "events": {
            "key.down.default": [{"file": "sounds/tone.wav"}],
            "key.up.default": [{"file": "sounds/release.wav"}],
            "trackpad.click.left": [{"file": "sounds/click-low.wav"}],
            "trackpad.scroll.up": [{"file": "sounds/click-high.wav"}],
        },
    })

    v1 = FIXTURES / "LegacyV1Single"
    shutil.copytree(audio, v1)
    write_json(v1 / "config.json", {
        "id": "fixture-v1-single",
        "name": "Fixture V1 Single",
        "key_define_type": "single",
        "includes_numpad": False,
        "sound": "tone.wav",
        "defines": {
            "30": [0, 100],
            "57": [100, 100],
            "14": [200, 100],
            "28": None,
        },
        "version": 1,
    })

    v1m = FIXTURES / "LegacyV1Multi"
    v1m.mkdir(parents=True)
    shutil.copy2(audio / "tone.wav", v1m / "fallback.wav")
    shutil.copy2(audio / "click-low.wav", v1m / "a.wav")
    shutil.copy2(audio / "click-high.wav", v1m / "space.wav")
    write_json(v1m / "config.json", {
        "id": "fixture-v1-multi",
        "name": "Fixture V1 Multi",
        "key_define_type": "multi",
        "includes_numpad": False,
        "sound": "fallback.wav",
        "defines": {"30": "a.wav", "57": "space.wav"},
        "version": 1,
    })

    v2 = FIXTURES / "LegacyV2Multi"
    v2.mkdir(parents=True)
    for name in ("fallback.wav", "a.wav", "space.wav", "release.wav"):
        source = (v1m / name) if name in ("a.wav", "space.wav") else audio / ("tone.wav" if name == "fallback.wav" else name)
        shutil.copy2(source, v2 / name)
    shutil.copy2(audio / "click-low.wav", v2 / "a-up.wav")
    shutil.copy2(audio / "click-high.wav", v2 / "space-up.wav")
    write_json(v2 / "config.json", {
        "id": "fixture-legacy-v2",
        "name": "Fixture Legacy V2",
        "key_define_type": "multi",
        "sound": "fallback.wav",
        "soundup": "release.wav",
        "defines": {
            "30": "a.wav",
            "57": "space.wav",
            "30-up": "a-up.wav",
            "57-up": "space-up.wav",
        },
        "version": 2,
    })

    v2single = FIXTURES / "LegacyV2Single"
    v2single.mkdir(parents=True)
    shutil.copy2(audio / "tone.wav", v2single / "tone.wav")
    write_json(v2single / "config.json", {
        "id": "fixture-v2-single-up",
        "name": "Fixture Legacy V2 Single",
        "key_define_type": "single",
        "sound": "tone.wav",
        "defines": {
            "30": [0, 100],
            "30-up": [100, 100],
        },
        "version": 2,
    })

    v2range = FIXTURES / "LegacyV2Range"
    (v2range / "press").mkdir(parents=True)
    shutil.copy2(audio / "tone.wav", v2range / "press" / "tick_0.wav")
    shutil.copy2(audio / "click-low.wav", v2range / "press" / "tick_1.wav")
    shutil.copy2(audio / "click-high.wav", v2range / "press" / "tick_2.wav")
    shutil.copy2(audio / "release.wav", v2range / "release.wav")
    write_json(v2range / "config.json", {
        "id": "fixture-v2-range",
        "name": "Fixture Legacy V2 Range",
        "key_define_type": "multi",
        "sound": "press/tick_{0-2}.wav",
        "soundup": "release.wav",
        "defines": {"30": "press/tick_0.wav"},
        "version": 2,
    })

    extended = FIXTURES / "ExtendedV2"
    extended.mkdir(parents=True)
    shutil.copy2(audio / "tone.ogg", extended / "sound.ogg")
    write_json(extended / "config.json", {
        "config_version": "2",
        "id": "fixture-extended-v2",
        "name": "Fixture Extended V2",
        "author": "TactileMac Tests",
        "definition_method": "single",
        "audio_file": "sound.ogg",
        "definitions": {
            "KeyA": {"timing": [[0.0, 100.0], [100.0, 180.0]]},
            "Space": {"timing": [[180.0, 300.0]]},
            "MouseLeft": {"timing": [[0.0, 50.0]]},
        },
        "options": {"recommended_volume": 0.9, "random_pitch": True},
        "tags": ["fixture"],
    })

    extendedMouse = FIXTURES / "ExtendedV2Mouse"
    extendedMouse.mkdir(parents=True)
    shutil.copy2(audio / "tone.wav", extendedMouse / "mouse.wav")
    write_json(extendedMouse / "config.json", {
        "config_version": 2,
        "name": "Fixture Extended V2 Mouse",
        "author": "TactileMac Tests",
        "definition_method": "single",
        "audio_file": "mouse.wav",
        "definitions": {
            "MouseLeft": {"timing": [[0, 80]]},
            "MouseRight": {"timing": [[80, 160]]},
            "WheelUp": {"timing": [[160, 240]]},
        },
    })

    invalid = FIXTURES / "Invalid"
    write_json(invalid / "Traversal" / "tactilemac.pack.json", {
        "schema": "tactilemac.pack",
        "schemaVersion": 1,
        "id": "fixture-traversal",
        "name": "Traversal",
        "author": "Tests",
        "events": {"key.down.default": [{"file": "../outside.wav"}]},
    })
    write_json(invalid / "MissingFile" / "tactilemac.pack.json", {
        "schema": "tactilemac.pack",
        "schemaVersion": 1,
        "id": "fixture-missing",
        "name": "Missing",
        "author": "Tests",
        "events": {"key.down.default": [{"file": "missing.wav"}]},
    })
    (invalid / "Malformed").mkdir(parents=True)
    (invalid / "Malformed" / "config.json").write_text('{"name": "broken", "defines": {', encoding="utf-8")
    write_json(invalid / "OutOfBounds" / "config.json", {
        "config_version": "2",
        "name": "Out of bounds",
        "author": "Tests",
        "definition_method": "single",
        "audio_file": "tone.wav",
        "definitions": {"KeyA": {"timing": [[900.0, 1000.0]]}},
    })
    shutil.copy2(audio / "tone.wav", invalid / "OutOfBounds" / "tone.wav")
    write_json(invalid / "UnsupportedVersion" / "config.json", {
        "config_version": 3,
        "name": "Future",
        "author": "Tests",
        "definitions": {"KeyA": {"timing": [[0, 50]]}},
    })
    shutil.copy2(audio / "tone.wav", invalid / "UnsupportedVersion" / "tone.wav")

    print("generated fixtures at", FIXTURES)


if __name__ == "__main__":
    main()
