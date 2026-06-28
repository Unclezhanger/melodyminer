# 🎵 melodyminer (拾音)

[![Version](https://img.shields.io/badge/version-2.8.6-blue)](https://github.com/Unclezhanger/melodyminer/releases)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Platform](https://img.shields.io/badge/platform-Linux%20%7C%20macOS-lightgrey)]()

> 🀄 [中文说明](README_zh.md)

**melodyminer (拾音) — Intelligent batch downloader for the YouTube Music ecosystem.**

Most tools treat every YouTube link the same. melodyminer doesn't.

---

## 🆚 What makes it different

### 1. Cover art that actually matches what you expect

YouTube Music pads album covers into 16:9 thumbnails. How a tool handles this determines whether your library looks right.

melodyminer reads each track's metadata **before** deciding what to do with the cover:

| Track type | Cover treatment |
|------------|----------------|
| YTM audio track (has `artist` + `album` metadata) | 1:1 center crop — recovers the original square album cover |
| MV / video track (no metadata) | Compress only, keep original aspect ratio |
| YTM album (unified mode) | Downloads the playlist-level thumbnail directly — the actual square album art, not a video thumbnail |

This means every track in a batch run gets the right cover automatically, without manual intervention.

### 2. Four link types, four different strategies

melodyminer detects the link type before asking any questions:

| Link type | Detection | Strategy |
|-----------|-----------|----------|
| YTM Album | `OLAK5uy_` in URL | Unified album cover + `album_artist` tag for correct library grouping |
| YTM Radio / Mix | `RDCLAK5uy_` in URL | Per-track independent covers |
| YouTube Playlist | `PL...` in URL | MV mode: manual per-track input or auto strategy |
| Single track | `watch?v=` | Same metadata check, same smart cover decision |

### 3. Correct ID3 tags for self-hosted libraries

`album_artist` is written correctly on every track. This matters for Navidrome and Jellyfin — without it, multi-artist albums split into multiple entries in your library.

Track numbers, album names, and cover art are all written via mutagen after download, giving you control over what goes in.

### 4. Dual audio format support

Choose your format once in `mm_setup.sh`:

- **Opus** (default) — higher quality (~160kbps VBR), smaller files
- **M4A** — native Apple device support, no transcoding needed for CarPlay / AirPlay / local playback

The correct yt-dlp format selector and mutagen API (Vorbis Comment vs iTunes tags) are applied automatically based on your choice.

### 5. True batch processing

Paste multiple links in one session. melodyminer handles them sequentially in the background via `nohup` — close your terminal, come back later, check the log. Re-running on the same folder safely skips already-downloaded tracks.

---

## 📋 Requirements

- **bash 4.0+** — macOS ships with bash 3.2, upgrade via `brew install bash`
- [`yt-dlp`](https://github.com/yt-dlp/yt-dlp)
- `ffmpeg`
- `python3` + [`mutagen`](https://mutagen.readthedocs.io/) (`pip3 install mutagen`)
- `node` (optional but recommended — some YouTube links require it for JS challenge solving)

---

## 📦 Quick Start

```bash
git clone https://github.com/Unclezhanger/melodyminer.git
cd melodyminer

# One-time setup (select music path, default folder, audio format)
bash mm_setup.sh

# Start downloading
bash melodyminer.sh
```

`mm_setup.sh` auto-detects all dependencies and guides you through configuration. Re-run anytime to change settings.

---

## 📁 Files

| File | Purpose |
|------|---------|
| `melodyminer.sh` | Main script |
| `mm_setup.sh` | Setup wizard |
| `mm_config.sh` | Generated config (do not edit manually) |

---

## ⚠️ Disclaimer

For personal and educational use only. Please respect copyright laws in your region. The author assumes no liability for any misuse.

---

## 📄 License

MIT License © 2026 Unclezhanger
