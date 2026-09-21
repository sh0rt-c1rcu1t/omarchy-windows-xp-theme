#!/usr/bin/env python3
"""Generate the Windows XP sound set procedurally.

Windows XP's own .wav files are Microsoft's copyrighted material, so this theme
does not redistribute them. Instead this script synthesises a set of sounds in
the same spirit -- a bright rising chime for logon, a soft two-note fall for
shutdown, a single bell for notifications -- from scratch, using only the Python
standard library plus `ffmpeg` for the final Vorbis encode.

Owners of a Windows XP installation can point `tools/fetch-xp-sounds.sh` at their
`C:\\WINDOWS\\Media` directory to drop the originals in place of these.

    python3 tools/generate-sounds.py [output-dir]

The output directory defaults to `sounds/` at the repository root.
"""

import math
import os
import struct
import subprocess
import sys
import tempfile
import wave

RATE = 44100


# --------------------------------------------------------------------------
# synthesis
# --------------------------------------------------------------------------
def bell(freq, duration, amplitude, decay=3.0, harmonics=(1.0, 0.5, 0.25, 0.12, 0.06)):
    """A bell-like tone: a few harmonically related partials under one envelope."""
    count = int(duration * RATE)
    out = [0.0] * count
    for index, partial in enumerate(harmonics):
        partial_freq = freq * (index + 1)
        if partial_freq > RATE / 2:
            break
        weight = partial / (index + 1) ** 1.4
        for i in range(count):
            t = i / RATE
            envelope = math.exp(-decay * t)
            out[i] += amplitude * weight * envelope * math.sin(2 * math.pi * partial_freq * t)
    return out


def pluck(freq, duration, amplitude, decay=5.0):
    """A sine with a fast attack and a percussive decay."""
    count = int(duration * RATE)
    out = [0.0] * count
    for i in range(count):
        t = i / RATE
        attack = min(1.0, t / 0.004)
        envelope = attack * math.exp(-decay * t)
        out[i] += amplitude * envelope * math.sin(2 * math.pi * freq * t)
    return out


def mix(tracks, total_duration):
    """Sum voices at their start offsets, then normalise to a safe peak."""
    count = int(total_duration * RATE)
    out = [0.0] * count
    for samples, offset in tracks:
        start = int(offset * RATE)
        for i, value in enumerate(samples):
            target = start + i
            if target >= count:
                break
            out[target] += value

    peak = max((abs(v) for v in out), default=0.0)
    if peak > 0.86:
        scale = 0.86 / peak
        out = [v * scale for v in out]

    # 6ms fade in and 30ms fade out remove the click at either end.
    fade_in = int(0.006 * RATE)
    fade_out = int(0.030 * RATE)
    for i in range(min(fade_in, count)):
        out[i] *= i / fade_in
    for i in range(min(fade_out, count)):
        out[count - 1 - i] *= i / fade_out
    return out


def reverb(samples, taps=((0.055, 0.24), (0.093, 0.16), (0.147, 0.10))):
    """A short diffuse tail, which is what makes a chime read as a room."""
    out = list(samples)
    for delay, gain in taps:
        offset = int(delay * RATE)
        for i in range(len(samples) - offset):
            out[i + offset] += samples[i] * gain
    peak = max((abs(v) for v in out), default=0.0)
    if peak > 0.95:
        scale = 0.95 / peak
        out = [v * scale for v in out]
    return out


def write_wav(path, samples):
    with wave.open(path, "wb") as handle:
        handle.setnchannels(1)
        handle.setsampwidth(2)
        handle.setframerate(RATE)
        frames = bytearray()
        for value in samples:
            clamped = max(-1.0, min(1.0, value))
            frames += struct.pack("<h", int(clamped * 32767))
        handle.writeframes(bytes(frames))


# --------------------------------------------------------------------------
# the sound set
# --------------------------------------------------------------------------
def xp_startup():
    """The rising four-note chime Windows XP plays at the welcome screen."""
    tracks = [
        (bell(392.0, 1.9, 0.34, decay=1.6), 0.00),
        (bell(587.33, 1.7, 0.30, decay=1.8), 0.22),
        (bell(783.99, 1.5, 0.26, decay=2.0), 0.44),
        (bell(1046.50, 1.6, 0.22, decay=2.2), 0.66),
        (bell(196.00, 2.2, 0.30, decay=1.1), 0.00),
    ]
    return reverb(mix(tracks, 3.0))


def xp_shutdown():
    """The falling three-note phrase Windows XP plays on shutdown."""
    tracks = [
        (bell(1046.50, 1.2, 0.30, decay=2.6), 0.00),
        (bell(783.99, 1.3, 0.30, decay=2.4), 0.24),
        (bell(523.25, 2.0, 0.34, decay=1.6), 0.48),
        (bell(130.81, 2.4, 0.28, decay=0.9), 0.48),
    ]
    return reverb(mix(tracks, 2.8))


def xp_logon():
    """Two bright notes: a session has started."""
    tracks = [
        (bell(659.25, 1.2, 0.32, decay=2.4), 0.00),
        (bell(987.77, 1.6, 0.30, decay=2.0), 0.16),
        (bell(329.63, 1.8, 0.24, decay=1.2), 0.00),
    ]
    return reverb(mix(tracks, 2.0))


