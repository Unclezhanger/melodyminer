#!/bin/bash
# ═════════════════════════════════════════════════
# melodyminer (拾音) 配置引导脚本 mm_setup.sh
# ═════════════════════════════════════════════════

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/mm_config.sh"

echo "=================================================="
echo " 🎵 melodyminer 配置引导 / Setup"
echo "=================================================="
echo ""
echo "请选择语言 / Please select language:"
echo " [1] 中文 (默认)"
echo " [2] English (main script interface coming in V2.8.0)"
echo -n "选择 / Select [1/2]: "
read -r LANG_CHOICE
[ -z "$LANG_CHOICE" ] && LANG_CHOICE="1"

if [ "$LANG_CHOICE" == "2" ]; then
    MM_LANG="en"
    MSG_WELCOME="🎵 melodyminer Setup"
    MSG_CHECK_DEP="🔍 Checking dependencies..."
    MSG_YTDLP_FOUND="  ✅ yt-dlp:"
    MSG_FFMPEG_FOUND="  ✅ ffmpeg:"
    MSG_PYTHON_FOUND="  ✅ python3:"
    MSG_NODE_FOUND="  ✅ node:"
    MSG_CHECK_MODULES="🔍 Checking Python modules..."
    MSG_MUTAGEN_OK="  ✅ mutagen"
    MSG_MISSING_DEP="❌ Missing required dependencies:"
    MSG_INSTALL_MACOS="  macOS:  brew install yt-dlp ffmpeg"
    MSG_INSTALL_LINUX="  Linux:  pip3 install yt-dlp && sudo apt install ffmpeg"
    MSG_RETRY="Please install and rerun this script."
    MSG_CONFIG_DIR="── 📂 Music Directory Configuration ──"
    MSG_DEFAULT_PATH="  Default:"
    MSG_INPUT_PROMPT="  Enter path (Enter to use default): "
    MSG_DIR_NOT_EXIST="  ⚠️ Directory does not exist, create it? [Y/n]: "
    MSG_DIR_CREATED="  ✅ Created:"
    MSG_MUSIC_DIR="  ✅ Music directory:"
    MSG_DEFAULT_ARTIST="── 🎤 Default Artist Folder ──"
    MSG_INPUT_ARTIST_PROMPT="  Enter (Enter to use 'melodyminer'): "
    MSG_DEFAULT_ARTIST_SET="  ✅ Default artist folder:"
    MSG_AUDIO_FORMAT="── 🎵 Audio Format ──"
    MSG_USING_OPUS="  ✅ Using opus (m4a support coming soon)"
    MSG_GEN_CONFIG="── 📝 Generating Config File ──"
    MSG_CONFIG_SAVED="  ✅ Config file saved:"
    MSG_DONE="🎉 Setup complete!"
    MSG_USAGE="Usage:"
    MSG_RUN_CMD="  bash melodyminer.sh"
    MSG_MODIFY_CONFIG="Modify config:"
    MSG_EDIT_CMD="  Edit $CONFIG_FILE"
    MSG_RECONFIGURE="Reconfigure:"
    MSG_RERUN_CMD="  bash mm_setup.sh"
    MSG_HIDDEN_FOLDERS="── 🗂️ Hidden Folders ──"
    MSG_SELECT_HIDE="  Select folders to hide (e.g., attachments):"
    MSG_INPUT_HIDE="  Enter folder numbers to hide (comma separated, Enter to skip): "
    MSG_HIDE_ADDED="  ✅ Added to hidden folders:"
    MSG_SELECT_DEFAULT="  Select default artist folder:"
    MSG_NEW_FOLDER="  [0] Create new folder"
    MSG_INPUT_NEW="  Enter new folder name: "
    MSG_DEFAULT_MARK=" (default)"
    MSG_SELECT_PROMPT="Select number or enter name (Enter for default[1]): "
