#!/bin/bash
# smart_cd 安装脚本
# 用法: ./install.sh [--uninstall] [--csh] [--both]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_DIR="$HOME/.local/share/smart_cd"
BIN_DIR="$HOME/.local/bin"
CONFIG_FILE="$HOME/.local/share/smart_cd/config.ini"
CSH_CONFIG="$HOME/.cshrc.smart_cd"

# 默认命令名称
CMD_LL="ll"
CMD_CD="cd"
CMD_CDD="cdd"

# 颜色定义
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[1;36m'; RESET='\033[0m'
print_info() { echo -e "${CYAN}[INFO]${RESET} $1"; }
print_ok() { echo -e "${GREEN}[OK]${RESET} $1"; }
print_warn() { echo -e "${YELLOW}[WARN]${RESET} $1"; }
print_err() { echo -e "${RED}[ERROR]${RESET} $1"; }

# 解析参数
INSTALL_BASH=true; INSTALL_CSH=false; ACTION=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        --uninstall|-u) ACTION="uninstall"; shift ;;
        --csh) INSTALL_CSH=true; INSTALL_BASH=false; shift ;;
        --both) INSTALL_CSH=true; INSTALL_BASH=true; shift ;;
        --help|-h) ACTION="help"; shift ;;
        *) shift ;;
    esac
done

# 交互式配置命令名称
configure_commands() {
    echo -e "\n${CYAN}=== 命令配置 ===${RESET}"
    echo "可自定义命令名称，直接回车使用默认值"
    echo

    read -p "目录列表命令 [$CMD_LL]: " input && CMD_LL="${input:-$CMD_LL}"
    read -p "切换目录命令 [$CMD_CD]: " input && CMD_CD="${input:-$CMD_CD}"
    read -p "模糊搜索命令 [$CMD_CDD]: " input && CMD_CDD="${input:-$CMD_CDD}"

    # 检查命令名是否重复
    if [[ "$CMD_LL" == "$CMD_CD" ]]; then
        print_err "目录列表命令和切换目录命令不能相同!"
        echo "请重新输入"
        CMD_LL="ll"
        CMD_CD="cd"
        configure_commands
        return
    fi
    if [[ "$CMD_LL" == "$CMD_CDD" ]]; then
        print_err "目录列表命令和模糊搜索命令不能相同!"
        echo "请重新输入"
        CMD_LL="ll"
        CMD_CDD="cdd"
        configure_commands
        return
    fi

    # 提示 cd 和 cdd 可以相同
    if [[ "$CMD_CD" == "$CMD_CDD" ]]; then
        echo -e "\n${YELLOW}提示: 切换目录和模糊搜索使用同一命令 '$CMD_CD'${RESET}"
        echo "  - 有参数时: 先尝试 cd 逻辑，失败则尝试模糊搜索"
        echo "  - 无参数时: 回到 home 目录"
    fi

    echo -e "\n${GREEN}命令配置:${RESET}"
    echo "  目录列表: $CMD_LL"
    echo "  切换目录: $CMD_CD"
    echo "  模糊搜索: $CMD_CDD"
    echo

    # 保存配置到文件
    mkdir -p "$INSTALL_DIR"
    cat > "$INSTALL_DIR/.cmd_config" << EOF
CMD_LL="$CMD_LL"
CMD_CD="$CMD_CD"
CMD_CDD="$CMD_CDD"
EOF
}

# 检查依赖
check_dependencies() {
    print_info "检查依赖..."
    if ! command -v python3 &> /dev/null; then print_err "需要 Python 3"; exit 1; fi
    print_ok "Python $(python3 --version 2>&1 | cut -d' ' -f2) 已安装"
}

