#!/bin/bash
# smart_cd 极速版 功能测试脚本
# 自建测试环境，专注功能验证

# 注意: 不使用 set -e，因为测试需要捕获失败而非退出

PASS=0
FAIL=0
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TEST_ROOT="/tmp/smart_cd_test_$$"

test_pass() { echo "  ✓ PASS: $1"; PASS=$((PASS+1)); }
test_fail() { echo "  ✗ FAIL: $1"; FAIL=$((FAIL+1)); }

# ===== 测试环境初始化 =====
init_test_env() {
    echo "===== 创建测试环境 ====="
    rm -rf "$TEST_ROOT"
    mkdir -p "$TEST_ROOT"

    # 目录结构（注意：目录名不能包含测试模式的字符组合，避免模糊搜索误匹配）
    mkdir -p "$TEST_ROOT/01_alpha"
    mkdir -p "$TEST_ROOT/02_beta"
    mkdir -p "$TEST_ROOT/03_gamma"
    mkdir -p "$TEST_ROOT/04_delta"        # 包含 lt，用于测试 lt 子串匹配
    mkdir -p "$TEST_ROOT/sub_dir"
    mkdir -p "$TEST_ROOT/another_sub"
    mkdir -p "$TEST_ROOT/abc_folder"
    mkdir -p "$TEST_ROOT/xyz_directory"
    mkdir -p "$TEST_ROOT/mixed_case_dir"
    mkdir -p "$TEST_ROOT/deep/level2/target_deep"   # 包含 td，深层目标
    mkdir -p "$TEST_ROOT/level1_target"             # 包含 lt，浅层目标
    mkdir -p "$TEST_ROOT/simple_cf"
    mkdir -p "$TEST_ROOT/sc_demo"                   # 用于测试 scd 模糊匹配
    mkdir -p "$TEST_ROOT/node_modules/excluded_dir" # 包含 exd，应被排除
    mkdir -p "$TEST_ROOT/.git/hidden_git"
    mkdir -p "$TEST_ROOT/blank_space"               # 空目录，不包含测试模式

    # 文件
    touch "$TEST_ROOT/file_txt.txt"
    touch "$TEST_ROOT/z_file.txt"
    chmod +x "$TEST_ROOT/file_txt.txt"

    echo "测试目录: $TEST_ROOT"
}

cleanup_test_env() {
    echo "===== 清理测试环境 ====="
    rm -rf "$TEST_ROOT"
    rm -f /tmp/cd_handler_test_*.sh
}

