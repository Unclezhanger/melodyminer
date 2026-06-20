# MelodyMiner (拾音) 🎵

> Dig music, not gold. / 掘乐不掘金。

MelodyMiner is a Bash script that downloads high-quality audio from YouTube Music and YouTube, with full ID3 tag and cover art support.

**中文名：拾音** — 从 YouTube 挖掘音乐宝藏。

---

## ✨ Features / 功能

- 🎵 **Multiple Link Types**: YTM Albums, YTM Singles, YTM Radio, YouTube Playlists, YouTube Singles
- 🏷️ **Full ID3 Tags**: Title, Artist, Album, Album Artist, Cover Art
- 🖼️ **Smart Cover Handling**: Auto crop for album covers, compress for MV thumbnails
- 📂 **Organized Output**: Files saved by artist/album folder structure
- ⏭️ **Skip Existing**: Won't re-download or overwrite already downloaded files
- 🍪 **Optional Cookies**: Bypass region restrictions or access Premium quality

---

## 📋 Requirements / 依赖

| Tool | Install |
|------|---------|
| yt-dlp | `pip3 install yt-dlp` or `brew install yt-dlp` |
| ffmpeg | `brew install ffmpeg` or `apt install ffmpeg` |
| python3 | Pre-installed on most systems |
| node | `brew install node` or `apt install nodejs` |
| mutagen (Python) | `pip3 install mutagen` |

---

## 🚀 Quick Start / 快速开始

```bash
# 1. Run setup (one-time)
bash mm_setup.sh

# 2. Start downloading
bash melodyminer.sh
