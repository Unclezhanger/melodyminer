# 🎵 MelodyMiner (拾音)

[![Version](https://img.shields.io/badge/version-2.7.8-blue)](https://github.com/Unclezhanger/melodyminer/releases)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Platform](https://img.shields.io/badge/platform-Linux%20%7C%20macOS-lightgrey)]()

> 🀄 [中文说明](README_zh.md)

**MelodyMiner (拾音) — Your YouTube Music companion.**

MelodyMiner is a Bash script purpose-built for the **YouTube Music ecosystem**. It accurately distinguishes between albums, radios, playlists, and MV singles — applying the right metadata strategy to each.

---

## 🆚 Why MelodyMiner?

| Scenario | Generic downloaders | MelodyMiner |
|----------|---------------------|--------------|
| YTM Album | Treated as playlist, missing metadata | Full album/artist extraction, 1:1 cover crop |
| YTM Radio | Can't differentiate | Auto-detected, independent covers per track |
| YouTube MV Playlist | Messy filenames, no ID3 | Manual or auto strategy, cover compressed (no crop) |
| MV Single | Uploader name used as artist | Manual input or auto strategy with correct title/artist/album |
| Re-download to same folder | Overwrites existing files | Auto-skips already downloaded tracks |

---

## ✨ Features

- **Smart link detection**: YTM Album (`OLAK5uy_`) / YTM Radio (`RDCLAK5uy_`) / YouTube Playlist (`PL`) / Single (`watch?v=`)
- **Full ID3 tags**: Title, Artist, Album, Album Artist, Cover Art (via mutagen)
- **Intelligent cover handling**:
  - Tracks with metadata → 1:1 center crop + compress
  - MV tracks (no metadata) → compress only, keep original ratio
  - Album unified cover → playlist thumbnail, compress only
- **Two MV strategies**: Per-track manual input or auto-fill from uploader/title
- **Skip existing**: Safe re-download without overwriting
- **Background execution**: nohup, non-blocking
- **Cross-platform**: Linux & macOS

---

## 📋 Requirements

- `bash` 4.0+ (macOS ships with bash 3.2 by default — install a newer version via `brew install bash`)
- [`yt-dlp`](https://github.com/yt-dlp/yt-dlp)
- `ffmpeg`
- `python3` with the [`mutagen`](https://mutagen.readthedocs.io/) module (`pip3 install mutagen`)
- `node` (optional but recommended — required by yt-dlp to solve some YouTube JS challenges)

---

## 📦 Quick Start

```bash
git clone https://github.com/Unclezhanger/melodyminer.git
cd melodyminer

# One-time setup
bash mm_setup.sh

# Start downloading
bash melodyminer.sh
```

`mm_setup.sh` auto-detects dependencies (yt-dlp, ffmpeg, python3, node, mutagen) and guides you through configuration.

---

## 📁 Files

| File | Purpose |
|------|---------|
| `melodyminer.sh` | Main script |
| `mm_setup.sh` | Setup wizard |
| `mm_config.sh` | Generated config file |

---

## ⚠️ Disclaimer

This tool is for personal educational use only. Please respect copyright laws in your region. The author assumes no liability for any misuse.

---

## 📄 License

MIT License © 2026 Unclezhanger
