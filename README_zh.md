# 🎵 melodyminer (拾音)

[![Version](https://img.shields.io/badge/version-2.8.6-blue)](https://github.com/Unclezhanger/melodyminer/releases)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Platform](https://img.shields.io/badge/platform-Linux%20%7C%20macOS-lightgrey)]()

> 🌐 [English](README.md)

**melodyminer (拾音) — 专为 YouTube Music 生态打造的智能批量下载工具。**

大多数工具对每一条 YouTube 链接一视同仁。拾音不是。

---

## 🆚 核心差异

### 1. 封面准确还原，不再将就

YouTube Music 将所有专辑封面填充成 16:9 缩略图。处理方式决定了你的曲库看起来对不对。

拾音在处理封面之前，先读取每首曲目的元数据：

| 曲目类型 | 封面处理方式 |
|----------|-------------|
| YTM 音乐曲目（有 `artist` + `album` 元数据） | 1:1 居中裁剪，还原正方形专辑封面 |
| MV / 视频曲目（无元数据） | 仅压缩，保留原始宽高比 |
| YTM 专辑（统一封面模式） | 直接下载播放列表级别缩略图，即真正的专辑封面，而非视频截图 |

同一批量任务中，每首曲目自动获得正确的封面处理，无需手动干预。

### 2. 四种链接类型，四套独立策略

拾音在提问之前先识别链接类型：

| 链接类型 | 识别方式 | 处理策略 |
|----------|---------|---------|
| YTM 专辑 | URL 含 `OLAK5uy_` | 统一专辑封面 + 正确写入 `album_artist`，Navidrome/Jellyfin 分组准确 |
| YTM 电台 / 精选 | URL 含 `RDCLAK5uy_` | 逐首独立封面，自动识别 |
| YouTube 播放列表 | URL 含 `PL...` | MV 模式：逐首手动填写或自动策略 |
| 单曲 | `watch?v=` 格式 | 同样的元数据检测，同样的智能封面决策 |

### 3. 专为自建曲库优化的 ID3 标签

每首曲目都正确写入 `album_artist` 字段。这对 Navidrome 和 Jellyfin 至关重要——没有这个字段，多艺术家专辑会被拆分成多个独立条目。

曲目编号、专辑名、封面图均通过 mutagen 在下载后写入，精确可控。

### 4. 双音频格式支持

在 `mm_setup.sh` 中一次性选择格式，全局生效：

- **Opus**（默认）—— 更高音质（约 160kbps VBR），文件更小
- **M4A**——苹果设备原生支持，CarPlay / AirPlay / 本地播放无需转码

yt-dlp 的格式选择器和 mutagen 的写入 API（Vorbis Comment 或 iTunes 标签）均根据你的选择自动切换。

### 5. 真正的批量下载

一次粘贴多条链接，拾音通过 `nohup` 在后台顺序处理。关掉终端，稍后回来查看日志即可。对同一文件夹再次运行时，自动跳过已下载的曲目，不会重复覆盖。

---

## 📋 依赖环境

- **bash 4.0+** —— macOS 系统自带 bash 3.2，需先通过 `brew install bash` 升级
- [`yt-dlp`](https://github.com/yt-dlp/yt-dlp)
- `ffmpeg`
- `python3` + [`mutagen`](https://mutagen.readthedocs.io/)（`pip3 install mutagen`）
- `node`（可选但推荐，部分 YouTube 链接需要用于 JS 挑战解析）

---

## 📦 快速开始

```bash
git clone https://github.com/Unclezhanger/melodyminer.git
cd melodyminer

# 一次性配置（设置音乐路径、默认文件夹、音频格式）
bash mm_setup.sh

# 开始下载
bash melodyminer.sh
```

`mm_setup.sh` 自动检测所有依赖，引导完成配置。随时重新运行以修改设置。

---

## 📁 文件说明

| 文件 | 用途 |
|------|------|
| `melodyminer.sh` | 主脚本 |
| `mm_setup.sh` | 配置引导脚本 |
| `mm_config.sh` | 自动生成的配置文件（请勿手动编辑） |

---

## ⚠️ 免责声明

本工具仅供个人学习研究使用，请遵守当地法律法规，尊重版权，仅限个人使用。开发者对任何滥用行为不承担法律责任。

---

## 📄 开源协议

MIT License © 2026 Unclezhanger