# 安装
install() {
    print_info "开始安装 smart_cd..."
    mkdir -p "$INSTALL_DIR" "$BIN_DIR"

    # 复制文件 (.txt 后缀文件去掉后缀)
    print_info "复制文件..."
    # Python 模块
    for f in config.py.txt database.py.txt tracker.py.txt scorer.py.txt predictor.py.txt daemon.py.txt display.py.txt fuzzy.py.txt smart_cd.py.txt; do
        base=$(basename "$f" .txt)
        [[ -f "$SCRIPT_DIR/$f" ]] && cp "$SCRIPT_DIR/$f" "$INSTALL_DIR/$base"
    done
    # 脚本文件
    [[ -f "$SCRIPT_DIR/ll_num.txt" ]] && cp "$SCRIPT_DIR/ll_num.txt" "$INSTALL_DIR/ll_num" && chmod +x "$INSTALL_DIR/ll_num"
    [[ -f "$SCRIPT_DIR/smart_cd_wrapper.txt" ]] && cp "$SCRIPT_DIR/smart_cd_wrapper.txt" "$INSTALL_DIR/smart_cd_wrapper" && chmod +x "$INSTALL_DIR/smart_cd_wrapper"
    [[ -f "$SCRIPT_DIR/cdd_wrapper.txt" ]] && cp "$SCRIPT_DIR/cdd_wrapper.txt" "$INSTALL_DIR/cdd_wrapper" && chmod +x "$INSTALL_DIR/cdd_wrapper"

    # 复制配置文件
    if [[ ! -f "$CONFIG_FILE" ]]; then
        [[ -f "$SCRIPT_DIR/config.example.ini.txt" ]] && cp "$SCRIPT_DIR/config.example.ini.txt" "$CONFIG_FILE"
        print_ok "创建配置文件: $CONFIG_FILE"
    else
        print_info "配置文件 $CONFIG_FILE 已存在，保留"
    fi

    # 创建可执行脚本
    print_info "创建可执行脚本..."
    cat > "$BIN_DIR/smart_cd" << 'SCRIPT'
#!/bin/bash
exec python3 "$HOME/.local/share/smart_cd/smart_cd.py" "$@"
SCRIPT
    chmod +x "$BIN_DIR/smart_cd"
    cat > "$BIN_DIR/smart_cd_daemon" << 'SCRIPT'
#!/bin/bash
exec python3 "$HOME/.local/share/smart_cd/smart_cd.py" --daemon "$@"
SCRIPT
    chmod +x "$BIN_DIR/smart_cd_daemon"
    print_ok "可执行脚本已创建"

    # 安装 shell 配置
    [[ "$INSTALL_BASH" == "true" ]] && install_shell_config
    [[ "$INSTALL_CSH" == "true" ]] && install_csh_config

    # 初始化数据库并启动 daemon
    print_info "初始化数据库..."
    python3 "$INSTALL_DIR/smart_cd.py" --init 2>/dev/null
    print_ok "数据库初始化完成"

    print_ok "安装完成!"
    echo
    echo "使用方法:"
    [[ "$INSTALL_BASH" == "true" ]] && echo "  bash: source ~/.bashrc"
    [[ "$INSTALL_CSH" == "true" ]] && echo "  csh:  source ~/.cshrc"
    echo
    echo "命令:"
    echo "  ${CMD_CD} --help   查看帮助"
    echo "  ${CMD_LL}          带编号的目录列表"
    echo "  ${CMD_CDD} <query> 模糊搜索跳转"
    echo "  sl                 显示推荐"
    echo "  sr                 切换推荐显示"
    echo "  so                 切换输出顺序"
    echo "  sc                 切换底部对齐"
    echo
}