else
    MM_LANG="zh"
    MSG_WELCOME="🎵 melodyminer (拾音) 配置引导"
    MSG_CHECK_DEP="🔍 检查依赖环境..."
    MSG_YTDLP_FOUND="  ✅ yt-dlp:"
    MSG_FFMPEG_FOUND="  ✅ ffmpeg:"
    MSG_PYTHON_FOUND="  ✅ python3:"
    MSG_NODE_FOUND="  ✅ node:"
    MSG_CHECK_MODULES="🔍 检查 Python 模块..."
    MSG_MUTAGEN_OK="  ✅ mutagen"
    MSG_MISSING_DEP="❌ 缺少必要依赖:"
    MSG_INSTALL_MACOS="  macOS:  brew install yt-dlp ffmpeg"
    MSG_INSTALL_LINUX="  Linux:  pip3 install yt-dlp && sudo apt install ffmpeg"
    MSG_RETRY="请安装后重新运行此脚本。"
    MSG_CONFIG_DIR="── 📂 音乐目录配置 ──"
    MSG_DEFAULT_PATH="  默认:"
    MSG_INPUT_PROMPT="  请输入路径 (回车使用默认): "
    MSG_DIR_NOT_EXIST="  ⚠️ 目录不存在，是否创建？ [Y/n]: "
    MSG_DIR_CREATED="  ✅ 已创建:"
    MSG_MUSIC_DIR="  ✅ 音乐目录:"
    MSG_DEFAULT_ARTIST="── 🎤 默认歌手文件夹 ──"
    MSG_INPUT_ARTIST_PROMPT="  请输入 (回车使用 'melodyminer'): "
    MSG_DEFAULT_ARTIST_SET="  ✅ 默认歌手文件夹:"
    MSG_AUDIO_FORMAT="── 🎵 音频格式 ──"
    MSG_USING_OPUS="  ✅ 当前使用: opus（m4a 支持将在后续版本添加）"
    MSG_GEN_CONFIG="── 📝 生成配置文件 ──"
    MSG_CONFIG_SAVED="  ✅ 配置文件已保存:"
    MSG_DONE="🎉 配置完成！"
    MSG_USAGE="使用方法："
    MSG_RUN_CMD="  bash melodyminer.sh"
    MSG_MODIFY_CONFIG="修改配置："
    MSG_EDIT_CMD="  编辑 $CONFIG_FILE"
    MSG_RECONFIGURE="重新配置："
    MSG_RERUN_CMD="  bash mm_setup.sh"
    MSG_HIDDEN_FOLDERS="── 🗂️ 隐藏文件夹管理 ──"
    MSG_SELECT_HIDE="  选择需要隐藏的文件夹（如 attachments）："
    MSG_INPUT_HIDE="  请输入要隐藏的文件夹编号（逗号分隔，回车跳过）: "
    MSG_HIDE_ADDED="  ✅ 已添加到隐藏文件夹:"
    MSG_SELECT_DEFAULT="  选择默认歌手文件夹:"
    MSG_NEW_FOLDER="  [0] 新建文件夹"
    MSG_INPUT_NEW="  请输入新文件夹名称: "
    MSG_DEFAULT_MARK=" （默认）"
    MSG_SELECT_PROMPT="请选择编号或直接输入名称 (直接回车默认[1]): "
fi

echo "=================================================="
echo " $MSG_WELCOME"
echo "=================================================="
echo ""

echo "$MSG_CHECK_DEP"
echo ""

MISSING=()

YTDLP_PATH=""
if command -v yt-dlp &>/dev/null; then
    YTDLP_PATH=$(command -v yt-dlp)
    echo "$MSG_YTDLP_FOUND $YTDLP_PATH"
elif [ -f "$HOME/.local/bin/yt-dlp" ]; then
    YTDLP_PATH="$HOME/.local/bin/yt-dlp"
    echo "$MSG_YTDLP_FOUND $YTDLP_PATH"
else
    echo "  ❌ yt-dlp: 未找到"
    MISSING+=("yt-dlp")
fi

if command -v ffmpeg &>/dev/null; then
    echo "$MSG_FFMPEG_FOUND $(command -v ffmpeg)"
else
    echo "  ❌ ffmpeg: 未找到"
    MISSING+=("ffmpeg")
fi

if command -v python3 &>/dev/null; then
    echo "$MSG_PYTHON_FOUND $(command -v python3)"
else
    echo "  ❌ python3: 未找到"
    MISSING+=("python3")
fi

NODE_PATH=""
if command -v node &>/dev/null; then
    NODE_PATH=$(command -v node)
    echo "$MSG_NODE_FOUND $NODE_PATH"
else
    echo "  ⚠️  node: 未找到（部分链接可能需要，建议安装）"
fi

echo ""
echo "$MSG_CHECK_MODULES"
python3 -c "import mutagen" 2>/dev/null && echo "$MSG_MUTAGEN_OK" || { echo "  ❌ mutagen 未安装"; MISSING+=("python3-mutagen"); }