def xp_logoff():
    """Two soft descending notes: a session has ended."""
    tracks = [
        (bell(783.99, 1.0, 0.28, decay=2.8), 0.00),
        (bell(523.25, 1.5, 0.30, decay=2.0), 0.18),
    ]
    return reverb(mix(tracks, 1.9))


def xp_notify():
    """One short bell, the equivalent of Windows XP's "ding"."""
    return reverb(mix([(bell(1318.51, 0.7, 0.30, decay=4.0), 0.0)], 0.9))


def xp_dialog_information():
    """A soft, low ding for informational balloons."""
    return reverb(mix([(bell(880.00, 0.8, 0.26, decay=3.6), 0.0)], 1.0))


def xp_dialog_warning():
    """A two-note rising figure for warnings."""
    tracks = [
        (bell(587.33, 0.6, 0.26, decay=3.6), 0.00),
        (bell(880.00, 0.9, 0.28, decay=3.0), 0.14),
    ]
    return reverb(mix(tracks, 1.2))


def xp_dialog_error():
    """A dissonant dyad: unmistakably a problem."""
    tracks = [
        (bell(233.08, 1.4, 0.32, decay=2.2), 0.00),
        (bell(246.94, 1.4, 0.28, decay=2.2), 0.00),
        (pluck(116.54, 1.2, 0.20, decay=2.6), 0.00),
    ]
    return reverb(mix(tracks, 1.6))


def xp_critical_stop():
    """Two descending low tones for a critical stop."""
    tracks = [
        (bell(349.23, 0.7, 0.30, decay=3.4), 0.00),
        (bell(196.00, 1.4, 0.34, decay=1.8), 0.22),
    ]
    return reverb(mix(tracks, 1.7))


def xp_hardware_insert():
    """A short upward blip: a device arrived."""
    tracks = [
        (pluck(1046.50, 0.30, 0.24, decay=9.0), 0.00),
        (pluck(1567.98, 0.40, 0.20, decay=8.0), 0.09),
    ]
    return reverb(mix(tracks, 0.7))


def xp_hardware_remove():
    """The same blip falling: a device was removed."""
    tracks = [
        (pluck(1567.98, 0.30, 0.24, decay=9.0), 0.00),
        (pluck(1046.50, 0.40, 0.20, decay=8.0), 0.09),
    ]
    return reverb(mix(tracks, 0.7))


def xp_battery_low():
    """The two-tone low-battery chime."""
    tracks = [
        (bell(880.00, 0.5, 0.28, decay=4.0), 0.00),
        (bell(659.25, 0.9, 0.30, decay=3.0), 0.18),
    ]
    return reverb(mix(tracks, 1.2))


def xp_battery_critical():
    """A repeating low pulse for a critical battery."""
    tracks = [
        (bell(523.25, 0.5, 0.30, decay=4.0), 0.00),
        (bell(392.00, 0.5, 0.30, decay=4.0), 0.30),
        (bell(523.25, 0.6, 0.28, decay=3.6), 0.60),
    ]
    return reverb(mix(tracks, 1.4))


def xp_volume():
    """The tiny tick Windows XP plays when the volume changes."""
    return mix([(pluck(1760.00, 0.08, 0.22, decay=22.0), 0.0)], 0.12)


# Name -> generator. The names are the freedesktop sound-theme names, so the
# theme can be selected with a `sound-theme-name` in an index.theme file.
SOUNDS = [
    ("desktop-login", xp_startup),
    ("desktop-logout", xp_shutdown),
    ("service-login", xp_logon),
    ("service-logout", xp_logoff),
    ("message", xp_notify),
    ("message-new-instant", xp_notify),
    ("bell", xp_notify),
    ("dialog-information", xp_dialog_information),
    ("dialog-warning", xp_dialog_warning),
    ("dialog-error", xp_dialog_error),
    ("dialog-question", xp_dialog_information),
    ("alarm-clock-elapsed", xp_critical_stop),
    ("complete", xp_dialog_information),
    ("device-added", xp_hardware_insert),
    ("device-removed", xp_hardware_remove),
    ("battery-low", xp_battery_low),
    ("battery-caution", xp_battery_critical),
    ("audio-volume-change", xp_volume),
    ("power-plug", xp_hardware_insert),
    ("power-unplug", xp_hardware_remove),
]


def main():
    out_dir = sys.argv[1] if len(sys.argv) > 1 else os.path.join(
        os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "sounds"
    )
    os.makedirs(out_dir, exist_ok=True)

    for name, builder in SOUNDS:
        target = os.path.join(out_dir, name + ".oga")
        samples = builder()
        with tempfile.TemporaryDirectory() as scratch:
            wav_path = os.path.join(scratch, "tone.wav")
            write_wav(wav_path, samples)
            result = subprocess.run(
                [
                    "ffmpeg", "-hide_banner", "-loglevel", "error", "-y",
                    "-i", wav_path,
                    "-c:a", "libvorbis", "-q:a", "5",
                    target,
                ],
                capture_output=True,
                text=True,
            )
            if result.returncode != 0:
                print("ffmpeg failed for %s:\n%s" % (name, result.stderr), file=sys.stderr)
                return 1
        print("wrote %s" % target)

    return 0


if __name__ == "__main__":
    sys.exit(main())