# 安装 bash 配置
install_shell_config() {
    print_info "配置 bash..."
    SHELL_RC="$HOME/.bash_aliases"
    [[ ! -f "$SHELL_RC" ]] && SHELL_RC="$HOME/.bashrc"
    [[ ! -f "$SHELL_RC" ]] && touch "$SHELL_RC"

    # 如果已存在配置，询问是否覆盖
    if grep -q "smart_cd" "$SHELL_RC" 2>/dev/null; then
        print_warn "检测到 $SHELL_RC 已存在 smart_cd 配置"
        read -p "是否覆盖原有配置? [Y/n]: " overwrite
        case "${overwrite:-Y}" in
            [Yy]|[Yy][Ee][Ss])
                print_info "正在删除旧配置..."
                sed -i '/^# >>> smart_cd/,/^# <<< smart_cd/d' "$SHELL_RC" 2>/dev/null
                sed -i '/SMART_CD_SCRIPT=/d;/SMART_CD_ENABLED=/d;/SMART_CD_SHOW_RECS=/d;/SMART_CD_BOTTOM_ALIGN=/d;/SMART_CD_RECS_FIRST=/d' "$SHELL_RC" 2>/dev/null
                sed -i '/^__get_editor/,/^}$/d' "$SHELL_RC" 2>/dev/null
                sed -i '/^__bottom_align_print/,/^}$/d' "$SHELL_RC" 2>/dev/null
                sed -i '/^sl()/,/}/d' "$SHELL_RC" 2>/dev/null
                sed -i '/^sr()/,/}/d' "$SHELL_RC" 2>/dev/null
                sed -i '/^sc()/,/}/d' "$SHELL_RC" 2>/dev/null
                sed -i '/^so()/,/}/d' "$SHELL_RC" 2>/dev/null
                sed -i '/^smart_cd_help/,/}/d' "$SHELL_RC" 2>/dev/null
                sed -i '/^ll()/,/^}/d' "$SHELL_RC" 2>/dev/null
                sed -i '/^cd()/,/^}/d' "$SHELL_RC" 2>/dev/null
                sed -i '/^cdd()/,/^}/d' "$SHELL_RC" 2>/dev/null
                sed -i '/^l()/,/^}/d' "$SHELL_RC" 2>/dev/null
                sed -i '/^_cd_smart/,/^}/d' "$SHELL_RC" 2>/dev/null
                sed -i '/complete.*cd/d' "$SHELL_RC" 2>/dev/null
                sed -i '/python3.*smart_cd.*--daemon/d' "$SHELL_RC" 2>/dev/null
                print_ok "旧配置已删除"
                ;;
            *)
                print_warn "跳过 bash 配置"
                return
                ;;
        esac
    fi

    # 使用变量生成配置
    cat >> "$SHELL_RC" << SHELL_CONFIG

# >>> smart_cd - 智能目录导航 >>>
SMART_CD_SCRIPT="$HOME/.local/share/smart_cd/smart_cd.py"
SMART_CD_ENABLED=1; SMART_CD_SHOW_RECS=1; SMART_CD_BOTTOM_ALIGN=0; SMART_CD_RECS_FIRST=0
__smart_cd_editor=""