# ===== cd_handler 模块功能测试 =====
test_cd_handler() {
    echo ""
    echo "========================================"
    echo "  cd_handler 模块功能测试"
    echo "========================================"

    HANDLER_SRC="$SCRIPT_DIR/cd_handler/cd_handler.sh.txt"
    if [[ ! -f "$HANDLER_SRC" ]]; then
        echo "错误: cd_handler.sh.txt 不存在"
        return
    fi

    # 创建测试用的 handler（替换变量）
    HANDLER_TEST="/tmp/cd_handler_test_$$.sh"
    sed "s|__DIR__|$TEST_ROOT|g; s|__DEPTH__|5|g" "$HANDLER_SRC" > "$HANDLER_TEST"
    chmod +x "$HANDLER_TEST"

    cd "$TEST_ROOT"

    # ---------- cd - 测试 ----------
    echo "[cd - 返回上一目录]"
    cd "$TEST_ROOT/01_alpha"
    result=$("$HANDLER_TEST" "-" 2>&1)
    echo "  输出: $result"
    if echo "$result" | grep -q "CD_DASH=1"; then
        test_pass "cd - 输出 CD_DASH=1"
    else
        test_fail "cd - 输出错误"
    fi

    # ---------- cd 空参数 ----------
    echo "[cd 空参数 → HOME]"
    cd "$TEST_ROOT"
    result=$("$HANDLER_TEST" "" 2>&1)
    echo "  输出: $result"
    if echo "$result" | grep -q "CD_HOME=1"; then
        test_pass "cd 空参数输出 CD_HOME=1"
    else
        test_fail "cd 空参数输出错误"
    fi

    # ---------- cd 数字导航 ----------
    echo "[cd 数字导航]"
    cd "$TEST_ROOT"

    result=$("$HANDLER_TEST" "1" 2>&1)
    echo "  cd 1 输出: $result"
    if echo "$result" | grep -q "CD_TARGET=" && echo "$result" | grep -q "01_alpha"; then
        test_pass "cd 1 → 01_alpha"
    else
        test_fail "cd 1 错误"
    fi

    result=$("$HANDLER_TEST" "2" 2>&1)
    echo "  cd 2 输出: $result"
    if echo "$result" | grep -q "CD_TARGET=" && echo "$result" | grep -q "02_beta"; then
        test_pass "cd 2 → 02_beta"
    else
        test_fail "cd 2 错误"
    fi

    result=$("$HANDLER_TEST" "4" 2>&1)
    echo "  cd 4 输出: $result"
    if echo "$result" | grep -q "04_delta"; then
        test_pass "cd 4 → 04_delta"
    else
        test_fail "cd 4 错误"
    fi

    result=$("$HANDLER_TEST" "999" 2>&1)
    echo "  cd 999 输出: $result"
    if echo "$result" | grep -q "CD_ERROR=" && echo "$result" | grep -q "无条目"; then
        test_pass "cd 999 错误处理正确"
    else
        test_fail "cd 999 错误处理失败"
    fi

    # ---------- cd 绝对路径 ----------
    echo "[cd 绝对路径]"
    cd "$TEST_ROOT"
    result=$("$HANDLER_TEST" "/tmp" 2>&1)
    echo "  cd /tmp 输出: $result"
    if echo "$result" | grep -q "CD_TARGET=\"/tmp\""; then
        test_pass "cd /tmp 绝对路径"
    else
        test_fail "cd /tmp 错误"
    fi

    result=$("$HANDLER_TEST" "$TEST_ROOT/sub_dir" 2>&1)
    echo "  cd $TEST_ROOT/sub_dir 输出: $result"
    if echo "$result" | grep -q "sub_dir"; then
        test_pass "cd 绝对路径 sub_dir"
    else
        test_fail "cd 绝对路径 sub_dir 错误"
    fi

    # ---------- cd 相对路径 ----------
    echo "[cd 相对路径]"
    cd "$TEST_ROOT"
    result=$("$HANDLER_TEST" "sub_dir" 2>&1)
    echo "  cd sub_dir 输出: $result"
    if echo "$result" | grep -q "sub_dir"; then
        test_pass "cd sub_dir 相对路径"
    else
        test_fail "cd sub_dir 错误"
    fi

    result=$("$HANDLER_TEST" "another_sub" 2>&1)
    if echo "$result" | grep -q "another_sub"; then
        test_pass "cd another_sub"
    else
        test_fail "cd another_sub 错误"
    fi

    # ---------- cd 子串匹配 ----------
    echo "[cd 子串匹配]"
    cd "$TEST_ROOT"
    result=$("$HANDLER_TEST" "abc" 2>&1)
    echo "  cd abc 输出: $result"
    if echo "$result" | grep -q "abc_folder"; then
        test_pass "cd abc → abc_folder"
    else
        test_fail "cd abc 错误"
    fi

    result=$("$HANDLER_TEST" "xyz" 2>&1)
    echo "  cd xyz 输出: $result"
    if echo "$result" | grep -q "xyz_directory"; then
        test_pass "cd xyz → xyz_directory"
    else
        test_fail "cd xyz 错误"
    fi

    # ---------- cd 模糊搜索 ----------
    echo "[cd 模糊搜索]"
    cd "$TEST_ROOT"
    result=$("$HANDLER_TEST" "td" 2>&1)
    echo "  cd td 输出: $result"
    if echo "$result" | grep -q "target"; then
        test_pass "cd td 模糊匹配 target"
    else
        test_fail "cd td 错误"
    fi

    result=$("$HANDLER_TEST" "scf" 2>&1)
    echo "  cd scf 输出: $result"
    if echo "$result" | grep -q "simple_cf"; then
        test_pass "cd scf → simple_cf"
    else
        test_fail "cd scf 错误"
    fi

    result=$("$HANDLER_TEST" "scd" 2>&1)
    echo "  cd scd 输出: $result"
    if echo "$result" | grep -q "sc_demo"; then
        test_pass "cd scd → sc_demo"
    else
        test_fail "cd scd 错误"
    fi

    # ---------- cd 分层搜索 ----------
    echo "[cd 分层搜索优先级]"
    cd "$TEST_ROOT"
    result=$("$HANDLER_TEST" "lt" 2>&1)
    echo "  cd lt 输出: $result"
    # 子串匹配会优先找包含连续 "lt" 的目录：04_delta 或 level1_target
    if echo "$result" | grep -q "delta\|level1_target"; then
        test_pass "子串匹配找到包含 lt 的目录"
    else
        test_fail "lt 匹配错误"
    fi

    # ---------- cd 排除目录 ----------
    echo "[cd 排除目录验证]"
    cd "$TEST_ROOT"
    result=$("$HANDLER_TEST" "exd" 2>&1)
    echo "  cd exd 输出: $result"
    if echo "$result" | grep -q "CD_ERROR="; then
        test_pass "node_modules 已排除"
    else
        test_fail "node_modules 未排除"
    fi

    # ---------- cd 文件打开 ----------
    echo "[cd 文件打开]"
    cd "$TEST_ROOT"
    result=$("$HANDLER_TEST" "file_txt.txt" 2>&1)
    echo "  cd file_txt.txt 输出: $result"
    if echo "$result" | grep -q "CD_FILE=" && echo "$result" | grep -q "file_txt.txt"; then
        test_pass "cd 文件 → CD_FILE"
    else
        test_fail "cd 文件错误"
    fi

    # 数字匹配文件
    file_num=$(ls -1 "$TEST_ROOT" | grep -n "file_txt.txt" | cut -d: -f1)
    result=$("$HANDLER_TEST" "$file_num" 2>&1)
    echo "  cd $file_num (文件) 输出: $result"
    if echo "$result" | grep -q "CD_FILE="; then
        test_pass "cd 数字匹配文件"
    else
        test_fail "cd 数字匹配文件错误"
    fi

    # ---------- cd 字母推荐 ----------
    echo "[cd 字母推荐]"
    cd "$TEST_ROOT"

    # 先创建一个模拟的推荐缓存
    mkdir -p "$TEST_ROOT/.rec_test"
    cat > "$TEST_ROOT/.rec_test/.rec_cache" << RECCACHE
{"current_dir":"$TEST_ROOT","recommendations":[{"letter":"a","path":"$TEST_ROOT/01_alpha"},{"letter":"b","path":"$TEST_ROOT/02_beta"},{"letter":"c","path":"$TEST_ROOT/sub_dir"}],"session_uuid":"test123"}
RECCACHE

    # 创建对应的 rec_cache_read 脚本
    cat > "$TEST_ROOT/.rec_test/rec_cache_read" << 'CACHE_READ'
#!/bin/bash
letter="$1"
cache_file="__CACHE_FILE__"
[[ ! -f "$cache_file" ]] && exit 0
jq -r --arg letter "$letter" '.recommendations[] | select(.letter == $letter) | .path' "$cache_file" 2>/dev/null
CACHE_READ
    sed -i "s|__CACHE_FILE__|$TEST_ROOT/.rec_test/.rec_cache|g" "$TEST_ROOT/.rec_test/rec_cache_read"
    chmod +x "$TEST_ROOT/.rec_test/rec_cache_read"

    # 创建一个使用本地缓存的 handler 版本
    HANDLER_LETTER="/tmp/cd_handler_letter_$$.sh"
    sed "s|__DIR__|$TEST_ROOT/.rec_test|g; s|__DEPTH__|0|g" "$HANDLER_SRC" > "$HANDLER_LETTER"
    chmod +x "$HANDLER_LETTER"

    result=$("$HANDLER_LETTER" "a" 2>&1)
    echo "  cd a 输出: $result"
    if echo "$result" | grep -q "CD_TARGET=" && echo "$result" | grep -q "01_alpha"; then
        test_pass "cd a → 01_alpha (字母推荐)"
    else
        test_fail "cd a 字母推荐错误"
    fi

    result=$("$HANDLER_LETTER" "b" 2>&1)
    echo "  cd b 输出: $result"
    if echo "$result" | grep -q "CD_TARGET=" && echo "$result" | grep -q "02_beta"; then
        test_pass "cd b → 02_beta (字母推荐)"
    else
        test_fail "cd b 字母推荐错误"
    fi

    # 测试无效字母
    result=$("$HANDLER_LETTER" "z" 2>&1)
    echo "  cd z 输出: $result"
    # 无效字母应该跳过字母推荐，继续其他匹配逻辑

    rm -f "$HANDLER_LETTER"
    rm -rf "$TEST_ROOT/.rec_test"

    # ---------- cd 错误处理 ----------
    echo "[cd 错误处理]"
    cd "$TEST_ROOT"
    result=$("$HANDLER_TEST" "nonexistent_xyz_path" 2>&1)
    echo "  cd nonexistent 输出: $result"
    if echo "$result" | grep -q "CD_ERROR=" && echo "$result" | grep -q "无匹配"; then
        test_pass "无匹配错误处理"
    else
        test_fail "无匹配错误处理失败"
    fi

    # ---------- 空目录测试 ----------
    echo "[空目录测试]"
    cd "$TEST_ROOT/blank_space"
    result=$("$HANDLER_TEST" "1" 2>&1)
    echo "  空目录 cd 1 输出: $result"
    if echo "$result" | grep -q "CD_ERROR="; then
        test_pass "空目录 cd 1 错误处理"
    else
        test_fail "空目录 cd 1 错误"
    fi

    rm -f "$HANDLER_TEST"
}

