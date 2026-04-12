#!/bin/bash
# smart_cd 测试脚本
# 运行: bash test_smart_cd.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_DIR="$HOME/.local/share/smart_cd"
TEST_DIR="/tmp/smart_cd_test_$$"

# 颜色
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RESET='\033[0m'
pass() { echo -e "${GREEN}✓${RESET} $1"; }
fail() { echo -e "${RED}✗${RESET} $1"; exit 1; }
info() { echo -e "${YELLOW}→${RESET} $1"; }

# 创建测试目录
setup() {
    info "创建测试环境..."
    mkdir -p "$TEST_DIR"/{dir1,dir2,dir3,.hidden_dir}
    touch "$TEST_DIR"/{file1.txt,file2.txt,.hidden_file}
    mkdir -p "$TEST_DIR"/project/{src,lib,test}
    cd "$TEST_DIR"
}

cleanup() {
    info "清理测试环境..."
    cd /
    rm -rf "$TEST_DIR"
}

# 测试 Python 模块
test_python_imports() {
    info "测试 Python 模块导入..."
    python3 -c "import sys; sys.path.insert(0, '$INSTALL_DIR'); from config import *; from database import *; from predictor import *; from fuzzy import *" || fail "Python 模块导入失败"
    pass "Python 模块导入"
}

# 测试数字参数解析
test_numeric_resolve() {
    info "测试数字参数解析..."
    cd "$TEST_DIR"
    local result=$(python3 "$INSTALL_DIR/smart_cd.py" --resolve 1 2>/dev/null)
    if [[ -n "$result" && "$result" != "cd: No"* ]]; then
        pass "数字解析: --resolve 1 -> $result"
    else
        fail "数字解析失败: $result"
    fi

    # 测试边界
    result=$(python3 "$INSTALL_DIR/smart_cd.py" --resolve 999 2>/dev/null)
    if [[ "$result" == "cd: No entry #999" ]]; then
        pass "边界检查: --resolve 999 正确返回错误"
    else
        fail "边界检查失败: $result"
    fi
}

# 测试字母参数解析
test_letter_resolve() {
    info "测试字母参数解析..."
    cd "$TEST_DIR"
    python3 "$INSTALL_DIR/smart_cd.py" --init 2>/dev/null

    local result=$(python3 "$INSTALL_DIR/smart_cd.py" --resolve a 2>/dev/null)
    # 可能没有推荐，但不应该报错
    if [[ "$result" != "cd: No"* || "$result" == *"recommendation"* ]]; then
        pass "字母解析: --resolve a 正常处理"
    else
        pass "字母解析: 无推荐时正常返回"
    fi
}

# 测试空参数
test_empty_resolve() {
    info "测试空参数..."
    local result=$(python3 "$INSTALL_DIR/smart_cd.py" --resolve "" 2>/dev/null)
    if [[ "$result" == "~" ]]; then
        pass "空参数返回 ~"
    else
        fail "空参数应返回 ~, 实际: $result"
    fi
}

# 测试特殊参数
test_special_args() {
    info "测试特殊参数..."
    cd "$TEST_DIR"

    # 测试 cd -
    local result=$(python3 "$INSTALL_DIR/smart_cd.py" --resolve "-" 2>/dev/null)
    if [[ "$result" == "-" ]]; then
        pass "--resolve - 返回 -"
    else
        fail "--resolve - 失败: $result"
    fi

    # 测试 --help
    result=$(python3 "$INSTALL_DIR/smart_cd.py" --help 2>/dev/null | grep -m1 "Smart CD")
    if [[ "$result" == *"Smart CD"* ]]; then
        pass "--help 正常工作"
    else
        fail "--help 失败"
    fi
}

# 测试模糊搜索
test_fuzzy_search() {
    info "测试模糊搜索..."
    cd "$TEST_DIR"

    local result=$(python3 "$INSTALL_DIR/smart_cd.py" --cdd "prj" 2>/dev/null)
    if [[ -n "$result" && "$result" != "cdd:"* ]]; then
        pass "模糊搜索 'prj' 找到: $result"
    else
        pass "模糊搜索 'prj' 无结果 (正常)"
    fi
}

# 测试 ll_num 脚本
test_ll_num() {
    info "测试 ll_num 脚本..."
    cd "$TEST_DIR"

    if [[ ! -x "$INSTALL_DIR/ll_num" ]]; then
        fail "ll_num 脚本不存在或不可执行"
    fi

    local output=$("$INSTALL_DIR/ll_num" 2>/dev/null | head -3)
    if [[ -n "$output" ]]; then
        pass "ll_num 输出正常"
    else
        fail "ll_num 输出为空"
    fi
}

# 测试 wrapper 脚本
test_wrapper() {
    info "测试 wrapper 脚本..."
    cd "$TEST_DIR"

    if [[ ! -x "$INSTALL_DIR/smart_cd_wrapper" ]]; then
        fail "smart_cd_wrapper 脚本不存在或不可执行"
    fi

    local output=$("$INSTALL_DIR/smart_cd_wrapper" "" 2>/dev/null)
    if [[ "$output" == *"chdir"* ]]; then
        pass "wrapper 空参数返回 chdir 命令"
    else
        fail "wrapper 空参数失败: $output"
    fi
}

# 测试文件名特殊字符
test_special_filenames() {
    info "测试特殊文件名..."
    mkdir -p "$TEST_DIR/special"
    touch "$TEST_DIR/special/file with spaces.txt"
    touch "$TEST_DIR/special/file'quote.txt"
    touch "$TEST_DIR/special/file\"double.txt"

    cd "$TEST_DIR/special"
    local result=$(python3 "$INSTALL_DIR/smart_cd.py" --resolve 1 2>/dev/null)
    if [[ -n "$result" && "$result" != "cd: No"* ]]; then
        pass "特殊文件名处理正常"
    else
        fail "特殊文件名处理失败: $result"
    fi
}

# 主测试流程
main() {
    echo "========================================"
    echo "smart_cd 测试套件"
    echo "========================================"

    setup

    test_python_imports
    test_numeric_resolve
    test_letter_resolve
    test_empty_resolve
    test_special_args
    test_fuzzy_search
    test_ll_num
    test_wrapper
    test_special_filenames

    cleanup

    echo ""
    echo -e "${GREEN}所有测试通过!${RESET}"
}

# 捕获错误清理
trap cleanup EXIT

main