__get_editor() {
    [[ -n "\$__smart_cd_editor" ]] && { echo "\$__smart_cd_editor"; return; }
    __smart_cd_editor=\$(python3 -c "
import sys; sys.path.insert(0, '$HOME/.local/share/smart_cd')
try: from config import get_editor_command; print(get_editor_command())
except: print('\${EDITOR:-gvim}')
" 2>/dev/null) || __smart_cd_editor="\${EDITOR:-gvim}"
    echo "\$__smart_cd_editor"
}

__bottom_align_print() {
    local lines=\$(echo "\$1" | wc -l) term_height=\$(tput lines 2>/dev/null || echo 24)
    local start_row=\$((term_height - lines)); [[ \$start_row -lt 1 ]] && start_row=1
    printf '\033[2J\033[%d;1H' "\$start_row"; echo "\$1"
}

sl() { local o=\$(python3 "\$SMART_CD_SCRIPT" --ll 2>/dev/null); [[ "\$SMART_CD_BOTTOM_ALIGN" -eq 1 ]] && __bottom_align_print "\$o" || echo "\$o"; }
sr() { [[ "\$SMART_CD_SHOW_RECS" -eq 1 ]] && { SMART_CD_SHOW_RECS=0; echo "推荐已关闭"; } || { SMART_CD_SHOW_RECS=1; echo "推荐已开启"; }; }
sc() { [[ "\$SMART_CD_BOTTOM_ALIGN" -eq 1 ]] && { SMART_CD_BOTTOM_ALIGN=0; echo "底部对齐已关闭"; } || { SMART_CD_BOTTOM_ALIGN=1; echo "底部对齐已开启"; }; }
so() { [[ "\$SMART_CD_RECS_FIRST" -eq 1 ]] && { SMART_CD_RECS_FIRST=0; echo "顺序: 目录先"; } || { SMART_CD_RECS_FIRST=1; echo "顺序: 推荐先"; }; }
smart_cd_help() { python3 "\$SMART_CD_SCRIPT" --help; }
SHELL_CONFIG

    # 添加 cdd 函数（如果 cd 和 cdd 不同）
    if [[ "$CMD_CD" != "$CMD_CDD" ]]; then
        cat >> "$SHELL_RC" << SHELL_CONFIG

${CMD_CDD}() {
    [[ -z "\$1" ]] && { echo "Usage: ${CMD_CDD} <query>"; return 1; }
    local p="\$PWD" t=\$(python3 "\$SMART_CD_SCRIPT" --cdd "\$1" 2>/dev/null)
    [[ -z "\$t" || "\$t" == "${CMD_CDD}:"* ]] && { echo "\$t"; return 1; }
    [[ -d "\$t" ]] && { builtin cd "\$t"; python3 "\$SMART_CD_SCRIPT" --record "\$PWD" --prev "\$p"; ${CMD_LL}; } || echo "${CMD_CDD}: Not a directory '\$t'"
}
SHELL_CONFIG
    fi

    # 添加 ll 函数
    cat >> "$SHELL_RC" << SHELL_CONFIG

${CMD_LL}() {
    local ll_o=\$("$HOME/.local/share/smart_cd/ll_num" "\$@")
    if [[ "\$SMART_CD_ENABLED" -eq 1 ]] && [[ "\$SMART_CD_SHOW_RECS" -eq 1 ]] && [[ -f "\$SMART_CD_SCRIPT" ]]; then
        local recs=\$(python3 "\$SMART_CD_SCRIPT" --ll 2>/dev/null)
        if [[ "\$SMART_CD_BOTTOM_ALIGN" -eq 1 ]]; then
            [[ "\$SMART_CD_RECS_FIRST" -eq 1 ]] && __bottom_align_print "\$recs"\$'\n'"\$ll_o" || __bottom_align_print "\$ll_o"\$'\n'"\$recs"
        else
            [[ "\$SMART_CD_RECS_FIRST" -eq 1 ]] && { echo "\$recs"; echo "\$ll_o"; } || { echo "\$ll_o"; echo "\$recs"; }
        fi
    else echo "\$ll_o"; fi
}
SHELL_CONFIG

    # 添加 cd 函数
    if [[ "$CMD_CD" == "$CMD_CDD" ]]; then
        # cd 和 cdd 相同：优先 cd 逻辑，失败后尝试模糊搜索
        cat >> "$SHELL_RC" << SHELL_CONFIG

${CMD_CD}() {
    local p="\$PWD"
    [[ "\$1" == "--help" || "\$1" == "-h" ]] && { smart_cd_help; return; }
    if [[ "\$1" =~ ^[a-z]\$ ]] && [[ "\$SMART_CD_ENABLED" -eq 1 ]] && [[ -f "\$SMART_CD_SCRIPT" ]]; then
        local t=\$(python3 "\$SMART_CD_SCRIPT" --get "\$1" 2>/dev/null)
        [[ -n "\$t" && -d "\$t" ]] && { builtin cd "\$t"; python3 "\$SMART_CD_SCRIPT" --record "\$PWD" --prev "\$p"; ${CMD_LL}; return; } || { echo "${CMD_CD}: 无推荐 '\$1'"; return 1; }
    fi
    if [[ "\$1" =~ ^[0-9]+\$ ]]; then
        local t=\$(ls -1 2>/dev/null | awk -v n="\$1" 'NR==n{print;exit}')
        [[ -z "\$t" ]] && { echo "${CMD_CD}: 无条目 #\$1"; return 1; }
        if [[ -d "\$t" ]]; then
            builtin cd "\$t"; python3 "\$SMART_CD_SCRIPT" --record "\$PWD" --prev "\$p"; ${CMD_LL}
        elif [[ -f "\$t" ]]; then
            \$(__get_editor) "\$t" >/dev/null 2>&1 &
        fi
        return
    fi
    if [[ "\$1" == "-" ]]; then
        [[ -n "\$OLDPWD" ]] && { builtin cd -; python3 "\$SMART_CD_SCRIPT" --record "\$PWD" --prev "\$p"; ${CMD_LL}; } || echo "${CMD_CD}: 无上一次目录"
        return
    fi
    [[ -z "\$1" ]] && { builtin cd; python3 "\$SMART_CD_SCRIPT" --record "\$PWD" --prev "\$p"; ${CMD_LL}; return; }
    [[ -f "\$1" ]] && { \$(__get_editor) "\$1" >/dev/null 2>&1 & } && return
    [[ -d "\$1" ]] && { builtin cd "\$@"; python3 "\$SMART_CD_SCRIPT" --record "\$PWD" --prev "\$p"; ${CMD_LL}; return; }
    local m=\$(ls -1 2>/dev/null | grep -Fi "\$1" | awk '{print length,\$0}' | sort -n | head -1 | cut -d' ' -f2-)
    if [[ -n "\$m" ]]; then
        if [[ -d "\$m" ]]; then
            builtin cd "\$m"; python3 "\$SMART_CD_SCRIPT" --record "\$PWD" --prev "\$p"; ${CMD_LL}
        elif [[ -f "\$m" ]]; then
            \$(__get_editor) "\$m" >/dev/null 2>&1 &
        fi
    else
        # 尝试模糊搜索
        local t=\$(python3 "\$SMART_CD_SCRIPT" --cdd "\$1" 2>/dev/null)
        [[ -n "\$t" && -d "\$t" ]] && { builtin cd "\$t"; python3 "\$SMART_CD_SCRIPT" --record "\$PWD" --prev "\$p"; ${CMD_LL}; return; } || echo "${CMD_CD}: 无匹配 '\$1'"
    fi
}
SHELL_CONFIG
    else
        # cd 和 cdd 不同：标准 cd 逻辑
        cat >> "$SHELL_RC" << SHELL_CONFIG

${CMD_CD}() {
    local p="\$PWD"
    [[ "\$1" == "--help" || "\$1" == "-h" ]] && { smart_cd_help; return; }
    if [[ "\$1" =~ ^[a-z]\$ ]] && [[ "\$SMART_CD_ENABLED" -eq 1 ]] && [[ -f "\$SMART_CD_SCRIPT" ]]; then
        local t=\$(python3 "\$SMART_CD_SCRIPT" --get "\$1" 2>/dev/null)
        [[ -n "\$t" && -d "\$t" ]] && { builtin cd "\$t"; python3 "\$SMART_CD_SCRIPT" --record "\$PWD" --prev "\$p"; ${CMD_LL}; return; } || { echo "${CMD_CD}: 无推荐 '\$1'"; return 1; }
    fi
    if [[ "\$1" =~ ^[0-9]+\$ ]]; then
        local t=\$(ls -1 2>/dev/null | awk -v n="\$1" 'NR==n{print;exit}')
        [[ -z "\$t" ]] && { echo "${CMD_CD}: 无条目 #\$1"; return 1; }
        if [[ -d "\$t" ]]; then
            builtin cd "\$t"; python3 "\$SMART_CD_SCRIPT" --record "\$PWD" --prev "\$p"; ${CMD_LL}
        elif [[ -f "\$t" ]]; then
            \$(__get_editor) "\$t" >/dev/null 2>&1 &
        fi
        return
    fi
    if [[ "\$1" == "-" ]]; then
        [[ -n "\$OLDPWD" ]] && { builtin cd -; python3 "\$SMART_CD_SCRIPT" --record "\$PWD" --prev "\$p"; ${CMD_LL}; } || echo "${CMD_CD}: 无上一次目录"
        return
    fi
    [[ -z "\$1" ]] && { builtin cd; python3 "\$SMART_CD_SCRIPT" --record "\$PWD" --prev "\$p"; ${CMD_LL}; return; }
    [[ -f "\$1" ]] && { \$(__get_editor) "\$1" >/dev/null 2>&1 & } && return
    [[ -d "\$1" ]] && { builtin cd "\$@"; python3 "\$SMART_CD_SCRIPT" --record "\$PWD" --prev "\$p"; ${CMD_LL}; return; }
    local m=\$(ls -1 2>/dev/null | grep -Fi "\$1" | awk '{print length,\$0}' | sort -n | head -1 | cut -d' ' -f2-)
    if [[ -n "\$m" ]]; then
        if [[ -d "\$m" ]]; then
            builtin cd "\$m"; python3 "\$SMART_CD_SCRIPT" --record "\$PWD" --prev "\$p"; ${CMD_LL}
        elif [[ -f "\$m" ]]; then
            \$(__get_editor) "\$m" >/dev/null 2>&1 &
        fi
    else
        echo "${CMD_CD}: 无匹配 '\$1'"
    fi
}
SHELL_CONFIG
    fi

    # 添加完成和启动
    cat >> "$SHELL_RC" << SHELL_CONFIG

python3 "\$SMART_CD_SCRIPT" --daemon status 2>/dev/null | grep -q "not running" && python3 "\$SMART_CD_SCRIPT" --daemon start >/dev/null 2>&1

_cd_smart() { local c="\${COMP_WORDS[COMP_CWORD]}"; [[ "\$c" =~ ^[a-z]?\$ ]] && COMPREPLY=(\$(compgen -W "a b c d e" -- "\$c")) || COMPREPLY=(\$(compgen -f -- "\$c")); }
complete -o nospace -F _cd_smart ${CMD_CD}
# <<< smart_cd - 智能目录导航 <<<
SHELL_CONFIG

    print_ok "bash 配置已添加到 $SHELL_RC"
    [[ "$SHELL_RC" == "$HOME/.bash_aliases" && ! -f "$HOME/.bashrc" ]] && touch "$HOME/.bashrc"
    grep -q "$BIN_DIR" "$HOME/.bashrc" 2>/dev/null || echo "export PATH=\"$BIN_DIR:\$PATH\"" >> "$HOME/.bashrc"
}

