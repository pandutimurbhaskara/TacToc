#!/usr/bin/env python3
"""Synthesize TactileMac's four built-in sound packs.

All audio here is generated from mathematical primitives in this script. No
third-party recordings are used, so the files can be distributed under CC0-1.0.
"""
from __future__ import annotations

import json
import math
import random
import wave
import zlib
from pathlib import Path

import numpy as np

RATE = 44100
ROOT = Path(__file__).resolve().parent.parent
PACKS = ROOT / "TactileMac" / "Resources" / "BuiltInPacks"

PROFILES = {
    "thock": {
        "name": "Thock",
        "description": "Warm, low mechanical thock. Original synthesized recording, not a sampled switch.",
        "volume": 0.65,
        "pitch": 0.12,
        "fundamental": 185.0,
        "modes": [1.0, 2.05, 3.4, 5.1],
        "weights": [1.0, 0.55, 0.28, 0.12],
        "decay": 0.085,
        "noise_decay": 0.012,
        "noise_tone": 2600.0,
        "noise_mix": 0.55,
        "peak": 0.82,
    },
    "clicky": {
        "name": "Clicky",
        "description": "Sharp, bright click with a short plastic transient. Original synthesized recording.",
        "volume": 0.60,
        "pitch": 0.08,
        "fundamental": 980.0,
        "modes": [1.0, 2.25, 3.8, 5.6],
        "weights": [0.8, 0.9, 0.55, 0.3],
        "decay": 0.028,
        "noise_decay": 0.006,
        "noise_tone": 6200.0,
        "noise_mix": 0.95,
        "peak": 0.78,
    },
    "linear": {
        "name": "Linear",
        "description": "Smooth, mid-focused press with a soft tail. Original synthesized recording.",
        "volume": 0.60,
        "pitch": 0.10,
        "fundamental": 440.0,
        "modes": [1.0, 1.9, 3.1, 4.4],
        "weights": [0.9, 0.6, 0.35, 0.15],
        "decay": 0.042,
        "noise_decay": 0.009,
        "noise_tone": 4200.0,
        "noise_mix": 0.6,
        "peak": 0.80,
    },
    "soft": {
        "name": "Soft",
        "description": "Muted, low-volume thump for quiet rooms. Original synthesized recording.",
        "volume": 0.55,
        "pitch": 0.06,
        "fundamental": 140.0,
        "modes": [1.0, 1.8, 2.8],
        "weights": [1.0, 0.45, 0.18],
        "decay": 0.070,
        "noise_decay": 0.015,
        "noise_tone": 1400.0,
        "noise_mix": 0.35,
        "peak": 0.70,
    },
}


def lowpass_noise(rng: np.random.Generator, length: int, cutoff: float) -> np.ndarray:
    noise = rng.normal(0.0, 1.0, length)
    alpha = min(0.99, max(0.001, 1.0 - math.exp(-2.0 * math.pi * cutoff / RATE)))
    out = np.empty(length, dtype=np.float64)
    acc = 0.0
    for i, value in enumerate(noise):
        acc += alpha * (value - acc)
        out[i] = acc
    return out


def make_click(
    profile: dict,
    seed: int,
    duration: float,
    *,
    frequency_scale: float = 1.0,
    decay_scale: float = 1.0,
    noise_scale: float = 1.0,
    amplitude: float = 1.0,
    bright: bool = False,
) -> np.ndarray:
    rng = np.random.default_rng(seed)
    n = max(64, int(RATE * duration))
    t = np.arange(n, dtype=np.float64) / RATE
    envelope = np.exp(-t / (profile["decay"] * decay_scale))
    attack = np.minimum(1.0, t / 0.0015)
    body = np.zeros(n, dtype=np.float64)
    fundamental = profile["fundamental"] * frequency_scale * (1.0 + rng.uniform(-0.04, 0.04))
    for mode, weight in zip(profile["modes"], profile["weights"]):
        freq = fundamental * mode
        if freq > RATE * 0.45:
            continue
        phase = rng.uniform(0, 2 * math.pi)
        body += weight * np.sin(2 * math.pi * freq * t + phase) * np.exp(-t / (profile["decay"] * decay_scale / (1.0 + 0.22 * mode)))
    body /= max(1e-9, np.max(np.abs(body)))

    noise = lowpass_noise(rng, n, profile["noise_tone"] * (1.6 if bright else 1.0))
    noise /= max(1e-9, np.max(np.abs(noise)))
    noise_env = np.exp(-t / (profile["noise_decay"] * decay_scale))
    click = body * envelope + noise * noise_env * profile["noise_mix"] * noise_scale
    click *= attack * amplitude
    peak = np.max(np.abs(click))
    if peak > 0:
        click = click / peak * profile["peak"]
    # Gentle fade-out prevents a discontinuity at the end of short clips.
    fade = min(n, int(RATE * 0.004))
    if fade > 1:
        click[-fade:] *= np.linspace(1.0, 0.0, fade)
    return click


def stereo(sample: np.ndarray, width: float = 0.00025) -> np.ndarray:
    delay = max(1, int(RATE * width))
    right = np.concatenate([np.zeros(delay), sample[:-delay]]) * 0.96
    return np.stack([sample, right], axis=1)


def write_wav(path: Path, sample: np.ndarray) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    data = np.clip(stereo(sample), -1.0, 1.0)
    pcm = (data * 32767.0).astype("<i2")
    with wave.open(str(path), "wb") as handle:
        handle.setnchannels(2)
        handle.setsampwidth(2)
        handle.setframerate(RATE)
        handle.writeframes(pcm.tobytes())


