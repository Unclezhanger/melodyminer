#!/bin/bash
# ─────────────────────────────────────────────
# melodyminer (拾音) V2.7.8
# 修复: cleanup_worker 清理范围、|分隔符转义、xargs报错
# ─────────────────────────────────────────────

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/mm_config.sh"

if [ ! -f "$CONFIG_FILE" ]; then
    echo "=================================================="
    echo " ❌ 未找到配置文件: $CONFIG_FILE"
    echo "=================================================="
    echo "📝 首次使用，请先运行配置引导脚本："
    echo " bash mm_setup.sh"
    echo ""
    exit 1
fi
source "$CONFIG_FILE"

: "${BASE_DIR:=$HOME/navidrome/music}"
: "${YTDLP:=yt-dlp}"
: "${DEFAULT_ARTIST_DIR:=melodyminer}"
: "${AUDIO_FORMAT:=opus}"
: "${PLAYLIST_SLEEP_REQUESTS:=0}"
: "${PLAYLIST_SLEEP_INTERVAL:=0}"
: "${NODE_PATH:=}"

if [ ${#HIDDEN_DIRS[@]} -eq 0 ]; then
    HIDDEN_DIRS=("attachments" "@eaDir" ".DS_Store")
fi

NODE_ARGS=""
if [ -n "$NODE_PATH" ]; then
    NODE_ARGS="--js-runtimes node:$NODE_PATH"
elif command -v node &>/dev/null; then
    NODE_ARGS="--js-runtimes node:$(command -v node)"
fi

CLEANUP_FILES=()
cleanup() {
    for f in "${CLEANUP_FILES[@]}"; do
        [ -f "$f" ] && rm -f "$f" 2>/dev/null
    done
}
trap cleanup EXIT

echo "=================================================="
echo " 🎵 melodyminer (拾音) V2.7.8"
echo "=================================================="
echo "支持: 专辑 / 播放列表 / YTM电台 / 单曲"
echo "=================================================="

MAX_LINKS_PER_RUN=10
MAX_TRACKS_PER_RUN=150

file_size() {
    local f="$1"
    if stat -c%s "$f" >/dev/null 2>&1; then stat -c%s "$f"; else stat -f%z "$f"; fi
}

sanitize_filename() { echo "$1" | sed 's/[\/:*?"<>|]/-/g' | sed 's/^-//' | sed 's/-$//'; }
fullwidth_to_halfwidth() { echo "$1" | sed 's/，/,/g' | sed 's/－/-/g'; }
safe_field() { echo "$1" | sed 's/|/｜/g'; }
safe_strip() { echo "$1" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//'; }

parse_track_selection() {
    local input="$1" max="$2" result=""
    input=$(fullwidth_to_halfwidth "$input")
    IFS=',' read -ra parts <<< "$input"
    for part in "${parts[@]}"; do
        part=$(echo "$part" | xargs)
        [ -z "$part" ] && continue
        if [[ "$part" =~ ^([0-9]+)-([0-9]+)$ ]]; then
            start=${BASH_REMATCH[1]}; end=${BASH_REMATCH[2]}
            if [ "$start" -ge 1 ] && [ "$end" -le "$max" ] && [ "$start" -le "$end" ]; then
                for ((i=start; i<=end; i++)); do
                    [ -n "$result" ] && result="$result,$i" || result="$i"
                done
            else echo "INVALID:$part"; return 1; fi
        elif [[ "$part" =~ ^[0-9]+$ ]]; then
            [ "$part" -ge 1 ] && [ "$part" -le "$max" ] && { [ -n "$result" ] && result="$result,$part" || result="$part"; } || { echo "INVALID:$part"; return 1; }
        else echo "INVALID:$part"; return 1; fi
    done
    [ -z "$result" ] && echo "ALL" || echo "$result"
}

select_artist_folder() {
    local prompt_suffix="$1"
    echo "" >&2
    echo "--- 📂 请选择歌手文件夹 ${prompt_suffix}---" >&2
    local folders=()
    folders+=("$DEFAULT_ARTIST_DIR")
    while IFS= read -r line; do
        [[ "$line" == "$DEFAULT_ARTIST_DIR" ]] && continue
        local hidden=0
        for h in "${HIDDEN_DIRS[@]}"; do [[ "$line" == "$h" ]] && hidden=1 && break; done
        [ $hidden -eq 1 ] && continue
        folders+=("$line")
    done < <(ls -F "$BASE_DIR" 2>/dev/null | grep '/$' | sed 's/\///')

    for i in "${!folders[@]}"; do
        if [ "$i" -eq 0 ]; then echo "[$((i+1))] ${folders[$i]} （默认）" >&2
        else echo "[$((i+1))] ${folders[$i]}" >&2; fi
    done
    echo "[0] 新建歌手文件夹" >&2
    echo "--------------------" >&2
    echo -n "请选择编号或直接输入名称 (直接回车默认[1]): " >&2
    read -r CHOICE
    if [ -z "$CHOICE" ]; then echo "${folders[0]}"
    elif [[ "$CHOICE" =~ ^[0-9]+$ ]] && [ "$CHOICE" -gt 0 ] && [ "$CHOICE" -le "${#folders[@]}" ]; then echo "${folders[$((CHOICE-1))]}"
    elif [ "$CHOICE" == "0" ]; then
        echo -n "请输入新歌手文件夹名称: " >&2; read -r NEW_DIR; echo "$NEW_DIR"
    else echo "$CHOICE"; fi
}

input_album_artist() {
    local default_name="$1"
    echo "" >&2
    echo "请输入专辑艺术家：" >&2
    echo " [回车] 使用默认值「$default_name」" >&2
    echo " [n] 跳过（不写入 album_artist）" >&2
    echo " [其他] 自定义输入" >&2
    echo -n "请选择: " >&2
    read -r input
    if [ -z "$input" ]; then echo "$default_name"; echo "✅ Album Artist: $default_name (默认)" >&2
    elif [[ "$input" =~ ^[Nn]$ ]]; then echo "SKIP"; echo "⏭️ 跳过 Album Artist" >&2
    else
        local safe_input=$(echo "$input" | sed 's/|/｜/g')
        echo "$safe_input"; echo "✅ Album Artist: $safe_input (自定义)" >&2
    fi
}

extract_song_info() {
    local title="$1"
    if [[ "$title" =~ ^(.+)\ -\ (.+)$ ]]; then
        local song_artist="${BASH_REMATCH[1]}"
        local song_name="${BASH_REMATCH[2]}"
        song_name=$(echo "$song_name" | sed 's/\s*\[[^]]*\]//g' | sed 's/\s*(Official[^)]*)//g' | sed 's/\s*(Acoustic[^)]*)//g' | sed 's/\s*(Lyric[^)]*)//g' | sed 's/\s*(Live[^)]*)//g' | sed 's/\s*(Performance[^)]*)//g' | sed 's/\s*(Stripped[^)]*)//g')
        song_name=$(safe_strip "$song_name")
        song_name=$(echo "$song_name" | sed 's/|/｜/g')
        song_artist=$(echo "$song_artist" | sed 's/|/｜/g')
        echo "${song_name}|${song_artist}"; return
    fi
    if [[ "$title" =~ 《([^》]+)》 ]]; then
        local s="${BASH_REMATCH[1]}"; s=$(echo "$s" | sed 's/|/｜/g')
        echo "${s}|"; return
    fi
    if [[ "$title" =~ \"([^\"]+)\" ]]; then
        local s="${BASH_REMATCH[1]}"; s=$(echo "$s" | sed 's/|/｜/g')
        echo "${s}|"; return
    fi
    local cleaned=$(echo "$title" | sed 's/^【[^】]*】//' | sed 's/^Stage: //' | sed 's/^纯享[：:]//')
    cleaned=$(safe_strip "$cleaned")
    cleaned=$(echo "$cleaned" | sed 's/|/｜/g')
    echo "${cleaned:0:50}|"
}

input_mv_full() {
    local default_title="$1" default_artist="$2"
    echo "" >&2
    echo "--- 🎤 输入歌曲信息 ---" >&2
    echo " [回车]=使用默认值" >&2
    echo -n "歌名 [${default_title}]: " >&2
    read -r t; [ -z "$t" ] && t="$default_title"
    echo -n "歌手 [${default_artist}]: " >&2
    read -r a; [ -z "$a" ] && a="$default_artist"
    echo -n "专辑 [${t}]: " >&2
    read -r al; [ -z "$al" ] && al="$t"
    t=$(echo "$t" | sed 's/|/｜/g')
    a=$(echo "$a" | sed 's/|/｜/g')
    al=$(echo "$al" | sed 's/|/｜/g')
    echo "${t}|${a}|${al}"
}

get_album_info() {
    local url="$1" tmp_json=$(mktemp)
    CLEANUP_FILES+=("$tmp_json")
    "$YTDLP" $NODE_ARGS --flat-playlist --no-warnings -J "$url" > "$tmp_json" 2>/dev/null
    if [ ! -s "$tmp_json" ]; then
        echo "Unknown Album"; echo "0"; echo "Unknown Artist"
        rm -f "$tmp_json"; return
    fi
    python3 << PYEOF
import json, re
with open("$tmp_json") as f: d = json.load(f)
raw = d.get('title', '') or ''
album = re.sub(r'^.+? - ', '', raw).strip() or 'Unknown Album'
count = d.get('playlist_count', 0)
artist = 'Unknown Artist'
entries = d.get('entries', [])
if entries:
    artist = re.sub(r' - Topic$', '', entries[0].get('uploader', '')).strip() or 'Unknown Artist'
print(album); print(count); print(artist)
for idx, e in enumerate(entries, 1):
    print(f"{idx}. {re.sub(r'^.+? - ', '', e.get('title', 'Unknown'))}")
PYEOF
    rm -f "$tmp_json"
}

get_playlist_info() {
    local url="$1" tmp_json=$(mktemp)
    CLEANUP_FILES+=("$tmp_json")
    "$YTDLP" $NODE_ARGS --flat-playlist --no-warnings -J "$url" > "$tmp_json" 2>/dev/null
    if [ ! -s "$tmp_json" ]; then
        echo "Unknown Playlist"; echo "0"
        rm -f "$tmp_json"; return
    fi
    python3 << PYEOF
import json
with open("$tmp_json") as f: d = json.load(f)
playlist = d.get('title', '').strip() or 'Unknown Playlist'
count = d.get('playlist_count', 0)
print(playlist); print(count)
entries = d.get('entries', [])
for idx, e in enumerate(entries, 1):
    if e is None: print(f"{idx}. [不可用]||False"); continue
    title = e.get('title') or f'Track {idx}'
    vid = e.get('id', '')
    has_meta = 'True' if (e.get('album') or e.get('artist')) else 'False'
    print(f"{idx}. {title}|{vid}|{has_meta}")
PYEOF
    rm -f "$tmp_json"
}

get_single_info() {
    local url="$1" tmp_json="/tmp/ytm_single_$$"
    CLEANUP_FILES+=("${tmp_json}.info.json" "$tmp_json")
    "$YTDLP" $NODE_ARGS --write-info-json --skip-download -o "$tmp_json" "$url" >/dev/null 2>&1
    local json_file="${tmp_json}.info.json"
    if [ ! -f "$json_file" ]; then
        echo "Unknown"; echo "1"; echo ""; echo ""; echo "False"
        rm -f "$tmp_json" "$json_file" 2>/dev/null; return
    fi
    python3 << PYEOF
import json
with open("$json_file") as f: d = json.load(f)
album = d.get('album', '') or ''
title = d.get('title', 'Unknown')
artist = d.get('artist', '') or ''
uploader = d.get('uploader', '') or ''
has_metadata = bool(artist and album)
print(album); print(title); print(artist); print(uploader); print(has_metadata)
PYEOF
    rm -f "$tmp_json" "$json_file" 2>/dev/null
}

get_link_type() {
    local url="$1"
    [[ "$url" =~ OLAK5uy_ ]] && { echo "album"; return; }
    [[ "$url" =~ RDCLAK5uy_ ]] && { echo "ytm_radio"; return; }
    if [[ "$url" =~ playlist\?list=PL ]] || [[ "$url" =~ playlist\?list=LM ]]; then echo "playlist"; return; fi
    [[ "$url" =~ youtube\.com/playlist ]] && { echo "playlist"; return; }
    [[ "$url" =~ watch\?v= ]] || [[ "$url" =~ youtu\.be/ ]] && { echo "single"; return; }
    echo "unknown"
}

# ═════════════════════════════════════════════
# 主流程
# ═════════════════════════════════════════════
echo ""
echo "请粘贴链接（一行一条），空行或输入 end 开始："
URLS=()
while true; do
    read -r line
    [[ "$line" == "end" ]] && break
    [[ -z "$line" ]] && break
    URLS+=("$line")
    [ ${#URLS[@]} -ge $MAX_LINKS_PER_RUN ] && { echo "⚠️ 已达上限"; break; }
done
[ ${#URLS[@]} -eq 0 ] && { echo "❌ 未检测到链接"; exit 1; }

echo ""
echo "🔍 检测链接类型..."
VALID_URLS=(); URL_TYPES=(); URL_NAMES=()
for url in "${URLS[@]}"; do
    TYPE=$(get_link_type "$url")
    if [ "$TYPE" != "unknown" ]; then
        VALID_URLS+=("$url"); URL_TYPES+=("$TYPE")
        case "$TYPE" in
            album) N="专辑";; playlist) N="播放列表";; ytm_radio) N="YTM电台";; single) N="单曲";;
        esac
        URL_NAMES+=("$N")
        echo "✅ $N: $url"
    else
        echo "⚠️ 跳过无效: $url"
    fi
done
[ ${#VALID_URLS[@]} -eq 0 ] && { echo "❌ 没有有效链接"; exit 1; }

echo ""
echo "📊 有效链接: ${#VALID_URLS[@]} 个"

declare -a ALBUM_CONFIGS
TOTAL_SELECTED=0

for idx in "${!VALID_URLS[@]}"; do
    url="${VALID_URLS[$idx]}"; TYPE="${URL_TYPES[$idx]}"
    echo ""
    echo "=========================================="
    echo "🔍 获取信息: ${URL_NAMES[$idx]}"
    echo "=========================================="

    IS_SINGLE=false; IS_PLAYLIST=false; IS_ALBUM=false; IS_YTM_RADIO=false
    HAS_METADATA="False"; DISPLAY_NAME=""; TRACK_COUNT=0; DISPLAY_ARTIST=""
    SONG_LIST=""; SONG_LIST_FULL=""
    MV_TITLE=""; MV_ARTIST=""; MV_ALBUM=""; MV_ALBUM_ARTIST=""
    BATCH_ALBUM=""; NORMAL_SELECTION=""; MV_VIDS=""; MV_INFO=""; MV_STRATEGY=""

    if [ "$TYPE" == "album" ]; then
        IS_ALBUM=true; HAS_METADATA="True"
        INFO=$(get_album_info "$url")
        DISPLAY_NAME=$(echo "$INFO" | sed -n '1p'); TRACK_COUNT=$(echo "$INFO" | sed -n '2p')
        DISPLAY_ARTIST=$(echo "$INFO" | sed -n '3p'); SONG_LIST=$(echo "$INFO" | tail -n +4)
    elif [ "$TYPE" == "ytm_radio" ]; then
        IS_YTM_RADIO=true
        INFO=$(get_playlist_info "$url")
        DISPLAY_NAME=$(echo "$INFO" | sed -n '1p'); TRACK_COUNT=$(echo "$INFO" | sed -n '2p')
        SONG_LIST_FULL=$(echo "$INFO" | tail -n +3); SONG_LIST=$(echo "$SONG_LIST_FULL" | sed 's/|.*//')
    elif [ "$TYPE" == "playlist" ]; then
        IS_PLAYLIST=true
        INFO=$(get_playlist_info "$url")
        DISPLAY_NAME=$(echo "$INFO" | sed -n '1p'); TRACK_COUNT=$(echo "$INFO" | sed -n '2p')
        SONG_LIST_FULL=$(echo "$INFO" | tail -n +3); SONG_LIST=$(echo "$SONG_LIST_FULL" | sed 's/|.*//')
    else
        IS_SINGLE=true
        SINGLE_INFO=$(get_single_info "$url")
        SINGLE_ALBUM=$(echo "$SINGLE_INFO" | sed -n '1p'); SINGLE_TITLE=$(echo "$SINGLE_INFO" | sed -n '2p')
        SINGLE_ARTIST=$(echo "$SINGLE_INFO" | sed -n '3p'); SINGLE_UPLOADER=$(echo "$SINGLE_INFO" | sed -n '4p')
        HAS_METADATA=$(echo "$SINGLE_INFO" | sed -n '5p')
        DISPLAY_NAME="${SINGLE_ALBUM:-$SINGLE_TITLE}"; DISPLAY_ARTIST="${SINGLE_ARTIST:-$SINGLE_UPLOADER}"
        SONG_LIST="1. $SINGLE_TITLE"; TRACK_COUNT=1
    fi

    [ -z "$DISPLAY_NAME" ] && { echo "⚠️ 无法获取信息，跳过"; continue; }
    SAFE_NAME=$(sanitize_filename "$DISPLAY_NAME")
    echo ""
    echo "📀 项目: $SAFE_NAME"
    [ -n "$DISPLAY_ARTIST" ] && [ "$DISPLAY_ARTIST" != "Unknown Artist" ] && echo "🎤 歌手: $DISPLAY_ARTIST"
    echo "🎵 曲目数: $TRACK_COUNT"
    [ "$IS_ALBUM" == true ] && echo "📌 类型: 正规专辑"
    [ "$IS_YTM_RADIO" == true ] && echo "📌 类型: YTM 电台/合集"
    [ "$IS_PLAYLIST" == true ] && echo "📌 类型: YouTube 播放列表"
    [ "$IS_SINGLE" == true ] && { [ "$HAS_METADATA" == "True" ] && echo "🔧 类型: 纯音频单曲" || echo "🎬 类型: MV 单曲"; }

    ARTIST_DIR=$(select_artist_folder " (《$SAFE_NAME》)")
    ARTIST_PATH="$BASE_DIR/$ARTIST_DIR"; mkdir -p "$ARTIST_PATH"

    if [ "$IS_SINGLE" == true ]; then
        echo -n "创建子文件夹？[回车=是/n=否]: "; read -r SUB_CHOICE
        [[ "$SUB_CHOICE" =~ ^[Nn]$ ]] && FINAL_PATH="$ARTIST_PATH" || { FINAL_PATH="$ARTIST_PATH/$SAFE_NAME"; mkdir -p "$FINAL_PATH"; }
    else
        FINAL_PATH="$ARTIST_PATH/$SAFE_NAME"; mkdir -p "$FINAL_PATH"
    fi
    echo "✅ 路径: $FINAL_PATH"

    ALBUM_ARTIST=""; ENHANCED_MODE=false
    if [ "$IS_ALBUM" == true ]; then
        AA_RESULT=$(input_album_artist "$ARTIST_DIR")
        [ "$AA_RESULT" != "SKIP" ] && ALBUM_ARTIST="$AA_RESULT"
        echo ""
        echo "[1] 统一封面 [2] 独立封面"
        echo -n "选择 [1/2]: "; read -r MC
        [ "$MC" == "2" ] && ENHANCED_MODE=true
    elif [ "$IS_SINGLE" == true ]; then
        ENHANCED_MODE=true
    else
        ENHANCED_MODE=true
        [ "$IS_YTM_RADIO" == true ] && echo "📌 YTM电台：自动使用独立封面模式"
    fi

    if [ "$TRACK_COUNT" -eq 1 ]; then
        SELECTION="ALL"; SELECTED_COUNT=1
    else
        echo ""
        echo "$SONG_LIST"; echo ""
        if [ "$TRACK_COUNT" -gt 50 ]; then
            echo "💡 共 $TRACK_COUNT 首，建议分批下载（如 1-50, 51-100）"
        fi
        while true; do
            echo -n "曲目编号 [回车=全部，支持 1,3,5 或 1-5]: "; read -r TI
            if [ -z "$TI" ]; then SELECTION="ALL"; SELECTED_COUNT=$TRACK_COUNT; break; fi
            P=$(parse_track_selection "$TI" "$TRACK_COUNT")
            [[ "$P" == INVALID:* ]] && { echo "⚠️ 错误"; continue; }
            SELECTION="$P"; SELECTED_COUNT=$(echo "$SELECTION" | tr ',' '\n' | wc -l); break
        done
    fi
    echo "✅ 将下载 $SELECTED_COUNT 首"

    # ── MV 单曲处理 ──
    if [ "$IS_SINGLE" == true ] && [ "$HAS_METADATA" != "True" ]; then
        echo ""
        echo "⚠️ MV 单曲"
        SI=$(extract_song_info "$SINGLE_TITLE"); ST=$(echo "$SI" | cut -d'|' -f1); SA=$(echo "$SI" | cut -d'|' -f2)
        [ -z "$SA" ] && SA="$ARTIST_DIR"
        echo "[1] 手动输入歌名/歌手/专辑（专辑默认=歌名）"
        echo "[2] 使用默认值（歌手=uploader，歌名=title，专辑=title）"
        echo -n "选择 [1/2]: "; read -r MS
        [ -z "$MS" ] && MS="1"
        if [ "$MS" == "1" ]; then
            MV_STRATEGY="1"
            MV_INPUT=$(input_mv_full "$ST" "$SA")
            MV_TITLE=$(echo "$MV_INPUT" | cut -d'|' -f1)
            MV_ARTIST=$(echo "$MV_INPUT" | cut -d'|' -f2)
            MV_ALBUM=$(echo "$MV_INPUT" | cut -d'|' -f3)
        else
            MV_STRATEGY="2"
            MV_TITLE="$SINGLE_TITLE"; MV_ARTIST="$SINGLE_UPLOADER"; MV_ALBUM="$SINGLE_TITLE"
        fi
    fi

    # ── 播放列表 MV 处理 ──
    if [ "$IS_PLAYLIST" == true ] && [ "$SELECTION" != "ALL" ]; then
        SEL_ITEMS=$(echo "$SELECTION" | tr ',' ' ')
        NORMAL_LIST=""; MV_LIST=""
        for inum in $SEL_ITEMS; do
            L=$(echo "$SONG_LIST_FULL" | sed -n "${inum}p")
            VID=$(echo "$L" | awk -F'|' '{print $(NF-1)}')
            HAS=$(echo "$L" | awk -F'|' '{print $NF}')
            if [ "$HAS" != "True" ]; then
                MV_LIST="$MV_LIST $VID"
            else
                NORMAL_LIST="${NORMAL_LIST}${NORMAL_LIST:+,}$inum"
            fi
        done
        NORMAL_SELECTION="$NORMAL_LIST"
        MV_VIDS=$(echo "$MV_LIST" | xargs)

        if [ -n "$MV_LIST" ]; then
            echo ""
            echo "⚠️ 选中有 MV ($(echo $MV_VIDS | wc -w) 首)"
            echo "[1] 手动输入歌名/歌手/专辑（专辑默认=歌名）"
            echo "[2] 使用默认值（歌手=uploader，歌名=title，专辑=title）"
            echo -n "选择 [1/2]: "; read -r MS
            [ -z "$MS" ] && MS="1"
            if [ "$MS" == "1" ]; then
                MV_STRATEGY="1"
                echo ""
                echo "--- 🎬 逐首确认 ---"
                MV_INFO=""
                for VID in $MV_VIDS; do
                    LINE=$(echo "$SONG_LIST_FULL" | grep "$VID")
                    INUM=$(echo "$LINE" | sed 's/^\([0-9]*\)\. .*/\1/')
                    RAW_TITLE=$(echo "$LINE" | sed 's/^[0-9]*\. //; s/|[^|]*|[^|]*$//')
                    SI=$(extract_song_info "$RAW_TITLE"); ST=$(echo "$SI" | cut -d'|' -f1); SA=$(echo "$SI" | cut -d'|' -f2)
                    [ -z "$SA" ] && SA="$ARTIST_DIR"
                    echo "" >&2; echo "━━━━ 第 ${INUM} 首: ${RAW_TITLE:0:60}..." >&2
                    NAME_INPUT=$(input_mv_full "$ST" "$SA")
                    TITLE=$(echo "$NAME_INPUT" | cut -d'|' -f1)
                    ARTIST=$(echo "$NAME_INPUT" | cut -d'|' -f2)
                    ALBUM=$(echo "$NAME_INPUT" | cut -d'|' -f3)
                    [ -n "$MV_INFO" ] && MV_INFO="${MV_INFO};"
                    MV_INFO="${MV_INFO}${VID}=${TITLE}=${ARTIST}=${ALBUM}"
                done
            else
                MV_STRATEGY="2"
                NORMAL_SELECTION="$SELECTION"; MV_VIDS=""; MV_INFO=""
            fi
        fi
        if [ -n "$NORMAL_SELECTION" ]; then SELECTION="$NORMAL_SELECTION"; else SELECTION=""; fi
    fi

    NT=$((TOTAL_SELECTED + SELECTED_COUNT))
    [ "$NT" -gt "$MAX_TRACKS_PER_RUN" ] && { echo "⚠️ 累计超限 $MAX_TRACKS_PER_RUN 首"; continue; }
    TOTAL_SELECTED=$NT

    ALBUM_CONFIGS+=("$(safe_field "$SAFE_NAME")|$SELECTION|$url|$FINAL_PATH|$(safe_field "$ALBUM_ARTIST")|$ENHANCED_MODE|$TYPE|$HAS_METADATA|$(safe_field "$MV_TITLE")|$(safe_field "$MV_ARTIST")|$(safe_field "$MV_ALBUM")|$(safe_field "$MV_ALBUM_ARTIST")|$(safe_field "$BATCH_ALBUM")|||$NORMAL_SELECTION|$MV_VIDS|$(safe_field "$MV_INFO")|$MV_STRATEGY")
    echo ""
done

[ ${#ALBUM_CONFIGS[@]} -eq 0 ] && { echo "❌ 没有项目"; exit 1; }
echo "📊 统计: ${#ALBUM_CONFIGS[@]} 个项目，累计 $TOTAL_SELECTED 首"

# ═════════════════════════════════════════════
# 后台脚本生成
# ═════════════════════════════════════════════
LOG_FILE="$HOME/ytm-album-$(date +%Y%m%d-%H%M%S).log"
WORKER_SH=$(mktemp /tmp/ytm_worker_XXXXXX.sh)
chmod +x "$WORKER_SH"

cat > "$WORKER_SH" << 'WORKEREOF'
#!/bin/bash
YTDLP="__YTDLP__"
NODE_ARGS="__NODE_ARGS__"
LOG_FILE="__LOG_FILE__"
AUDIO_FORMAT="__AUDIO_FORMAT__"
SLEEP_REQUESTS="__SLEEP_REQUESTS__"
SLEEP_INTERVAL="__SLEEP_INTERVAL__"

cleanup_worker() {
    rm -f /tmp/existing_before_$$* /tmp/cover_$$* /tmp/cover_mv_$$* /tmp/cover_$$_* 2>/dev/null
}
trap cleanup_worker EXIT

log() { echo "$1" >> "$LOG_FILE"; }

file_size() {
    local f="$1"
    if stat -c%s "$f" >/dev/null 2>&1; then stat -c%s "$f"; else stat -f%z "$f"; fi
}

cover_crop_center() {
    local src="$1" dst="$2"
    ffmpeg -i "$src" \
           -vf "crop=min(iw\,ih):min(iw\,ih):(iw-min(iw\,ih))/2:(ih-min(iw\,ih))/2" \
           -q:v 2 -y "$dst" 2>/dev/null
    [ -f "$dst" ] && return 0 || return 1
}

cover_compress() {
    local src="$1" dst="$2"
    ffmpeg -i "$src" -q:v 2 -y "$dst" 2>/dev/null
    [ -f "$dst" ] && return 0 || return 1
}

mv_write_id3() {
    python3 - "$@" << 'PYEOF'
import sys, os
from mutagen.oggopus import OggOpus
fpath = sys.argv[1]; title = sys.argv[2]; artist = sys.argv[3]
album = sys.argv[4]; album_artist = sys.argv[5]; cover_file = sys.argv[6] if len(sys.argv) > 6 else ""
audio = OggOpus(fpath)
audio['title'] = [title]
audio['artist'] = [artist]
if album: audio['album'] = [album]
elif 'album' in audio: del audio['album']
if album_artist: audio['album_artist'] = [album_artist]
elif 'album_artist' in audio: del audio['album_artist']
if cover_file and os.path.exists(cover_file):
    from mutagen.flac import Picture
    import base64
    with open(cover_file, 'rb') as img:
        pic = Picture(); pic.data = img.read(); pic.type = 3; pic.mime = 'image/jpeg'
        audio['metadata_block_picture'] = [base64.b64encode(pic.write()).decode('ascii')]
    print(f' ✅ +封面: {os.path.basename(fpath)}')
else:
    print(f' ✅ ID3: {os.path.basename(fpath)}')
audio.save()
PYEOF
}

embed_cover() {
    python3 - "$@" << 'PYEOF'
import sys, os, base64
from mutagen.oggopus import OggOpus
from mutagen.flac import Picture
fpath = sys.argv[1]; aa = sys.argv[2]; an = sys.argv[3]
hc = sys.argv[4]; em = sys.argv[5]; oa = sys.argv[6]; cf = sys.argv[7] if len(sys.argv) > 7 else ""
try:
    audio = OggOpus(fpath)
    if aa and aa not in ('None','SKIP',''): audio['album_artist'] = [aa]
    elif 'album_artist' in audio: del audio['album_artist']
    if em=='true' and oa and oa!='None' and not oa.startswith('%'): audio['album'] = [oa]
    else: audio['album'] = [an]
    if em=='true' and 'tracknumber' in audio: del audio['tracknumber']
    if hc=='true' and cf and os.path.exists(cf):
        with open(cf,'rb') as img:
            pic=Picture(); pic.data=img.read(); pic.type=3; pic.mime='image/jpeg'
            audio['metadata_block_picture'] = [base64.b64encode(pic.write()).decode('ascii')]
        print(f' ✅ +封面: {os.path.basename(fpath)}')
    else:
        print(f' ✅ 仅ID3: {os.path.basename(fpath)}')
    audio.save()
except Exception as e:
    print(f' ❌ 失败: {os.path.basename(fpath)} - {e}')
PYEOF
}

get_cover_url() {
    python3 -c "
import json, sys
with open(sys.argv[1]) as f: d = json.load(f)
thumbs = sorted(d.get('thumbnails',[]), key=lambda x: x.get('width',0)*x.get('height',0), reverse=True)
if thumbs: print(thumbs[0]['url'])
" "$1" 2>/dev/null
}

download_cover() {
    local json_file="$1" out_var="$2"
    local url=""
    url=$(get_cover_url "$json_file")
    if [ -n "$url" ]; then
        local tmp="/tmp/cover_$$.jpg"
        curl -sL "$url" -o "$tmp" 2>/dev/null
        if [ -f "$tmp" ] && [ "$(file_size "$tmp" 2>/dev/null)" -gt 10240 ]; then
            eval "$out_var=$tmp"
            return 0
        fi
    fi
    return 1
}

declare -A MV_DATA
parse_mv_info() {
    local info="$1"
    if [ -z "$info" ]; then return; fi
    IFS=';' read -ra ENTRIES <<< "$info"
    for entry in "${ENTRIES[@]}"; do
        VID=$(echo "$entry" | cut -d= -f1)
        TITLE=$(echo "$entry" | cut -d= -f2)
        ARTIST=$(echo "$entry" | cut -d= -f3)
        ALBUM=$(echo "$entry" | cut -d= -f4)
        [ -n "$VID" ] && MV_DATA["$VID"]="$TITLE|$ARTIST|$ALBUM"
    done
}

log "⚙️ PID: $$ | 🕒 $(date '+%Y-%m-%d %H:%M:%S')"
WORKEREOF

# 替换占位符
sed -i "s|__YTDLP__|$YTDLP|g" "$WORKER_SH"
sed -i "s|__NODE_ARGS__|$NODE_ARGS|g" "$WORKER_SH"
sed -i "s|__LOG_FILE__|$LOG_FILE|g" "$WORKER_SH"
sed -i "s|__AUDIO_FORMAT__|$AUDIO_FORMAT|g" "$WORKER_SH"
sed -i "s|__SLEEP_REQUESTS__|$PLAYLIST_SLEEP_REQUESTS|g" "$WORKER_SH"
sed -i "s|__SLEEP_INTERVAL__|$PLAYLIST_SLEEP_INTERVAL|g" "$WORKER_SH"

# 写入 ALBUMS 数组
echo 'ALBUMS=(' >> "$WORKER_SH"
for config in "${ALBUM_CONFIGS[@]}"; do
    printf ' %q\n' "$config" >> "$WORKER_SH"
done
echo ')' >> "$WORKER_SH"

cat >> "$WORKER_SH" << 'LOOPEOF'
for album_entry in "${ALBUMS[@]}"; do
    ALBUM_NAME=$(echo "$album_entry" | cut -d'|' -f1)
    SELECTION=$(echo "$album_entry" | cut -d'|' -f2)
    url=$(echo "$album_entry" | cut -d'|' -f3)
    FINAL_PATH=$(echo "$album_entry" | cut -d'|' -f4)
    ALBUM_ARTIST=$(echo "$album_entry" | cut -d'|' -f5)
    ENHANCED_MODE=$(echo "$album_entry" | cut -d'|' -f6)
    TYPE=$(echo "$album_entry" | cut -d'|' -f7)
    HAS_METADATA=$(echo "$album_entry" | cut -d'|' -f8)
    MV_TITLE=$(echo "$album_entry" | cut -d'|' -f9)
    MV_ARTIST=$(echo "$album_entry" | cut -d'|' -f10)
    MV_ALBUM=$(echo "$album_entry" | cut -d'|' -f11)
    MV_ALBUM_ARTIST=$(echo "$album_entry" | cut -d'|' -f12)
    BATCH_ALBUM=$(echo "$album_entry" | cut -d'|' -f13)
    NORMAL_SELECTION=$(echo "$album_entry" | cut -d'|' -f16)
    MV_VIDS=$(echo "$album_entry" | cut -d'|' -f17)
    MV_INFO=$(echo "$album_entry" | cut -d'|' -f18)
    MV_STRATEGY=$(echo "$album_entry" | cut -d'|' -f19)

    log "========================================"
    log "💿 $ALBUM_NAME | 📂 $FINAL_PATH | 📌 $TYPE"
    log "========================================"
    mkdir -p "$FINAL_PATH"

    IS_MV_SINGLE=false
    [ "$TYPE" = "single" ] && [ "$HAS_METADATA" != "True" ] && [ -n "$MV_TITLE" ] && IS_MV_SINGLE=true

    ls "$FINAL_PATH"/*.opus 2>/dev/null > /tmp/existing_before_$$.txt

    SLEEP_ARGS=""
    { [ "$TYPE" = "playlist" ] || [ "$TYPE" = "ytm_radio" ]; } && [ "$SLEEP_INTERVAL" -gt 0 ] && SLEEP_ARGS="--sleep-requests $SLEEP_REQUESTS --sleep-interval $SLEEP_INTERVAL"

    if [ "$ENHANCED_MODE" != "true" ]; then
        log "🖼️ 统一封面..."
        CTD=$(mktemp -d)
        "$YTDLP" $NODE_ARGS --no-warnings --write-thumbnail --skip-download --convert-thumbnails jpg \
            --playlist-items 1 -o "$CTD/%(id)s" "$url" >> "$LOG_FILE" 2>&1
        CS=$(find "$CTD" -name "*.jpg" -type f -exec ls -la {} \; 2>/dev/null | sort -k5 -rn | head -1 | awk '{print $NF}')
        if [ -n "$CS" ]; then
            cp "$CS" "$FINAL_PATH/cover.jpg"
            cover_compress "$FINAL_PATH/cover.jpg" "$FINAL_PATH/cover_tmp.jpg" 2>/dev/null
            if [ -f "$FINAL_PATH/cover_tmp.jpg" ]; then
                mv "$FINAL_PATH/cover_tmp.jpg" "$FINAL_PATH/cover.jpg"
                log "✅ 统一封面（压缩完成）"
            else
                log "✅ 统一封面（压缩失败，保留原图）"
            fi
        else
            log "⚠️ 未能获取统一封面"
        fi
        rm -rf "$CTD"
    fi

    MV_DATA=()
    parse_mv_info "$MV_INFO"

    if [ "$IS_MV_SINGLE" = true ]; then
        log "🚚 MV单曲(temp)..."
        "$YTDLP" $NODE_ARGS --user-agent "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36" \
            --embed-metadata --no-embed-thumbnail --windows-filenames --write-info-json \
            -f ba -x --audio-format "$AUDIO_FORMAT" --audio-quality 0 \
            -o "temp_mv_%(id)s.%(ext)s" -P "$FINAL_PATH" "$url" >> "$LOG_FILE" 2>&1
    elif [ "$MV_STRATEGY" = "2" ]; then
        log "🚚 默认值模式批量..."
        "$YTDLP" $NODE_ARGS --user-agent "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36" \
            --embed-metadata --no-embed-thumbnail --windows-filenames --yes-playlist \
            --parse-metadata "%(playlist_index)s:%(track_number)s" --write-info-json $SLEEP_ARGS \
            -f ba -x --audio-format "$AUDIO_FORMAT" --audio-quality 0 \
            --playlist-items "$SELECTION" \
            -o "%(artist,uploader)s - %(title)s.%(ext)s" -P "$FINAL_PATH" "$url" >> "$LOG_FILE" 2>&1
    else
        if [ -n "$NORMAL_SELECTION" ]; then
            log "🚚 正常曲目批量..."
            "$YTDLP" $NODE_ARGS --user-agent "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36" \
                --embed-metadata --no-embed-thumbnail --windows-filenames --yes-playlist \
                --parse-metadata "%(playlist_index)s:%(track_number)s" --write-info-json $SLEEP_ARGS \
                -f ba -x --audio-format "$AUDIO_FORMAT" --audio-quality 0 \
                --playlist-items "$NORMAL_SELECTION" \
                -o "%(artist,uploader)s - %(title)s.%(ext)s" -P "$FINAL_PATH" "$url" >> "$LOG_FILE" 2>&1
        fi
        if [ -n "$MV_VIDS" ] && [ "$MV_STRATEGY" = "1" ]; then
            for VID in $MV_VIDS; do
                SINGLE_URL="https://www.youtube.com/watch?v=$VID"
                log "🚚 MV逐首: $VID"
                "$YTDLP" $NODE_ARGS --user-agent "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36" \
                    --embed-metadata --no-embed-thumbnail --windows-filenames --write-info-json \
                    -f ba -x --audio-format "$AUDIO_FORMAT" --audio-quality 0 \
                    -o "temp_mv_%(id)s.%(ext)s" -P "$FINAL_PATH" "$SINGLE_URL" >> "$LOG_FILE" 2>&1
            done
        fi
        if [ -z "$NORMAL_SELECTION" ] && [ -z "$MV_VIDS" ]; then
            log "🚚 下载..."
            DOWNLOAD_ARGS=""
            [ "$SELECTION" != "ALL" ] && DOWNLOAD_ARGS="--playlist-items $SELECTION"
            "$YTDLP" $NODE_ARGS --user-agent "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36" \
                --embed-metadata --no-embed-thumbnail --windows-filenames --yes-playlist \
                --parse-metadata "%(playlist_index)s:%(track_number)s" --write-info-json $SLEEP_ARGS \
                -f ba -x --audio-format "$AUDIO_FORMAT" --audio-quality 0 $DOWNLOAD_ARGS \
                -o "%(artist,uploader)s - %(title)s.%(ext)s" -P "$FINAL_PATH" "$url" >> "$LOG_FILE" 2>&1
        fi
    fi
    log "✅ 下载完成"

    # ── MV 单曲后处理 ──
    if [ "$IS_MV_SINGLE" = true ]; then
        log "🏷️ MV单曲后处理..."
        for mv_f in "$FINAL_PATH"/temp_mv_*.opus; do
            [ -f "$mv_f" ] || continue
            SAFE_ARTIST=$(echo "$MV_ARTIST" | sed 's/[\/:*?"<>|]/-/g')
            SAFE_TITLE=$(echo "$MV_TITLE" | sed 's/[\/:*?"<>|]/-/g')
            NEW_NAME="${SAFE_ARTIST} - ${SAFE_TITLE}.opus"
            NEW_PATH="$FINAL_PATH/$NEW_NAME"
            [ -f "$NEW_PATH" ] && NEW_PATH="$FINAL_PATH/${SAFE_ARTIST} - ${SAFE_TITLE}_$(date +%s).opus"
            mv "$mv_f" "$NEW_PATH"
            log " 📝 重命名: $(basename "$mv_f") → $NEW_NAME"

            CF=""; JSON_FILE="${NEW_PATH%.opus}.info.json"
            [ ! -f "$JSON_FILE" ] && JSON_FILE=$(find "$FINAL_PATH" -name "temp_mv_*.info.json" 2>/dev/null | head -1)
            if [ -f "$JSON_FILE" ]; then
                if download_cover "$JSON_FILE" CF; then
                    CC="/tmp/cover_$$_compressed.jpg"
                    cover_compress "$CF" "$CC" 2>/dev/null
                    if [ -f "$CC" ]; then rm -f "$CF"; CF="$CC"; log "  🖼️ 封面已压缩"; fi
                fi
                rm -f "$JSON_FILE"
            fi
            mv_write_id3 "$NEW_PATH" "$MV_TITLE" "$MV_ARTIST" "$MV_ALBUM" "" "$CF"
            [ -n "$CF" ] && rm -f "$CF"
            echo "$NEW_PATH" >> /tmp/existing_before_$$.txt
        done
        rm -f "$FINAL_PATH"/temp_mv_* "$FINAL_PATH"/*.webm 2>/dev/null
        log "🎉 完成: $ALBUM_NAME"
        continue
    fi

    # ── 策略 2 后处理 ──
    if [ "$MV_STRATEGY" = "2" ]; then
        log "🏷️ 默认值后处理..."
        for f in "$FINAL_PATH"/*.opus; do
            [ -f "$f" ] || continue
            [[ "$(basename "$f")" == temp_* ]] && continue
            if grep -qxF "$f" /tmp/existing_before_$$.txt 2>/dev/null; then
                log " ⏭️ 跳过已存在: $(basename "$f")"
                continue
            fi
            JSON_FILE="${f%.opus}.info.json"
            TITLE=""
            [ -f "$JSON_FILE" ] && TITLE=$(python3 -c "import json, sys; print(json.load(open(sys.argv[1])).get('title',''))" "$JSON_FILE" 2>/dev/null)
            CF=""
            if [ -f "$JSON_FILE" ]; then
                if download_cover "$JSON_FILE" CF; then
                    CC="/tmp/cover_$$_compressed.jpg"
                    cover_compress "$CF" "$CC" 2>/dev/null
                    if [ -f "$CC" ]; then rm -f "$CF"; CF="$CC"; fi
                fi
                rm -f "$JSON_FILE"
            fi
            FINAL_ALBUM="$TITLE"
            embed_cover "$f" "" "$ALBUM_NAME" "$([ -n "$CF" ] && echo true || echo false)" "true" "$FINAL_ALBUM" "$CF" >> "$LOG_FILE" 2>&1
            [ -n "$CF" ] && rm -f "$CF"
            echo "$f" >> /tmp/existing_before_$$.txt
        done
        rm -f "$FINAL_PATH"/*.info.json "$FINAL_PATH"/*.webm 2>/dev/null
        rm -f /tmp/existing_before_$$.txt
        log "🎉 完成: $ALBUM_NAME"
        continue
    fi

    # ── MV曲目后处理（策略1）──
    if [ -n "$MV_VIDS" ] && [ "$MV_STRATEGY" = "1" ]; then
        log "🏷️ MV曲目后处理..."
        for mv_f in "$FINAL_PATH"/temp_mv_*.opus; do
            [ -f "$mv_f" ] || continue
            JSON_FILE="${mv_f%.opus}.info.json"
            VID=""
            [ -f "$JSON_FILE" ] && VID=$(python3 -c "import json, sys; print(json.load(open(sys.argv[1])).get('id',''))" "$JSON_FILE" 2>/dev/null)
            if [ -n "$VID" ] && [ -n "${MV_DATA[$VID]}" ]; then
                IFS='|' read -r TITLE ARTIST ALBUM <<< "${MV_DATA[$VID]}"
                SAFE_ARTIST=$(echo "$ARTIST" | sed 's/[\/:*?"<>|]/-/g')
                SAFE_TITLE=$(echo "$TITLE" | sed 's/[\/:*?"<>|]/-/g')
                NEW_NAME="${SAFE_ARTIST} - ${SAFE_TITLE}.opus"
                NEW_PATH="$FINAL_PATH/$NEW_NAME"
                [ -f "$NEW_PATH" ] && NEW_PATH="$FINAL_PATH/${SAFE_ARTIST} - ${SAFE_TITLE}_$(date +%s).opus"
                mv "$mv_f" "$NEW_PATH"
                log " 📝 重命名: $(basename "$mv_f") → $NEW_NAME"
                CF=""
                if [ -f "$JSON_FILE" ]; then
                    if download_cover "$JSON_FILE" CF; then
                        CC="/tmp/cover_$$_compressed.jpg"
                        cover_compress "$CF" "$CC" 2>/dev/null
                        if [ -f "$CC" ]; then rm -f "$CF"; CF="$CC"; fi
                    fi
                fi
                FINAL_ALBUM="${ALBUM:-$TITLE}"
                mv_write_id3 "$NEW_PATH" "$TITLE" "$ARTIST" "$FINAL_ALBUM" "" "$CF"
                [ -n "$CF" ] && rm -f "$CF"
                echo "$NEW_PATH" >> /tmp/existing_before_$$.txt
            fi
            [ -f "$JSON_FILE" ] && rm -f "$JSON_FILE"
        done
    fi

    # ── 正常后处理 ──
    log "🏷️ 后处理..."
    for f in "$FINAL_PATH"/*.opus; do
        [ -f "$f" ] || continue
        [[ "$(basename "$f")" == temp_* || "$(basename "$f")" == temp_mv_* ]] && continue
        if grep -qxF "$f" /tmp/existing_before_$$.txt 2>/dev/null; then
            log " ⏭️ 跳过已存在: $(basename "$f")"
            continue
        fi
        ORIG_ALBUM=""; CF=""; HC="false"
        if [ "$ENHANCED_MODE" = "true" ]; then
            JSON_FILE="${f%.opus}.info.json"
            if [ -f "$JSON_FILE" ]; then
                ORIG_ALBUM=$(python3 -c "import json, sys; print(json.load(open(sys.argv[1])).get('album',''))" "$JSON_FILE" 2>/dev/null)
                SA=$(python3 -c "import json, sys; print(json.load(open(sys.argv[1])).get('artist',''))" "$JSON_FILE" 2>/dev/null)
                HS=false
                [ -n "$ORIG_ALBUM" ] && [ -n "$SA" ] && HS=true
                log " 📀 元数据: $HS"
                if download_cover "$JSON_FILE" CF; then
                    if [ "$HS" = "true" ]; then
                        CC="/tmp/cover_$$_cropped.jpg"
                        if cover_crop_center "$CF" "$CC"; then
                            rm -f "$CF"; CF="$CC"; HC="true"
                            log "  🖼️ 封面已居中裁剪"
                        else
                            log "  ⚠️ 裁剪失败，使用原图"
                            HC="true"
                        fi
                    else
                        CC="/tmp/cover_$$_compressed.jpg"
                        if cover_compress "$CF" "$CC"; then
                            rm -f "$CF"; CF="$CC"; HC="true"
                            log "  🖼️ 封面已压缩"
                        else
                            HC="true"
                        fi
                    fi
                fi
                rm -f "$JSON_FILE"
            fi
        else
            ORIG_ALBUM="$ALBUM_NAME"
            if [ -f "$FINAL_PATH/cover.jpg" ] && [ "$(file_size "$FINAL_PATH/cover.jpg" 2>/dev/null)" -gt 10240 ]; then
                CF="$FINAL_PATH/cover.jpg"
                HC="true"
                log "  🖼️ 使用统一封面"
            fi
        fi
        embed_cover "$f" "$ALBUM_ARTIST" "$ALBUM_NAME" "$HC" "$ENHANCED_MODE" "$ORIG_ALBUM" "$CF" >> "$LOG_FILE" 2>&1
        [ -n "$CF" ] && [ "$CF" != "$FINAL_PATH/cover.jpg" ] && rm -f "$CF"
    done

    rm -f "$FINAL_PATH"/*.info.json "$FINAL_PATH"/*.webm 2>/dev/null
    rm -f /tmp/existing_before_$$.txt
    log "🎉 完成: $ALBUM_NAME"
done

rm -f "$0"
exit 0
LOOPEOF

# ── 启动后台脚本 ──
nohup bash "$WORKER_SH" >> "$LOG_FILE" 2>&1 &
WORKER_PID=$!

echo ""
echo "📝 日志: tail -n +1 -f \"$LOG_FILE\""
echo "🚀 切入后台..."
echo "✅ PID: $WORKER_PID"