# 安装 csh 配置
install_csh_config() {
    print_info "配置 csh..."

    # 生成配置文件
    cat > "$CSH_CONFIG" << CSH_CONFIG
# smart_cd - 智能目录导航 (C Shell 版本)
# 用法: 把此文件内容直接添加到 ~/.cshrc 末尾
#
# 使用方式:
#   ${CMD_CD} a        -> cd 到推荐目录 a + ${CMD_LL} + 智能推荐
#   ${CMD_CD} 1        -> cd 到当前目录第1个条目 + ${CMD_LL}
#   ${CMD_CD} psc      -> 模糊匹配 + ${CMD_LL} + 智能推荐
#   ${CMD_CD} -        -> 返回上一次目录 + ${CMD_LL} + 智能推荐
#   ${CMD_CD}          -> cd 到 home + ${CMD_LL} + 智能推荐
#   ${CMD_CDD} query   -> 模糊搜索目录并跳转
#   ${CMD_LL}          -> 带编号和颜色的目录列表
#   sl                 -> 显示推荐列表
#   sr                 -> 切换推荐显示
#   so                 -> 切换输出顺序 (目录先/推荐先)
#   sc                 -> 切换底部对齐输出

setenv SMART_CD_SCRIPT "\$HOME/.local/share/smart_cd/smart_cd.py"
setenv SMART_CD_ENABLED 1
setenv SMART_CD_SHOW_RECS 1
setenv SMART_CD_BOTTOM_ALIGN 0
setenv SMART_CD_RECS_FIRST 0

# 设置 prompt 显示完整路径（%~ 显示相对 home 的路径）
if (\$?prompt) then
    set prompt = "[%n@%m %~]%# "
endif

# ${CMD_LL} - 带编号和颜色的目录列表
alias ${CMD_LL} '~/.local/share/smart_cd/ll_num \\!*'

# 基本命令
alias sl 'python3 \$SMART_CD_SCRIPT --ll'

# 切换函数 - csh 版本 (使用 Python --toggle)
alias sr 'setenv SMART_CD_SHOW_RECS \`python3 \$SMART_CD_SCRIPT --toggle SMART_CD_SHOW_RECS\`; echo "推荐: \$SMART_CD_SHOW_RECS"'
alias sc 'setenv SMART_CD_BOTTOM_ALIGN \`python3 \$SMART_CD_SCRIPT --toggle SMART_CD_BOTTOM_ALIGN\`; echo "底部对齐: \$SMART_CD_BOTTOM_ALIGN"'
alias so 'setenv SMART_CD_RECS_FIRST \`python3 \$SMART_CD_SCRIPT --toggle SMART_CD_RECS_FIRST\`; echo "顺序: \$SMART_CD_RECS_FIRST (0=目录先 1=推荐先)"'
alias smart_cd_help 'python3 \$SMART_CD_SCRIPT --help'

# ${CMD_CD} 增强 - 使用 eval 执行 wrapper 输出
alias ${CMD_CD} 'eval \`~/.local/share/smart_cd/smart_cd_wrapper "\\!*"\`'
CSH_CONFIG

    # 如果 cd 和 cdd 不同，添加单独的 cdd 命令
    if [[ "$CMD_CD" != "$CMD_CDD" ]]; then
        cat >> "$CSH_CONFIG" << CSH_CONFIG

# ${CMD_CDD} - 模糊搜索目录跳转
alias ${CMD_CDD} 'eval \`~/.local/share/smart_cd/cdd_wrapper "\\!*"\`'
CSH_CONFIG
    fi

    cat >> "$CSH_CONFIG" << CSH_CONFIG

# daemon (已合并到 smart_cd.py)
python3 \$SMART_CD_SCRIPT --daemon status | grep -q "not running" && python3 \$SMART_CD_SCRIPT --daemon start > /dev/null

echo "smart_cd 已加载: ${CMD_CD}, ${CMD_LL}, sl, sr, so, sc"
CSH_CONFIG

    # 如果已存在配置文件，询问是否覆盖
    if [[ -f "$CSH_CONFIG" ]]; then
        print_warn "检测到已存在 csh 配置文件"
        read -p "是否覆盖原有配置? [Y/n]: " overwrite
        case "${overwrite:-Y}" in
            [Yy]|[Yy][Ee][Ss])
                print_ok "覆盖 csh 配置: $CSH_CONFIG"
                ;;
            *)
                print_warn "跳过 csh 配置"
                return
                ;;
        esac
    else
        print_ok "创建 csh 配置: $CSH_CONFIG"
    fi

    # 检查 .cshrc 是否已有 source 行，没有则添加
    if [[ -f "$HOME/.cshrc" ]] && ! grep -q "cshrc.smart_cd" "$HOME/.cshrc" 2>/dev/null; then
        echo '' >> "$HOME/.cshrc"
        echo 'if (-f ~/.cshrc.smart_cd) source ~/.cshrc.smart_cd' >> "$HOME/.cshrc"
        print_ok "添加到 .cshrc"
    fi
}