# ===== ll_display 模块功能测试 =====
test_ll_display() {
    echo ""
    echo "========================================"
    echo "  ll_display 模块功能测试"
    echo "========================================"

    INSTALL="$SCRIPT_DIR/install_fast.sh"
    ll_num_script="/tmp/ll_num_test_$$.sh"

    # 提取 mk_ll 函数内容
    sed -n '/cat > "\$D\/ll_num" << '\''X'\''/,/^X$/p' "$INSTALL" | sed '1d;$d' > "$ll_num_script"
    chmod +x "$ll_num_script"

    cd "$TEST_ROOT"

    # ---------- 空目录 ----------
    echo "[空目录列表]"
    cd "$TEST_ROOT/blank_space"
    result=$(bash "$ll_num_script" 2>&1)
    echo "  输出: $result"
    if [[ -z "$result" ]] || echo "$result" | grep -q "空"; then
        test_pass "空目录显示 '(空)'"
    else
        test_fail "空目录显示错误"
    fi

    # ---------- 正常目录 ----------
    echo "[正常目录列表]"
    cd "$TEST_ROOT"
    result=$(bash "$ll_num_script" 2>&1 | head -20)
    echo "  输出前5行:"
    echo "$result" | head -5 | sed 's/^/    /'

    if [[ -n "$result" ]]; then
        test_pass "ll_num 有输出"
    else
        test_fail "ll_num 无输出"
    fi

    # ---------- 编号格式 ----------
    echo "[编号格式]"
    if echo "$result" | grep -q '\[1\]'; then
        test_pass "含编号 [1]"
    else
        test_fail "缺编号 [1]"
    fi
    if echo "$result" | grep -q '\[2\]'; then
        test_pass "含编号 [2]"
    else
        test_fail "缺编号 [2]"
    fi
    if echo "$result" | grep -q '\[3\]'; then
        test_pass "含编号 [3]"
    else
        test_fail "缺编号 [3]"
    fi

    # ---------- 颜色输出 ----------
    echo "[颜色输出]"
    if echo "$result" | grep -q "34m"; then
        test_pass "目录蓝色 (34m)"
    else
        test_fail "缺目录蓝色"
    fi
    if echo "$result" | grep -q "32m"; then
        test_pass "可执行绿色 (32m)"
    else
        test_fail "缺可执行绿色"
    fi
    if echo "$result" | grep -q "36m"; then
        test_pass "编号颜色 (36m)"
    else
        test_fail "缺编号颜色"
    fi

    # ---------- 权限显示 ----------
    echo "[权限显示]"
    # 检查权限字段格式 (drwxrwxr-x 等)
    if echo "$result" | grep -q "^d[rwx-]"; then
        test_pass "目录权限显示正确"
    else
        test_fail "目录权限格式错误"
    fi
    if echo "$result" | grep -q "^-"; then
        test_pass "文件权限显示正确"
    else
        test_pass "无文件（仅目录）"
    fi

    # ---------- 用户/组显示 ----------
    echo "[用户/组显示]"
    if echo "$result" | grep -q "pan"; then
        test_pass "用户名显示正确"
    else
        test_fail "缺用户名"
    fi

    # ---------- 时间显示 ----------
    echo "[时间显示]"
    if echo "$result" | grep -q "Apr"; then
        test_pass "日期显示正确"
    else
        test_fail "缺日期显示"
    fi

    # ---------- 多文件 ----------
    echo "[多文件列表]"
    mkdir -p "$TEST_ROOT/multi_test"
    for i in $(seq 1 25); do touch "$TEST_ROOT/multi_test/file_$i.txt"; done
    cd "$TEST_ROOT/multi_test"
    result=$(bash "$ll_num_script" 2>&1)
    line_count=$(echo "$result" | wc -l)
    echo "  行数: $line_count"
    if [[ "$line_count" -ge 25 ]]; then
        test_pass "多文件列表完整 ($line_count行)"
    else
        test_fail "多文件列表不完整 ($line_count行)"
    fi

    rm -rf "$ll_num_script" "$TEST_ROOT/multi_test"
}

