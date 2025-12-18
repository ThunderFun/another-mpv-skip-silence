# AMPS (Another MPV Skip-silence)

A standalone mpv script that automatically increases playback speed during silent parts of a video.

## Features
- **Zero Dependencies**: Uses built-in ffmpeg filters.
- **Dynamic Threshold**: Automatically adjusts to the background noise floor of your audio.
- **Manual Toggle**: Start only when you need it with a keybinding.
- **OSD Notifications**: Clear feedback when enabled/disabled.

## Installation
Drop `amps.lua` into your mpv scripts folder:
- Linux/macOS: `~/.config/mpv/scripts/`
- Windows: `%APPDATA%/mpv/scripts/`

## Usage
- Press `Shift+C` to toggle AMPS on and off.
- The script stays disabled by default until you toggle it.

## Configuration
You can edit the `opts` table at the top of the script to tune behavior.

| Option | Description |
|--------|-------------|
| `threshold` | Initial silence threshold in dB (default: -40). |
| `silence_speed` | Speed multiplier during silence (default: 3.0). |
| `silence_duration` | Minimum duration of silence before speedup (default: 0.5s). |

## Versions
- `amps.lua`: Standard version, balanced for most content.
- `amps_AGGRESSIVE.lua`: Tuned for faster reaction and higher speed (4.0x).