def clip(file: str, **kwargs) -> dict:
    entry = {"file": file}
    entry.update(kwargs)
    return entry


def build_pack(pack_id: str, profile: dict) -> None:
    folder = PACKS / pack_id
    sounds = folder / "sounds"
    sounds.mkdir(parents=True, exist_ok=True)
    rng = random.Random(zlib.crc32(pack_id.encode("utf-8")) & 0xFFFFFFFF)

    for i in range(1, 6):
        write_wav(sounds / f"press_{i}.wav", make_click(profile, seed=rng.randrange(1 << 30), duration=0.16, amplitude=1.0))
    for i in range(1, 4):
        write_wav(
            sounds / f"release_{i}.wav",
            make_click(profile, seed=rng.randrange(1 << 30), duration=0.075, frequency_scale=1.45, decay_scale=0.55, noise_scale=0.55, amplitude=0.40, bright=True),
        )
    write_wav(sounds / "space_down.wav", make_click(profile, seed=rng.randrange(1 << 30), duration=0.20, frequency_scale=0.72, decay_scale=1.25, noise_scale=0.8, amplitude=1.05))
    write_wav(sounds / "enter_down.wav", make_click(profile, seed=rng.randrange(1 << 30), duration=0.18, frequency_scale=0.88, decay_scale=1.05, amplitude=0.95))
    write_wav(sounds / "backspace_down.wav", make_click(profile, seed=rng.randrange(1 << 30), duration=0.13, frequency_scale=1.20, decay_scale=0.8, noise_scale=0.7, amplitude=0.75))
    write_wav(sounds / "modifier_down.wav", make_click(profile, seed=rng.randrange(1 << 30), duration=0.10, frequency_scale=0.95, decay_scale=0.65, noise_scale=0.45, amplitude=0.50))
    write_wav(sounds / "escape_down.wav", make_click(profile, seed=rng.randrange(1 << 30), duration=0.11, frequency_scale=1.30, decay_scale=0.6, noise_scale=0.9, amplitude=0.65, bright=True))

    write_wav(sounds / "trackpad_click_1.wav", make_click(profile, seed=rng.randrange(1 << 30), duration=0.045, frequency_scale=1.9, decay_scale=0.35, noise_scale=1.1, amplitude=0.55, bright=True))
    write_wav(sounds / "trackpad_click_2.wav", make_click(profile, seed=rng.randrange(1 << 30), duration=0.050, frequency_scale=1.75, decay_scale=0.38, noise_scale=1.0, amplitude=0.50, bright=True))
    write_wav(sounds / "trackpad_click_right.wav", make_click(profile, seed=rng.randrange(1 << 30), duration=0.055, frequency_scale=1.35, decay_scale=0.50, noise_scale=0.8, amplitude=0.50))
    for direction, scale in (("up", 1.55), ("down", 1.30)):
        for i in (1, 2):
            write_wav(
                sounds / f"scroll_{direction}_{i}.wav",
                make_click(profile, seed=rng.randrange(1 << 30), duration=0.028, frequency_scale=scale + i * 0.08, decay_scale=0.22, noise_scale=0.9, amplitude=0.32, bright=True),
            )

    events = {
        "key.down.default": [clip(f"sounds/press_{i}.wav") for i in range(1, 6)],
        "key.up.default": [clip(f"sounds/release_{i}.wav") for i in range(1, 4)],
        "key.down.space": [clip("sounds/space_down.wav")],
        "key.up.space": [clip("sounds/release_1.wav"), clip("sounds/release_2.wav")],
        "key.down.enter": [clip("sounds/enter_down.wav")],
        "key.up.enter": [clip("sounds/release_2.wav")],
        "key.down.backspace": [clip("sounds/backspace_down.wav")],
        "key.up.backspace": [clip("sounds/release_1.wav")],
        "key.down.modifier": [clip("sounds/modifier_down.wav")],
        "key.up.modifier": [clip("sounds/release_3.wav")],
        "key.down.escape": [clip("sounds/escape_down.wav")],
        "key.down.navigation": [clip("sounds/press_2.wav"), clip("sounds/press_4.wav")],
        "trackpad.click.default": [clip("sounds/trackpad_click_1.wav"), clip("sounds/trackpad_click_2.wav")],
        "trackpad.click.left": [clip("sounds/trackpad_click_1.wav"), clip("sounds/trackpad_click_2.wav")],
        "trackpad.click.right": [clip("sounds/trackpad_click_right.wav")],
        "trackpad.scroll.up": [clip(f"sounds/scroll_up_{i}.wav") for i in (1, 2)],
        "trackpad.scroll.down": [clip(f"sounds/scroll_down_{i}.wav") for i in (1, 2)],
    }

    manifest = {
        "schema": "tactilemac.pack",
        "schemaVersion": 1,
        "id": pack_id,
        "name": profile["name"],
        "author": "TactileMac",
        "description": profile["description"],
        "license": "CC0-1.0",
        "recommendedVolume": profile["volume"],
        "pitchVariation": profile["pitch"],
        "events": events,
    }
    (folder / "tactilemac.pack.json").write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def main() -> None:
    PACKS.mkdir(parents=True, exist_ok=True)
    for pack_id, profile in PROFILES.items():
        build_pack(pack_id, profile)
        print(f"generated {pack_id}")


if __name__ == "__main__":
    main()
