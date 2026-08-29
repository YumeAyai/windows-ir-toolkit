#!/bin/bash
# ============================================================
# macOS / Linux 取证工具一键安装
# 从 GitHub Releases 拉取最新的 tools-* release
# ============================================================
set -e

REPO="${REPO:-YumeAyai/windows-ir-toolkit}"
OUTPUT_DIR="${1:-.}"

# 颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}[*] 输出目录: $OUTPUT_DIR${NC}"
echo -e "${CYAN}[*] 仓库: $REPO${NC}"
echo ""

# 创建目录
mkdir -p "$OUTPUT_DIR/01_acquire" "$OUTPUT_DIR/03_analysis"

# ============== 找最新 tools-* release ==============
echo -e "${GREEN}[+] 查询 GitHub 最新 tools release...${NC}"
RELEASE_JSON=$(curl -fsSL "https://api.github.com/repos/$REPO/releases")

LATEST_TAG=$(echo "$RELEASE_JSON" | python3 -c "
import sys, json
releases = [r for r in json.load(sys.stdin) if r['tag_name'].startswith('tools-')]
if not releases:
    sys.exit(1)
releases.sort(key=lambda r: r['created_at'], reverse=True)
print(releases[0]['tag_name'])
" 2>/dev/null) || {
    echo -e "${YELLOW}[!] 还没生成过 tools-* release,先去触发 workflow:${NC}"
    echo "    https://github.com/$REPO/actions"
    exit 1
}

echo -e "    ${GREEN}找到: $LATEST_TAG${NC}"
echo ""

# ============== 下载 ==============
TEMP_DIR=$(mktemp -d)
trap "rm -rf $TEMP_DIR" EXIT

ASSETS=$(echo "$RELEASE_JSON" | python3 -c "
import sys, json
releases = [r for r in json.load(sys.stdin) if r['tag_name'] == '$LATEST_TAG']
if not releases:
    sys.exit(1)
for a in releases[0].get('assets', []):
    print(f'{a[\"name\"]}\t{a[\"browser_download_url\"]}\t{a[\"size\"]}')
")

SUCCESS=()
FAILED=()
while IFS=$'\t' read -r NAME URL SIZE; do
    SIZE_MB=$(echo "scale=2; $SIZE/1048576" | bc)
    echo -e "  ${CYAN}[↓]${NC} $NAME ($SIZE_MB MB)..."

    if [[ "$NAME" == winpmem* ]]; then
        TARGET="$OUTPUT_DIR/01_acquire/$NAME"
    else
        TARGET="$TEMP_DIR/$NAME"
    fi

    if curl -fsSL --retry 3 --retry-delay 5 -o "$TARGET" "$URL"; then
        echo -e "       ${GREEN}✓${NC}"
        SUCCESS+=("$NAME")
    else
        echo -e "       ${RED}✗ download failed${NC}"
        FAILED+=("$NAME")
    fi
done <<< "$ASSETS"

# ============== 处理 capa zip ==============
CAPA_ZIP=$(find "$TEMP_DIR" -name "*.zip" 2>/dev/null | head -1)
if [ -n "$CAPA_ZIP" ]; then
    echo ""
    echo -e "${GREEN}[+] 解压 capa...${NC}"
    mkdir -p "$TEMP_DIR/capa_extracted"
    unzip -q "$CAPA_ZIP" -d "$TEMP_DIR/capa_extracted"

    # 找到 capa.exe,放到 03_analysis/capa/
    CAPA_EXE=$(find "$TEMP_DIR/capa_extracted" -name "capa.exe" | head -1)
    if [ -n "$CAPA_EXE" ]; then
        mkdir -p "$OUTPUT_DIR/03_analysis/capa"
        cp -r "$(dirname "$CAPA_EXE")"/* "$OUTPUT_DIR/03_analysis/capa/"
        chmod +x "$OUTPUT_DIR/03_analysis/capa/capa.exe"
        echo -e "    ${GREEN}✓ capa 已放到 03_analysis/capa/${NC}"
    fi
fi

# ============== 报告 ==============
echo ""
echo "============================================================"
echo -e "${GREEN}完成!${NC}"
echo -e "  ${GREEN}✓ 下载成功: ${#SUCCESS[@]} 个${NC}"
if [ ${#FAILED[@]} -gt 0 ]; then
    echo -e "  ${RED}✗ 失败:     ${#FAILED[@]} 个${NC}"
fi
echo ""
echo -e "${YELLOW}[!] 以下工具需要手动下载(官方需注册):${NC}"
echo "    - FTK Imager         https://www.exterro.com/ftk-imager"
echo "    - Magnet RAM Capture https://www.magnetforensics.com/"
echo "    - DumpIt             https://www.comae.com/"
echo ""
echo -e "${CYAN}[*] Windows 取证: 把整个目录拷到 U 盘,双击 02_collection\\acquire.bat${NC}"
echo -e "${CYAN}[*] 内存分析:  vol -f mem.raw windows.pstree  (需要 vol3)${NC}"