# 卸载
uninstall() {
    print_info "开始卸载..."
    python3 "$INSTALL_DIR/smart_cd.py" --daemon stop 2>/dev/null || true
    rm -f "$INSTALL_DIR/smart_cd.py" "$INSTALL_DIR/ll_num" "$INSTALL_DIR/smart_cd_wrapper" "$BIN_DIR/smart_cd" "$BIN_DIR/smart_cd_daemon"
    print_ok "文件已删除"
    [[ -f "$HOME/.bash_aliases" ]] && sed -i '/smart_cd/,/^complete.*cd$/d;/SMART_CD_/d' "$HOME/.bash_aliases" 2>/dev/null && print_ok "已从 .bash_aliases 移除"
    [[ -f "$HOME/.bashrc" ]] && sed -i '/smart_cd/,/^complete.*cd$/d;/SMART_CD_/d' "$HOME/.bashrc" 2>/dev/null && print_ok "已从 .bashrc 移除"
    [[ -f "$CSH_CONFIG" ]] && rm -f "$CSH_CONFIG" && print_ok "已删除 csh 配置"
    [[ -f "$HOME/.cshrc" ]] && sed -i '/cshrc.smart_cd/d' "$HOME/.cshrc" 2>/dev/null && print_ok "已从 .cshrc 移除"
    print_ok "卸载完成"; echo "请运行: source ~/.bashrc 或 source ~/.cshrc"
}

# 交互式选择安装目标
select_install_target() {
    echo -e "\n${CYAN}=== 安装目标 ===${RESET}"
    echo "请选择要安装的 shell:"
    echo "  1) bash"
    echo "  2) csh"
    echo "  3) both (bash + csh)"
    echo
    read -p "请选择 [1-3, 默认 1]: " choice
    case "${choice:-1}" in
        1) INSTALL_BASH=true; INSTALL_CSH=false; print_info "选择: bash";;
        2) INSTALL_BASH=false; INSTALL_CSH=true; print_info "选择: csh";;
        3) INSTALL_BASH=true; INSTALL_CSH=true; print_info "选择: both (bash + csh)";;
        *) INSTALL_BASH=true; INSTALL_CSH=false; print_info "默认: bash";;
    esac
}

# 主逻辑
[[ "$ACTION" == "help" ]] && { echo "用法: $0 [--uninstall] [--csh] [--both] [--help]"; exit 0; }
[[ "$ACTION" == "uninstall" ]] && { uninstall; exit 0; }
check_dependencies
select_install_target
configure_commands
install