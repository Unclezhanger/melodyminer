# 🎵 MelodyMiner (拾音)

[![Version](https://img.shields.io/badge/version-2.7.8-blue)](https://github.com/Unclezhanger/melodyminer/releases)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Platform](https://img.shields.io/badge/platform-Linux%20%7C%20macOS-lightgrey)]()

> 🀄 [English](README.md)

**MelodyMiner (拾音) — 你的 YouTube Music 助手。**

MelodyMiner 是一个专为 **YouTube Music 生态** 打造的 Bash 脚本。它可以精准区分专辑、电台、播放列表与 MV 单曲，并为每种类型应用恰当的元数据策略。

---

## 🆚 为什么选择 MelodyMiner？

| 场景 | 普通下载工具 | MelodyMiner |
|------|-------------|------------|
| YTM 正规专辑 | 当成播放列表处理，元数据缺失 | 完整提取 album/artist，封面 1:1 居中裁剪 |
| YTM 电台 | 无法区分 | 自动识别，每首曲目独立封面 |
| YouTube MV 播放列表 | 文件名混乱，无 ID3 | 支持逐首确认或自动策略，封面仅压缩不裁剪 |
| MV 单曲 | uploader 被当作歌手 | 手动输入或自动策略，正确写入 title/artist/album |
| 同一文件夹重复下载 | 覆盖已有文件 | 自动跳过已下载曲目 |

---

## ✨ 核心功能

- **智能链接识别**：YTM 专辑 (`OLAK5uy_`) / YTM 电台 (`RDCLAK5uy_`) / YouTube 播放列表 (`PL`) / 单曲 (`watch?v=`)
- **完整 ID3 标签**：Title、Artist、Album、Album Artist、封面嵌入（基于 mutagen）
- **智能封面处理**：
  - 有元数据的曲目 → 1:1 居中裁剪 + 压缩
  - MV 曲目（无元数据） → 仅压缩，保留原始宽高比
  - 正规专辑统一封面 → 抓取 playlist thumbnail，仅压缩
- **MV 双策略**：逐首手动输入 或 使用 uploader/title 自动填充
- **跳过已有**：安全重复下载，不覆盖已有文件
- **后台运行**：nohup 启动，不阻塞终端
- **跨平台**：支持 Linux 与 macOS

---

## 📋 环境依赖

- `bash` 4.0+（macOS 默认搭载 bash 3.2，需通过 `brew install bash` 安装新版）
- [`yt-dlp`](https://github.com/yt-dlp/yt-dlp)
- `ffmpeg`
- `python3` 与 [`mutagen`](https://mutagen.readthedocs.io/) 模块 (`pip3 install mutagen`)
- `node`（可选但推荐，yt-dlp 部分 JS 挑战需要 node 来解决）

---

## 📦 快速开始

```bash
git clone https://github.com/Unclezhanger/melodyminer.git
cd melodyminer

# 一次性配置
bash mm_setup.sh

# 开始下载
bash melodyminer.sh
```

`mm_setup.sh` 会自动检测依赖 (yt-dlp、ffmpeg、python3、node、mutagen) 并引导你完成所有配置。

---

## 📁 文件说明

| 文件 | 用途 |
|------|---------|
| `melodyminer.sh` | 主脚本 |
| `mm_setup.sh` | 配置向导 |
| `mm_config.sh` | 生成的配置文件 |

---

## ⚠️ 免责声明

本工具仅供个人学习研究使用。请遵守你所在地区的版权法规。作者不对任何滥用行为承担责任。

---

## 📄 开源协议

MIT License © 2026 Unclezhanger