if [ ${#MISSING[@]} -gt 0 ]; then
    echo ""
    echo "$MSG_MISSING_DEP ${MISSING[*]}"
    echo ""
    echo "$MSG_INSTALL_MACOS"
    echo "$MSG_INSTALL_LINUX"
    echo ""
    echo "$MSG_RETRY"
    exit 1
fi

echo ""

echo "$MSG_CONFIG_DIR"
echo ""
DEFAULT_BASE="$HOME/navidrome/music"
echo "$MSG_DEFAULT_PATH $DEFAULT_BASE"
echo -n "$MSG_INPUT_PROMPT"
read -r USER_BASE
BASE_DIR="${USER_BASE:-$DEFAULT_BASE}"

if [ ! -d "$BASE_DIR" ]; then
    echo -n "$MSG_DIR_NOT_EXIST"
    read -r CREATE_DIR
    [[ ! "$CREATE_DIR" =~ ^[Nn]$ ]] && mkdir -p "$BASE_DIR" && echo "$MSG_DIR_CREATED $BASE_DIR"
fi
echo "$MSG_MUSIC_DIR $BASE_DIR"
echo ""

echo "$MSG_DEFAULT_ARTIST"
echo ""

folders=()
folders+=("melodyminer")
while IFS= read -r line; do
    [[ "$line" == "melodyminer" ]] && continue
    folders+=("$line")
done < <(ls -F "$BASE_DIR" 2>/dev/null | grep '/$' | sed 's/\///')

echo "$MSG_SELECT_DEFAULT"
for i in "${!folders[@]}"; do
    if [ "$i" -eq 0 ]; then
        echo "[$((i+1))] ${folders[$i]}$MSG_DEFAULT_MARK" >&2
    else
        echo "[$((i+1))] ${folders[$i]}" >&2
    fi
done
echo "$MSG_NEW_FOLDER" >&2
echo -n "$MSG_SELECT_PROMPT" >&2
read -r CHOICE
if [ -z "$CHOICE" ]; then
    DEFAULT_ARTIST_DIR="${folders[0]}"
elif [[ "$CHOICE" =~ ^[0-9]+$ ]] && [ "$CHOICE" -gt 0 ] && [ "$CHOICE" -le "${#folders[@]}" ]; then
    DEFAULT_ARTIST_DIR="${folders[$((CHOICE-1))]}"
elif [ "$CHOICE" == "0" ]; then
    echo -n "$MSG_INPUT_NEW" >&2
    read -r NEW_DIR
    DEFAULT_ARTIST_DIR="$NEW_DIR"
else
    DEFAULT_ARTIST_DIR="$CHOICE"
fi
echo "$MSG_DEFAULT_ARTIST_SET $DEFAULT_ARTIST_DIR"
echo ""

AUDIO_FORMAT="opus"
echo "$MSG_AUDIO_FORMAT"
echo "$MSG_USING_OPUS"
echo ""

echo "$MSG_HIDDEN_FOLDERS"
echo ""

all_dirs=()
while IFS= read -r line; do
    all_dirs+=("$line")
done < <(ls -F "$BASE_DIR" 2>/dev/null | grep '/$' | sed 's/\///')

HIDDEN_DIRS=(".DS_Store" "@eaDir" "attachments")

if [ ${#all_dirs[@]} -gt 0 ]; then
    echo "$MSG_SELECT_HIDE"
    for i in "${!all_dirs[@]}"; do
        echo "[$((i+1))] ${all_dirs[$i]}" >&2
    done
    echo -n "$MSG_INPUT_HIDE"
    read -r HIDE_CHOICE

    if [ -n "$HIDE_CHOICE" ]; then
        IFS=',' read -ra IDX <<< "$HIDE_CHOICE"
        for idx in "${IDX[@]}"; do
            idx=$(echo "$idx" | xargs)
            if [[ "$idx" =~ ^[0-9]+$ ]] && [ "$idx" -gt 0 ] && [ "$idx" -le "${#all_dirs[@]}" ]; then
                HIDDEN_DIRS+=("${all_dirs[$((idx-1))]}")
            fi
        done
    fi
fi

mapfile -t HIDDEN_DIRS < <(printf "%s\n" "${HIDDEN_DIRS[@]}" | sort -u)
echo "$MSG_HIDE_ADDED ${HIDDEN_DIRS[*]}"
echo ""

echo "$MSG_GEN_CONFIG"

HIDDEN_DIRS_STR="("
for hd in "${HIDDEN_DIRS[@]}"; do
    HIDDEN_DIRS_STR+="\"$hd\" "
done
HIDDEN_DIRS_STR+=")"

cat > "$CONFIG_FILE" << CFGEOF
#!/bin/bash
# melodyminer (拾音) 配置文件
# 由 mm_setup.sh 生成于 $(date '+%Y-%m-%d %H:%M:%S')

# 语言设置 (zh/en)
MM_LANG="$MM_LANG"

# 音乐库根目录
BASE_DIR="$BASE_DIR"

# yt-dlp 路径
YTDLP="$YTDLP_PATH"

# node 路径（yt-dlp 解析用，留空则自动检测）
NODE_PATH="${NODE_PATH:-}"

# 默认歌手文件夹
DEFAULT_ARTIST_DIR="$DEFAULT_ARTIST_DIR"

# 隐藏文件夹（在歌手选择界面中不显示）
HIDDEN_DIRS=$HIDDEN_DIRS_STR

# 音频格式: opus (m4a 将在后续版本支持)
AUDIO_FORMAT="$AUDIO_FORMAT"

# 播放列表下载间隔（秒，0=不限制）
PLAYLIST_SLEEP_REQUESTS=0
PLAYLIST_SLEEP_INTERVAL=0
CFGEOF

chmod +x "$CONFIG_FILE"
echo "$MSG_CONFIG_SAVED $CONFIG_FILE"
echo ""

echo "=================================================="
echo " $MSG_DONE"
echo "=================================================="
echo ""
echo "$MSG_USAGE"
echo "$MSG_RUN_CMD"
echo ""
echo "$MSG_MODIFY_CONFIG"
echo "$MSG_EDIT_CMD"
echo ""
echo "$MSG_RECONFIGURE"
echo "$MSG_RERUN_CMD"
echo ""