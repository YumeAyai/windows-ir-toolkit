#!/bin/bash
# ============================================================
# Volatility 3 一键安装(分析机用,macOS / Linux)
# ============================================================
set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
VOL3_DIR="$SCRIPT_DIR/volatility3"

echo -e "${CYAN}[*] Volatility 3 安装脚本 (macOS / Linux)${NC}"
echo -e "${CYAN}[*] 工具包: $VOL3_DIR${NC}"
echo ""

# 检查 Python
if ! command -v python3 &>/dev/null; then
    echo -e "${RED}[ERROR] python3 未找到${NC}"
    echo "  请先安装 Python 3.8+ (https://www.python.org/downloads/)"
    exit 1
fi

PY_VERSION=$(python3 -c 'import sys; print("%d.%d" % sys.version_info[:2])')
echo -e "${GREEN}[OK] Python $PY_VERSION${NC}"

# 找 wheel 文件
WHL=$(ls "$VOL3_DIR"/volatility3-*.whl 2>/dev/null | head -1)
if [ -z "$WHL" ]; then
    echo -e "${RED}[ERROR] 找不到 vol3 wheel${NC}"
    echo "  期待: $VOL3_DIR/volatility3-*.whl"
    echo "  请用 GitHub release 的完整 zip 包,或 pip install volatility3"
    exit 1
fi

echo -e "${GREEN}[OK] Wheel: $(basename "$WHL")${NC}"

# 装 venv 还是 --user
if [ -w "/usr/local/lib/python${PY_VERSION}/site-packages" ] 2>/dev/null; then
    echo -e "${CYAN}[*] 系统级安装(有写权限)...${NC}"
    python3 -m pip install "$WHL" 2>&1 | tail -3
else
    echo -e "${CYAN}[*] 用 --user 安装(无系统写权限)...${NC}"
    python3 -m pip install --user "$WHDL" 2>&1 | tail -3
fi

# 验证
echo ""
echo -e "${CYAN}[*] 验证安装...${NC}"
if command -v vol &>/dev/null; then
    vol --version
    echo -e "${GREEN}[OK] vol 已可用${NC}"
elif python3 -m volatility3 --help &>/dev/null; then
    echo -e "${GREEN}[OK] 'python3 -m volatility3' 已可用${NC}"
else
    echo -e "${YELLOW}[WARN] 'vol' 命令没找到,试试 'python3 -m volatility3'${NC}"
fi

echo ""
echo -e "${CYAN}[*] 接下来:${NC}"
echo "  vol -f mem.raw windows.info"
echo "  vol -f mem.raw windows.pstree"
echo "  vol -f mem.raw windows.netscan"
echo ""
echo -e "${CYAN}[*] 如果还没下载 Volatility symbols,跑:${NC}"
echo "  ./install_symbols.sh   # 或手动:"
echo "  mkdir -p ~/.local/share/volatility3/symbols"
echo "  unzip 03_analysis/volatility3/symbols/windows.zip -d ~/.local/share/volatility3/symbols/"