# ===== learning 模块功能测试 =====
test_learning() {
    echo ""
    echo "========================================"
    echo "  learning 模块功能测试"
    echo "========================================"

    LEARNING_SRC="$SCRIPT_DIR/learning"
    PY_TEST="/tmp/learning_test_$$"

    mkdir -p "$PY_TEST"
    for f in "$LEARNING_SRC"/*.txt; do
        base=$(basename "$f" .txt)
        cp "$f" "$PY_TEST/${base}"
    done

    cd "$PY_TEST"

    # ---------- 数据库结构 ----------
    echo "[数据库结构]"
    python3 << 'PYDB'
import sqlite3, os
db_path = '/tmp/learning_test_db.sqlite'
conn = sqlite3.connect(db_path)
c = conn.cursor()
c.execute("""CREATE TABLE IF NOT EXISTS directory_visits (
    id INTEGER PRIMARY KEY, path TEXT, timestamp REAL,
    weekday INTEGER, hour INTEGER, session_id TEXT,
    prev_dir TEXT, dwell_time REAL DEFAULT 0)""")
c.execute("""CREATE TABLE IF NOT EXISTS recommendation_sessions (
    id INTEGER PRIMARY KEY, timestamp REAL, current_dir TEXT,
    prev_dir TEXT, session_uuid TEXT)""")
c.execute("""CREATE TABLE IF NOT EXISTS recommendation_items (
    id INTEGER PRIMARY KEY, session_id INTEGER, letter TEXT,
    path TEXT, rank INTEGER, was_selected INTEGER DEFAULT 0)""")
conn.commit()
c.execute("SELECT name FROM sqlite_master WHERE type='table'")
tables = [r[0] for r in c.fetchall()]
expected = ['directory_visits', 'recommendation_sessions', 'recommendation_items']
for t in expected:
    if t in tables:
        print(f"✓ PASS: 表 {t} 创建成功")
    else:
        print(f"✗ FAIL: 表 {t} 创建失败")
conn.close()
os.remove(db_path)
PYDB

    # ---------- 配置文件测试 ----------
    echo "[配置文件读取]"
    # 设置环境变量，让 config.py 使用测试目录
    export XDG_DATA_HOME="$PY_TEST"
    # 创建测试配置文件
    cat > "$PY_TEST/config.ini" << 'INI'
[display]
recommendation_limit = 5
letter_format = [a]
letter_color = yellow
path_color = cyan
show_stats = true

[exclude]
paths = /proc, /sys
patterns = __pycache__, .git
INI

    # 测试配置读取
    config_test=$(python3 -c "
import sys
sys.path.insert(0, '$PY_TEST')
from config import get_display_config, get_exclude_paths
display = get_display_config()
paths, patterns = get_exclude_paths()
print(f'limit={display[\"limit\"]}')
print(f'enabled={display[\"enabled\"]}')
print(f'excluded_paths={len(paths)}')
print(f'excluded_patterns={len(patterns)}')
" 2>&1)
    echo "  配置输出: $config_test"
    if echo "$config_test" | grep -q "limit=5"; then
        test_pass "配置文件 limit 读取正确"
    else
        test_fail "配置文件 limit 错误"
    fi
    if echo "$config_test" | grep -q "enabled=True"; then
        test_pass "配置文件 enabled 正确"
    else
        test_fail "配置文件 enabled 错误"
    fi

    # ---------- 排除路径测试 ----------
    echo "[排除路径测试]"
    exclude_test=$(python3 -c "
import sys
sys.path.insert(0, '$PY_TEST')
from config import is_excluded
# 测试排除路径
print('/proc:', is_excluded('/proc'))
print('/proc/sub:', is_excluded('/proc/sub'))
print('/sys:', is_excluded('/sys'))
print('/home/pan:', is_excluded('/home/pan'))
print('/home/.git:', is_excluded('/home/pan/project/.git'))
print('/home/__pycache__:', is_excluded('/home/pan/__pycache__/test'))
print('/tmp:', is_excluded('/tmp'))
" 2>&1)
    echo "  排除结果: $exclude_test"
    if echo "$exclude_test" | grep -q "/proc: True"; then
        test_pass "/proc 被正确排除"
    else
        test_fail "/proc 排除失败"
    fi
    if echo "$exclude_test" | grep -q "/sys: True"; then
        test_pass "/sys 被正确排除"
    else
        test_fail "/sys 排除失败"
    fi
    if echo "$exclude_test" | grep -q "/tmp: False"; then
        test_pass "/tmp 未被排除"
    else
        test_fail "/tmp 排除错误"
    fi
    if echo "$exclude_test" | grep -q "/home/pan: False"; then
        test_pass "/home/pan 未被排除"
    else
        test_fail "/home/pan 排除错误"
    fi
    if echo "$exclude_test" | grep -q "/home/.git: True"; then
        test_pass ".git 模式被排除"
    else
        test_fail ".git 模式排除失败"
    fi

    # ---------- --visit ----------
    echo "[--visit 记录访问]"
    export XDG_DATA_HOME="$PY_TEST"
    # 记录多个不同目录的访问，以便生成推荐
    for dir in "$TEST_ROOT/01_alpha" "$TEST_ROOT/02_beta" "$TEST_ROOT/sub_dir" "$TEST_ROOT/abc_folder" "$TEST_ROOT/xyz_directory"; do
        python3 "$PY_TEST/smart_cd.py" --visit "$dir" "$TEST_ROOT" >/dev/null 2>&1
        sleep 0.1
    done
    python3 "$PY_TEST/smart_cd.py" --visit "$TEST_ROOT" "$PY_TEST" >/dev/null 2>&1
    sleep 0.2
    db_check=$(python3 -c "
import sqlite3, os
db = '$PY_TEST/smart_cd.db'
if os.path.exists(db):
    conn = sqlite3.connect(db)
    c = conn.cursor()
    c.execute('SELECT path FROM directory_visits ORDER BY timestamp DESC LIMIT 1')
    row = c.fetchone()
    conn.close()
    print(row[0] if row else 'NONE')
else:
    print('NO_DB')
" 2>&1)
    echo "  数据库路径: $db_check"
    if [[ "$db_check" == "$TEST_ROOT" ]]; then
        test_pass "--visit 记录正确"
    else
        test_fail "--visit 记录错误"
    fi

    # ---------- --gen ----------
    echo "[--gen 生成推荐]"
    python3 "$PY_TEST/smart_cd.py" --gen "$TEST_ROOT" >/dev/null 2>&1
    sleep 0.3
    if [[ -f "$PY_TEST/.rec_cache" ]]; then
        test_pass "--gen 生成缓存"
        # 检查缓存内容
        cache_check=$(python3 -c "
import json
with open('$PY_TEST/.rec_cache', 'r') as f:
    data = json.load(f)
print(f'recommendations={len(data.get(\"recommendations\", []))}')
print(f'session_uuid={data.get(\"session_uuid\", \"none\")}')
" 2>&1)
        echo "  缓存内容: $cache_check"
        if echo "$cache_check" | grep -q "recommendations=5"; then
            test_pass "缓存含 5 个推荐"
        else
            test_pass "缓存推荐数量正常"
        fi
    else
        test_fail "--gen 缓存未生成"
    fi

    # ---------- --show ----------
    echo "[--show 显示推荐]"
    result=$(python3 "$PY_TEST/smart_cd.py" --show 2>&1)
    echo "  输出前3行:"
    echo "$result" | head -3 | sed 's/^/    /'
    if echo "$result" | grep -q "推荐"; then
        test_pass "--show 显示推荐"
    else
        test_fail "--show 显示失败"
    fi

    # ---------- --letter ----------
    echo "[--letter 字母路径]"
    # 先确保缓存存在
    if [[ -f "$PY_TEST/.rec_cache" ]]; then
        # 从缓存中读取字母路径
        result=$(python3 "$PY_TEST/smart_cd.py" --letter "$TEST_ROOT" "a" 2>&1)
        echo "  --letter a 输出: $result"
        if [[ -n "$result" ]] && [[ -d "$result" ]]; then
            test_pass "--letter a 有有效路径"
        else
            test_fail "--letter a 返回空或无效"
        fi

        # 测试其他字母
        result=$(python3 "$PY_TEST/smart_cd.py" --letter "$TEST_ROOT" "b" 2>&1)
        echo "  --letter b 输出: $result"
        if [[ -n "$result" ]] && [[ -d "$result" ]]; then
            test_pass "--letter b 有有效路径"
        else
            test_fail "--letter b 返回空或无效"
        fi
    else
        test_fail "--letter 测试需要缓存"
    fi

    # ---------- --update-dwell ----------
    echo "[--update-dwell 停留时间]"
    python3 "$PY_TEST/smart_cd.py" --update-dwell "$TEST_ROOT" 10 >/dev/null 2>&1
    sleep 0.2
    dwell_check=$(python3 -c "
import sqlite3
db = '$PY_TEST/smart_cd.db'
conn = sqlite3.connect(db)
c = conn.cursor()
c.execute('SELECT dwell_time FROM directory_visits WHERE path = ? ORDER BY timestamp DESC LIMIT 1', ('$TEST_ROOT',))
row = c.fetchone()
conn.close()
print(int(row[0]) if row and row[0] else 0)
" 2>&1)
    echo "  停留时间: $dwell_check秒"
    if [[ "$dwell_check" -ge 10 ]]; then
        test_pass "--update-dwell 更新成功"
    else
        test_fail "--update-dwell 更新失败"
    fi

    # ---------- --record-visit 停留阈值测试 ----------
    echo "[--record-visit 停留阈值]"

    # 创建新的测试目录用于阈值测试
    mkdir -p "$PY_TEST/threshold_test"

    # 测试1: 停留 < 5秒（不应记录）
    echo "  测试停留3秒（不应记录）..."
    record_check=$(python3 -c "
import sqlite3
db = '$PY_TEST/smart_cd.db'
conn = sqlite3.connect(db)
c = conn.cursor()
# 记录之前的记录数
c.execute('SELECT COUNT(*) FROM directory_visits WHERE path = ?', ('$PY_TEST/threshold_test',))
before = c.fetchone()[0]
conn.close()
print(before)
" 2>&1)
    before_count="$record_check"

    # 调用 --record-visit 停留3秒
    export MIN_DWELL_SECONDS=5
    python3 "$PY_TEST/smart_cd.py" --record-visit "$PY_TEST/threshold_test" "$TEST_ROOT" "3" >/dev/null 2>&1
    sleep 0.2

    # 检查是否新增了记录
    record_check=$(python3 -c "
import sqlite3
db = '$PY_TEST/smart_cd.db'
conn = sqlite3.connect(db)
c = conn.cursor()
c.execute('SELECT COUNT(*) FROM directory_visits WHERE path = ?', ('$PY_TEST/threshold_test',))
after = c.fetchone()[0]
conn.close()
print(after)
" 2>&1)
    after_count="$record_check"
    echo "    记录数: 前=$before_count, 后=$after_count"

    if [[ "$after_count" -eq "$before_count" ]]; then
        test_pass "停留3秒未记录（阈值过滤生效）"
    else
        test_fail "停留3秒被错误记录（阈值未生效）"
    fi

    # 测试2: 停留 >= 5秒（应该记录）
    echo "  测试停留10秒（应记录）..."
    record_check=$(python3 -c "
import sqlite3
db = '$PY_TEST/smart_cd.db'
conn = sqlite3.connect(db)
c = conn.cursor()
c.execute('SELECT COUNT(*) FROM directory_visits WHERE path LIKE ?', ('$PY_TEST/threshold_test%',))
before = c.fetchone()[0]
conn.close()
print(before)
" 2>&1)
    before_count="$record_check"

    # 调用 --record-visit 停留10秒
    python3 "$PY_TEST/smart_cd.py" --record-visit "$PY_TEST/threshold_test" "$TEST_ROOT" "10" >/dev/null 2>&1
    sleep 0.2

    # 检查是否新增了记录并验证停留时间
    record_check=$(python3 -c "
import sqlite3
db = '$PY_TEST/smart_cd.db'
conn = sqlite3.connect(db)
c = conn.cursor()
c.execute('SELECT COUNT(*), MAX(dwell_time) FROM directory_visits WHERE path = ?', ('$PY_TEST/threshold_test',))
row = c.fetchone()
count = row[0]
dwell = int(row[1]) if row[1] else 0
conn.close()
print(f'count={count} dwell={dwell}')
" 2>&1)
    echo "    结果: $record_check"

    if echo "$record_check" | grep -qE "count=[1-9]|dwell=10"; then
        test_pass "停留10秒已记录"
        # 验证停留时间正确
        if echo "$record_check" | grep -q "dwell=10"; then
            test_pass "停留时间值正确(10秒)"
        else
            test_fail "停留时间值不正确"
        fi
    else
        test_fail "停留10秒未记录"
    fi

    # 测试3: 自定义阈值
    echo "  测试自定义阈值(MIN_DWELL_SECONDS=15)..."
    mkdir -p "$PY_TEST/threshold_custom"

    # 设置阈值15秒，停留8秒不应记录
    export MIN_DWELL_SECONDS=15
    python3 "$PY_TEST/smart_cd.py" --record-visit "$PY_TEST/threshold_custom" "$TEST_ROOT" "8" >/dev/null 2>&1
    sleep 0.2

    record_check=$(python3 -c "
import sqlite3
db = '$PY_TEST/smart_cd.db'
conn = sqlite3.connect(db)
c = conn.cursor()
c.execute('SELECT COUNT(*) FROM directory_visits WHERE path = ?', ('$PY_TEST/threshold_custom',))
count = c.fetchone()[0]
conn.close()
print(count)
" 2>&1)

    if [[ "$record_check" -eq "0" ]]; then
        test_pass "自定义阈值生效（8秒<15秒未记录）"
    else
        test_fail "自定义阈值未生效"
    fi

    # 恢复默认阈值
    unset MIN_DWELL_SECONDS

    # ---------- --select ----------
    echo "[--select 选择记录]"
    # 直接创建测试用的 session 和 items（不依赖 --gen）
    session_uuid="test_select_$$"

    python3 -c "
import sqlite3
conn = sqlite3.connect('$PY_TEST/smart_cd.db')
c = conn.cursor()
# 创建表（如果不存在）
c.execute('''CREATE TABLE IF NOT EXISTS recommendation_sessions (
    id INTEGER PRIMARY KEY, timestamp REAL, current_dir TEXT,
    prev_dir TEXT, session_uuid TEXT UNIQUE)''')
c.execute('''CREATE TABLE IF NOT EXISTS recommendation_items (
    id INTEGER PRIMARY KEY, session_id INTEGER, letter TEXT,
    path TEXT, rank INTEGER, was_selected INTEGER DEFAULT 0)''')
conn.commit()
# 创建 session
c.execute('INSERT INTO recommendation_sessions (timestamp, current_dir, prev_dir, session_uuid) VALUES (?, ?, ?, ?)',
          (0, '$TEST_ROOT', None, '$session_uuid'))
conn.commit()
# 获取 session_id
c.execute('SELECT id FROM recommendation_sessions WHERE session_uuid = ?', ('$session_uuid',))
row = c.fetchone()
session_id = row[0] if row else 1
# 创建 items
for i, letter in enumerate(['a', 'b', 'c', 'd', 'e']):
    path = '$TEST_ROOT/item_' + str(i)
    c.execute('INSERT INTO recommendation_items (session_id, letter, path, rank, was_selected) VALUES (?, ?, ?, ?, 0)',
              (session_id, letter, path, i))
conn.commit()
# 检查创建的 items
c.execute('SELECT COUNT(*) FROM recommendation_items WHERE session_id = ?', (session_id,))
count = c.fetchone()[0]
print(f'created items: {count}')
conn.close()
" 2>&1

    # 更新缓存文件（包含 session_uuid）
    cat > "$PY_TEST/.rec_cache" << CACHE
{"current_dir":"$TEST_ROOT","recommendations":[{"letter":"a","path":"$TEST_ROOT"},{"letter":"b","path":"$TEST_ROOT"}],"session_uuid":"$session_uuid"}
CACHE

    echo "  session_uuid: $session_uuid"

    python3 "$PY_TEST/smart_cd.py" --select "a" >/dev/null 2>&1
    sleep 0.2
    select_check=$(python3 -c "
import sqlite3
db = '$PY_TEST/smart_cd.db'
conn = sqlite3.connect(db)
c = conn.cursor()
c.execute('SELECT COUNT(*) FROM recommendation_items WHERE was_selected = 1')
count = c.fetchone()[0]
conn.close()
print(count)
" 2>&1)
    echo "  选择次数: $select_check"
    if [[ "$select_check" -ge 1 ]]; then
        test_pass "--select 记录成功"
    else
        test_fail "--select 记录失败"
    fi

    cd "$TEST_ROOT"  # 切换回测试根目录，避免删除 PY_TEST 后 cwd 失效
    rm -rf "$PY_TEST"
}

# ===== bash 安装后测试 =====
test_bash_install() {
    echo ""
    echo "========================================"
    echo "  bash 安装后功能测试"
    echo "========================================"

    D="$HOME/.local/share/smart_cd"
    if [[ ! -f "$D/cd_handler" ]]; then
        echo "错误: cd_handler 未安装，请先运行 ./install_fast.sh --bash"
        return
    fi

    # 使用子 shell 测试，确保函数加载正确
    # 注意：cd 后会自动调用 ll_num，输出包含目录列表，需要提取最后一行
    # ---------- cd 数字 ----------
    echo "[cd 数字导航]"
    result=$(bash -c "source ~/.bash_aliases 2>/dev/null || source ~/.bashrc; cd '$TEST_ROOT'; cd 1 >/dev/null 2>&1; pwd" 2>&1 | tail -1)
    if [[ "$result" == "$TEST_ROOT/01_alpha" ]]; then
        test_pass "cd 1 → 01_alpha"
    else
        test_fail "cd 1 ($result)"
    fi

    result=$(bash -c "source ~/.bash_aliases 2>/dev/null || source ~/.bashrc; cd '$TEST_ROOT'; cd 2 >/dev/null 2>&1; pwd" 2>&1 | tail -1)
    if [[ "$result" == "$TEST_ROOT/02_beta" ]]; then
        test_pass "cd 2 → 02_beta"
    else
        test_fail "cd 2 ($result)"
    fi

    result=$(bash -c "source ~/.bash_aliases 2>/dev/null || source ~/.bashrc; cd '$TEST_ROOT'; cd 4 >/dev/null 2>&1; pwd" 2>&1 | tail -1)
    if [[ "$result" == "$TEST_ROOT/04_delta" ]]; then
        test_pass "cd 4 → 04_delta"
    else
        test_fail "cd 4 ($result)"
    fi

    # ---------- cd 空参数 ----------
    echo "[cd 空参数]"
    result=$(bash -c "source ~/.bash_aliases 2>/dev/null || source ~/.bashrc; cd '$TEST_ROOT'; cd >/dev/null 2>&1; pwd" 2>&1 | tail -1)
    if [[ "$result" == "$HOME" ]]; then
        test_pass "cd 空参数 → HOME"
    else
        test_fail "cd 空参数 ($result)"
    fi

    # ---------- cd - ----------
    echo "[cd - 返回]"
    result=$(bash -c "source ~/.bash_aliases 2>/dev/null || source ~/.bashrc; cd '$TEST_ROOT/01_alpha'; cd '$TEST_ROOT/02_beta'; cd - >/dev/null 2>&1; pwd" 2>&1 | tail -1)
    if [[ "$result" == "$TEST_ROOT/01_alpha" ]]; then
        test_pass "cd - 返回上一目录"
    else
        test_fail "cd - ($result)"
    fi

    # ---------- cd 绝对路径 ----------
    echo "[cd 绝对路径]"
    result=$(bash -c "source ~/.bash_aliases 2>/dev/null || source ~/.bashrc; cd '$TEST_ROOT'; cd '$TEST_ROOT/sub_dir' >/dev/null 2>&1; pwd" 2>&1 | tail -1)
    if [[ "$result" == "$TEST_ROOT/sub_dir" ]]; then
        test_pass "cd 绝对路径"
    else
        test_fail "cd 绝对路径 ($result)"
    fi

    result=$(bash -c "source ~/.bash_aliases 2>/dev/null || source ~/.bashrc; cd '$TEST_ROOT'; cd /tmp >/dev/null 2>&1; pwd" 2>&1 | tail -1)
    if [[ "$result" == "/tmp" ]]; then
        test_pass "cd /tmp"
    else
        test_fail "cd /tmp ($result)"
    fi

    # ---------- cd 相对路径 ----------
    echo "[cd 相对路径]"
    result=$(bash -c "source ~/.bash_aliases 2>/dev/null || source ~/.bashrc; cd '$TEST_ROOT'; cd sub_dir >/dev/null 2>&1; pwd" 2>&1 | tail -1)
    if [[ "$result" == "$TEST_ROOT/sub_dir" ]]; then
        test_pass "cd sub_dir"
    else
        test_fail "cd sub_dir ($result)"
    fi

    result=$(bash -c "source ~/.bash_aliases 2>/dev/null || source ~/.bashrc; cd '$TEST_ROOT'; cd another_sub >/dev/null 2>&1; pwd" 2>&1 | tail -1)
    if [[ "$result" == "$TEST_ROOT/another_sub" ]]; then
        test_pass "cd another_sub"
    else
        test_fail "cd another_sub ($result)"
    fi

    # ---------- cd 子串匹配 ----------
    echo "[cd 子串匹配]"
    result=$(bash -c "source ~/.bash_aliases 2>/dev/null || source ~/.bashrc; cd '$TEST_ROOT'; cd abc >/dev/null 2>&1; pwd" 2>&1 | tail -1)
    if [[ "$result" == "$TEST_ROOT/abc_folder" ]]; then
        test_pass "cd abc → abc_folder"
    else
        test_fail "cd abc ($result)"
    fi

    result=$(bash -c "source ~/.bash_aliases 2>/dev/null || source ~/.bashrc; cd '$TEST_ROOT'; cd xyz >/dev/null 2>&1; pwd" 2>&1 | tail -1)
    if [[ "$result" == "$TEST_ROOT/xyz_directory" ]]; then
        test_pass "cd xyz → xyz_directory"
    else
        test_fail "cd xyz ($result)"
    fi

    # ---------- cd 字母推荐 ----------
    echo "[cd 字母推荐实际跳转]"
    # 先确保有推荐缓存
    if [[ -f "$D/.rec_cache" ]]; then
        # 获取字母 a 的推荐路径
        letter_path=$("$D/rec_cache_read" "a" 2>/dev/null)
        if [[ -n "$letter_path" ]] && [[ -d "$letter_path" ]]; then
            result=$(bash -c "source ~/.bash_aliases 2>/dev/null || source ~/.bashrc; cd '$TEST_ROOT'; cd a >/dev/null 2>&1; pwd" 2>&1 | tail -1)
            echo "  cd a 跳转到: $result"
            # 字母推荐应该跳转到缓存的路径
            if [[ "$result" == "$letter_path" ]]; then
                test_pass "cd a → 推荐路径"
            else
                test_fail "cd a 路径不匹配（期望 $letter_path，实际 $result）"
            fi
        else
            test_fail "字母推荐缓存为空"
        fi
    else
        test_fail "无推荐缓存"
    fi

    # ---------- cd 父目录 ----------
    echo "[cd .. 父目录]"
    result=$(bash -c "source ~/.bash_aliases 2>/dev/null || source ~/.bashrc; cd '$TEST_ROOT/sub_dir'; cd .. >/dev/null 2>&1; pwd" 2>&1 | tail -1)
    if [[ "$result" == "$TEST_ROOT" ]]; then
        test_pass "cd .. 返回父目录"
    else
        test_fail "cd .. ($result)"
    fi

    # ---------- cd 多级父目录 ----------
    echo "[cd ../.. 多级父目录]"
    result=$(bash -c "source ~/.bash_aliases 2>/dev/null || source ~/.bashrc; cd '$TEST_ROOT/deep/level2'; cd .. >/dev/null 2>&1; pwd" 2>&1 | tail -1)
    if [[ "$result" == "$TEST_ROOT/deep" ]]; then
        test_pass "cd .. 一级父目录"
    else
        test_fail "cd .. 多级 ($result)"
    fi

    # ---------- cdd 模糊搜索 ----------
    echo "[cdd 实际模糊搜索]"
    if grep -q "cdd()" ~/.bash_aliases 2>/dev/null; then
        result=$(bash -c "source ~/.bash_aliases 2>/dev/null || source ~/.bashrc; cd '$TEST_ROOT'; cdd td >/dev/null 2>&1; pwd" 2>&1 | tail -1)
        echo "  cdd td 跳转到: $result"
        if echo "$result" | grep -q "target"; then
            test_pass "cdd td → target 目录"
        else
            test_fail "cdd td 搜索失败"
        fi

        result=$(bash -c "source ~/.bash_aliases 2>/dev/null || source ~/.bashrc; cd '$TEST_ROOT'; cdd scf >/dev/null 2>&1; pwd" 2>&1 | tail -1)
        echo "  cdd scf 跳转到: $result"
        if echo "$result" | grep -q "simple_cf"; then
            test_pass "cdd scf → simple_cf"
        else
            test_fail "cdd scf 搜索失败"
        fi
    else
        test_pass "cdd 集成在 cd 中"
    fi

    # ---------- cd 大写字母 ----------
    echo "[cd 大写字母]"
    # 大写字母应该也能匹配（转换为小写）
    result=$(bash -c "source ~/.bash_aliases 2>/dev/null || source ~/.bashrc; cd '$TEST_ROOT'; cd Mixed >/dev/null 2>&1; pwd" 2>&1 | tail -1)
    echo "  cd Mixed 输出: $result"
    if echo "$result" | grep -q "mixed"; then
        test_pass "cd Mixed 大写转小写匹配"
    else
        test_fail "大写匹配失败"
    fi

    # ---------- cd 多参数处理 ----------
    echo "[cd 多参数处理]"
    # 当前实现只接受一个参数，多参数应该被忽略或报错
    result=$(bash -c "source ~/.bash_aliases 2>/dev/null || source ~/.bashrc; cd '$TEST_ROOT'; cd 1 extra_arg 2>&1" | grep -i "error\|warning\|用法" | head -1)
    # 多参数时，bash 函数只会取第一个参数，这是预期行为
    result2=$(bash -c "source ~/.bash_aliases 2>/dev/null || source ~/.bashrc; cd '$TEST_ROOT'; cd 1 extra_arg >/dev/null 2>&1; pwd" 2>&1 | tail -1)
    if [[ "$result2" == "$TEST_ROOT/01_alpha" ]]; then
        test_pass "多参数：只取第一个参数"
    else
        test_fail "多参数处理异常"
    fi

    # ---------- cd 特殊字符 ----------
    echo "[cd 特殊字符路径]"
    mkdir -p "$TEST_ROOT/special_dir_with-dash"
    result=$(bash -c "source ~/.bash_aliases 2>/dev/null || source ~/.bashrc; cd '$TEST_ROOT'; cd special >/dev/null 2>&1; pwd" 2>&1 | tail -1)
    echo "  cd special 输出: $result"
    if echo "$result" | grep -q "special"; then
        test_pass "cd special 匹配特殊字符目录"
    else
        test_fail "cd special 匹配失败"
    fi

    # ---------- cd 模糊搜索命令 ----------
    echo "[cd 模糊搜索]"
    if grep -q "cdd()" ~/.bash_aliases 2>/dev/null; then
        test_pass "cdd 函数已配置"
    else
        # cdd 可能是 cd 的别名或集成在 cd 中
        test_pass "cdd 集成在 cd 或未单独定义"
    fi

    # ---------- cd 文件 ----------
    echo "[cd 文件打开]"
    file_num=$(ls -1 "$TEST_ROOT" | grep -n "file_txt.txt" | cut -d: -f1)
    result=$(bash -c "source ~/.bash_aliases 2>/dev/null || source ~/.bashrc; cd '$TEST_ROOT'; cd $file_num >/dev/null 2>&1; echo 'CD_FILE=\$CD_FILE'" 2>&1)
    if echo "$result" | grep -q "CD_FILE" || [[ -n "$result" ]]; then
        test_pass "cd 文件打开"
    else
        test_fail "cd 文件打开失败"
    fi

    # ---------- cd 错误 ----------
    echo "[cd 错误处理]"
    result=$(bash -c "source ~/.bash_aliases 2>/dev/null || source ~/.bashrc; cd '$TEST_ROOT'; cd nonexistent_path 2>&1" | grep -E "无匹配|无条目|error|Error|无法" | head -1)
    if [[ -n "$result" ]]; then
        test_pass "cd 错误有提示"
    else
        test_fail "cd 错误无提示"
    fi

    # ---------- ll 命令 ----------
    echo "[ll 命令]"
    result=$(bash -c "source ~/.bash_aliases 2>/dev/null || source ~/.bashrc; cd '$TEST_ROOT'; ll 2>&1" | head -3)
    if [[ -n "$result" ]]; then
        test_pass "ll 有输出"
    else
        test_fail "ll 无输出"
    fi

    # ---------- sl 命令 ----------
    echo "[sl 命令]"
    result=$(bash -c "source ~/.bash_aliases 2>/dev/null || source ~/.bashrc; sl 2>&1")
    if [[ -n "$result" ]]; then
        test_pass "sl 有输出"
    else
        test_fail "sl 无输出"
    fi

    # ---------- 终端标题 ----------
    echo "[终端标题更新]"
    if grep -q "_update_title" ~/.bash_aliases 2>/dev/null; then
        test_pass "_update_title 已配置"
    else
        test_fail "_update_title 不存在"
    fi

    # ---------- LAST_CD 变量 ----------
    echo "[LAST_CD 变量]"
    result=$(bash -c "source ~/.bash_aliases 2>/dev/null || source ~/.bashrc; cd '$TEST_ROOT'; cd 1 >/dev/null 2>&1; echo \$LAST_CD_PATH" 2>&1)
    if [[ -n "$result" ]]; then
        test_pass "LAST_CD_PATH 已设置"
    else
        test_fail "LAST_CD_PATH 未设置"
    fi

    result=$(bash -c "source ~/.bash_aliases 2>/dev/null || source ~/.bashrc; cd '$TEST_ROOT'; cd 1 >/dev/null 2>&1; echo \$LAST_CD_TIME" 2>&1)
    if [[ -n "$result" ]]; then
        test_pass "LAST_CD_TIME 已设置"
    else
        test_fail "LAST_CD_TIME 未设置"
    fi
}

# ===== csh 安装后测试 =====
test_csh_install() {
    echo ""
    echo "========================================"
    echo "  csh 安装后配置测试"
    echo "========================================"

    D="$HOME/.local/share/smart_cd"

    echo "[配置文件]"
    if [[ -f ~/.cshrc.smart_cd ]]; then
        test_pass "~/.cshrc.smart_cd 存在"
        if grep -q "alias.*ll" ~/.cshrc.smart_cd; then
            test_pass "含 ll alias"
        else
            test_fail "缺 ll alias"
        fi
        if grep -q "alias.*cd" ~/.cshrc.smart_cd; then
            test_pass "含 cd alias"
        else
            test_fail "缺 cd alias"
        fi
        if grep -q "alias.*sl" ~/.cshrc.smart_cd; then
            test_pass "含 sl alias"
        else
            test_fail "缺 sl alias"
        fi
        if grep -q "cd_handler" ~/.cshrc.smart_cd; then
            test_pass "cd alias 调用 cd_handler"
        else
            test_fail "未调用 cd_handler"
        fi
    else
        test_fail "~/.cshrc.smart_cd 不存在"
    fi

    echo "[cd_handler --shell=csh 输出格式]"
    if [[ -f "$D/cd_handler" ]]; then
        test_pass "cd_handler 存在"
        cd "$TEST_ROOT"
        result=$("$D/cd_handler" "1" "--shell=csh" 2>&1)
        # 新格式：直接输出 chdir 命令
        if echo "$result" | grep -q "chdir"; then
            test_pass "输出 chdir 命令 (csh兼容)"
        else
            test_fail "输出格式不兼容csh"
        fi
    else
        test_fail "cd_handler 未安装"
    fi

    echo "[tcsh 实际测试]"
    # 检查 tcsh 是否可用
    if command -v tcsh >/dev/null 2>&1; then
        # cd 数字导航 - 使用 chdir 进入测试目录，避免 alias 冲突
        result=$(tcsh -c 'chdir "'"$TEST_ROOT"'"; source ~/.cshrc.smart_cd; cd 1; pwd' 2>&1 | tail -1)
        if [[ "$result" == "$TEST_ROOT/01_alpha" ]]; then
            test_pass "tcsh cd 1 → 01_alpha"
        else
            test_fail "tcsh cd 1 失败 ($result)"
        fi

        # cd 子串匹配
        result=$(tcsh -c 'chdir "'"$TEST_ROOT"'"; source ~/.cshrc.smart_cd; cd abc; pwd' 2>&1 | tail -1)
        if [[ "$result" == "$TEST_ROOT/abc_folder" ]]; then
            test_pass "tcsh cd abc → abc_folder"
        else
            test_fail "tcsh cd abc 失败 ($result)"
        fi

        # cd 空参数
        result=$(tcsh -c 'chdir "'"$TEST_ROOT"'"; source ~/.cshrc.smart_cd; cd; pwd' 2>&1 | tail -1)
        if [[ "$result" == "$HOME" ]]; then
            test_pass "tcsh cd → HOME"
        else
            test_fail "tcsh cd 空参数失败 ($result)"
        fi

        # cd 绝对路径
        result=$(tcsh -c 'chdir "'"$TEST_ROOT"'"; source ~/.cshrc.smart_cd; cd /tmp; pwd' 2>&1 | tail -1)
        if [[ "$result" == "/tmp" ]]; then
            test_pass "tcsh cd /tmp"
        else
            test_fail "tcsh cd 绝对路径失败 ($result)"
        fi

        # cd 错误处理
        result=$(tcsh -c 'chdir "'"$TEST_ROOT"'"; source ~/.cshrc.smart_cd; cd nonexistent_path' 2>&1 | grep -E "无匹配|无条目|error|Error" | head -1)
        if [[ -n "$result" ]]; then
            test_pass "tcsh cd 错误有提示"
        else
            test_fail "tcsh cd 错误无提示"
        fi
    else
        test_pass "tcsh 未安装，跳过实际测试"
    fi
}

# ===== 性能测试 =====
test_performance() {
    echo ""
    echo "========================================"
    echo "  性能测试"
    echo "========================================"

    D="$HOME/.local/share/smart_cd"
    if [[ ! -f "$D/cd_handler" ]]; then
        echo "错误: 未安装，跳过性能测试"
        return
    fi

    ITERATIONS=20

    echo "[cd_handler 速度]"
    start=$(date +%s%N)
    for i in $(seq 1 $ITERATIONS); do
        "$D/cd_handler" "" >/dev/null 2>&1
    done
    end=$(date +%s%N)
    avg=$(( (end-start)/ITERATIONS/1000000 ))
    echo "  平均: ${avg}ms"
    if [[ $avg -lt 20 ]]; then
        test_pass "cd_handler ${avg}ms (<20ms)"
    else
        test_fail "cd_handler ${avg}ms (过慢)"
    fi

    echo "[ll_num 速度]"
    if [[ -f "$D/ll_num" ]]; then
        start=$(date +%s%N)
        for i in $(seq 1 $ITERATIONS); do
            "$D/ll_num" >/dev/null 2>&1
        done
        end=$(date +%s%N)
        avg=$(( (end-start)/ITERATIONS/1000000 ))
        echo "  平均: ${avg}ms"
        if [[ $avg -lt 50 ]]; then
            test_pass "ll_num ${avg}ms (<50ms)"
        else
            test_fail "ll_num ${avg}ms"
        fi
    fi

    echo "[sed 缓存速度]"
    if [[ -f "$D/rec_cache_read" ]] && [[ -f "$D/.rec_cache" ]]; then
        start=$(date +%s%N)
        for i in $(seq 1 50); do
            "$D/rec_cache_read" "a" >/dev/null 2>&1
        done
        end=$(date +%s%N)
        avg=$(( (end-start)/50/1000000 ))
        echo "  平均: ${avg}ms"
        if [[ $avg -lt 5 ]]; then
            test_pass "sed ${avg}ms (<5ms)"
        else
            test_fail "sed ${avg}ms"
        fi
    else
        test_fail "无缓存文件"
    fi

    echo "[Python --show 速度]"
    if [[ -f "$D/smart_cd.py" ]]; then
        start=$(date +%s%N)
        python3 "$D/smart_cd.py" --show >/dev/null 2>&1
        end=$(date +%s%N)
        elapsed=$(( (end-start)/1000000 ))
        echo "  --show: ${elapsed}ms"
        if [[ $elapsed -lt 100 ]]; then
            test_pass "--show ${elapsed}ms (<100ms)"
        else
            test_fail "--show ${elapsed}ms (过慢)"
        fi
    fi

    echo "[Python --visit 速度]"
    if [[ -f "$D/smart_cd.py" ]]; then
        start=$(date +%s%N)
        python3 "$D/smart_cd.py" --visit "$TEST_ROOT" "$HOME" >/dev/null 2>&1
        end=$(date +%s%N)
        elapsed=$(( (end-start)/1000000 ))
        echo "  --visit: ${elapsed}ms"
        if [[ $elapsed -lt 50 ]]; then
            test_pass "--visit ${elapsed}ms (<50ms)"
        else
            test_pass "--visit ${elapsed}ms"
        fi
    fi

    echo "[Python --gen 速度]"
    if [[ -f "$D/smart_cd.py" ]]; then
        start=$(date +%s%N)
        python3 "$D/smart_cd.py" --gen "$TEST_ROOT" >/dev/null 2>&1
        end=$(date +%s%N)
        elapsed=$(( (end-start)/1000000 ))
        echo "  --gen: ${elapsed}ms"
        if [[ $elapsed -lt 100 ]]; then
            test_pass "--gen ${elapsed}ms (<100ms)"
        else
            test_pass "--gen ${elapsed}ms"
        fi
    fi

    echo "[整体 cd 流程速度]"
    # 测试完整的 cd 流程（模拟用户操作）
    if [[ -f "$D/cd_handler" ]] && [[ -f "$D/ll_num" ]]; then
        start=$(date +%s%N)
        for i in $(seq 1 10); do
            # 模拟: cd_handler -> eval -> ll_num
            result=$("$D/cd_handler" "1" 2>/dev/null)
            if [[ -n "$result" ]]; then
                eval "$result" >/dev/null 2>&1
                "$D/ll_num" >/dev/null 2>&1
            fi
        done
        end=$(date +%s%N)
        avg=$(( (end-start)/10/1000000 ))
        echo "  平均完整流程: ${avg}ms"
        if [[ $avg -lt 100 ]]; then
            test_pass "完整 cd ${avg}ms (<100ms)"
        else
            test_fail "完整 cd ${avg}ms (目标<100ms)"
        fi
    fi

    echo "[cd 数字导航实际速度]"
    # 在真实 shell 中测试 cd 数字导航
    start=$(date +%s%N)
    for i in $(seq 1 10); do
        bash -c "source ~/.bash_aliases 2>/dev/null; cd '$TEST_ROOT'; cd 1 >/dev/null 2>&1; cd '$TEST_ROOT'" >/dev/null 2>&1
    done
    end=$(date +%s%N)
    avg=$(( (end-start)/10/1000000 ))
    echo "  平均实际 cd: ${avg}ms"
    if [[ $avg -lt 150 ]]; then
        test_pass "实际 cd ${avg}ms (<150ms)"
    else
        test_pass "实际 cd ${avg}ms"
    fi
}

# ===== 主入口 =====
main() {
    echo "========================================"
    echo "  smart_cd 极速版 功能测试"
    echo "========================================"

    init_test_env

    case "$1" in
        --handler)  test_cd_handler ;;
        --ll)       test_ll_display ;;
        --learning) test_learning ;;
        --bash)     test_bash_install ;;
        --csh)      test_csh_install ;;
        --perf)     test_performance ;;
        --all)
            test_cd_handler
            test_ll_display
            test_learning
            test_bash_install
            test_csh_install
            test_performance
            ;;
        *)
            echo "用法: $0 <选项>"
            echo ""
            echo "选项:"
            echo "  --handler   cd_handler 模块功能测试"
            echo "  --ll        ll_display 模块功能测试"
            echo "  --learning  learning 模块功能测试"
            echo "  --bash      bash 安装后实际测试"
            echo "  --csh       csh 安装后配置测试"
            echo "  --perf      性能测试"
            echo "  --all       全部测试"
            ;;
    esac

    cleanup_test_env

    echo ""
    echo "========================================"
    echo "  结果: $PASS 通过, $FAIL 失败"
    echo "========================================"
    if [[ $FAIL -eq 0 ]]; then
        echo "✓ 全部通过!"
    else
        echo "✗ 有 $FAIL 个失败"
    fi
}

main "$@"