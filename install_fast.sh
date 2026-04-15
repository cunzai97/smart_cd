#!/bin/bash
# smart_cd 极速版安装脚本
# 用法: ./install_fast.sh [--uninstall] [--bash] [--csh] [--both] [--clean-db]

set -e
D="$HOME/.local/share/smart_cd"
C='\033[1;36m'; G='\033[0;32m'; Y='\033[1;33m'; R='\033[0m'
info(){ echo -e "${C}[INFO]${R} $1"; }
ok(){ echo -e "${G}[OK]${R} $1"; }
warn(){ echo -e "${Y}[WARN]${R} $1"; }

CMD_LL="l"; CMD_CD="cd"; CMD_FUZZY="cdd"; CMD_SL="sl"
SEARCH_DEPTH=5
REC_LIMIT=26
REC_COLOR="yellow"
A=""; B=false; S=false; ASK_SHELL=false; SKIP_CFG=false; FORCE=false
for x in "$@"; do
    case "$x" in
        --uninstall|-u) A="uninstall" ;;
        --bash) B=true ;;
        --csh) S=true ;;
        --both) B=true; S=true ;;
        --skip-cfg|-s) SKIP_CFG=true ;;
        --force|-f) FORCE=true ;;
    esac
done
[[ "$B" == "false" && "$S" == "false" ]] && ASK_SHELL=true

# 配置命令
cfg(){
    mkdir -p "$D"

    # 如果跳过配置，直接读取并返回
    if [[ "$SKIP_CFG" == "true" ]]; then
        if [[ -f "$D/.cmd_config" ]]; then
            source "$D/.cmd_config"
        fi
        echo -e "\n${G}命令:${R} $CMD_LL $CMD_CD $CMD_SL"
        [[ "$CMD_CD" != "$CMD_FUZZY" ]] && echo -e "      $CMD_FUZZY(模糊)"
        if [ "$SEARCH_DEPTH" -gt 0 ] 2>/dev/null; then
            echo -e "${G}分层搜索:${R} 深度=$SEARCH_DEPTH"
        else
            echo -e "${G}搜索范围:${R} 当前目录"
        fi
        echo -e "${G}智能推荐:${R} 显示$REC_LIMIT行"
        return
    fi

    # 有已保存配置时，询问是否修改
    if [[ -f "$D/.cmd_config" ]]; then
        source "$D/.cmd_config"
        echo -e "\n${G}当前配置:${R} $CMD_LL $CMD_CD $CMD_SL"
        [[ "$CMD_CD" != "$CMD_FUZZY" ]] && echo -e "      $CMD_FUZZY(模糊)"
        echo -e "${G}分层搜索:${R} 深度=$SEARCH_DEPTH"
        echo -e "${G}智能推荐:${R} 显示$REC_LIMIT行"
        read -p "修改配置? [y/N]: " i
        [[ "$i" =~ ^[Nn]$ ]] || [[ -z "$i" ]] && return
    fi

    echo -e "\n${C}=== 命令配置 ===${R}"
    read -p "目录列表 [$CMD_LL]: " i; CMD_LL="${i:-$CMD_LL}"
    read -p "切换目录 [$CMD_CD]: " i; CMD_CD="${i:-$CMD_CD}"
    read -p "模糊搜索 [$CMD_FUZZY] (=$CMD_CD集成): " i; CMD_FUZZY="${i:-$CMD_FUZZY}"
    read -p "显示推荐 [$CMD_SL]: " i; CMD_SL="${i:-$CMD_SL}"
    [[ "$CMD_LL" == "$CMD_CD" ]] && { warn "ll≠cd"; CMD_LL="ll"; CMD_CD="cd"; cfg; return; }

    echo -e "\n${C}=== 搜索配置 ===${R}"
    read -p "搜索深度 [$SEARCH_DEPTH] (0=当前目录): " i; SEARCH_DEPTH="${i:-$SEARCH_DEPTH}"

    echo -e "\n${C}=== 推荐配置 ===${R}"
    read -p "显示行数 [$REC_LIMIT]: " i; REC_LIMIT="${i:-$REC_LIMIT}"
    read -p "字母颜色 [$REC_COLOR] (yellow/red/green/cyan): " i; REC_COLOR="${i:-$REC_COLOR}"

    echo "CMD_LL=\"$CMD_LL\"; CMD_CD=\"$CMD_CD\"; CMD_FUZZY=\"$CMD_FUZZY\"; CMD_SL=\"$CMD_SL\"; SEARCH_DEPTH=\"$SEARCH_DEPTH\"; REC_LIMIT=\"$REC_LIMIT\"; REC_COLOR=\"$REC_COLOR\"" > "$D/.cmd_config"
    echo -e "\n${G}命令:${R} $CMD_LL $CMD_CD $CMD_SL"
    [[ "$CMD_CD" != "$CMD_FUZZY" ]] && echo -e "      $CMD_FUZZY(模糊)"
    echo -e "${G}分层搜索:${R} 深度=$SEARCH_DEPTH"
    echo -e "${G}智能推荐:${R} 显示$REC_LIMIT行, 颜色=$REC_COLOR"
}

# 安装 Python 模块
mk_python(){
    info "安装 Python 模块..."
    SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

    PY_SRC="$SCRIPT_DIR/learning"
    if [[ ! -d "$PY_SRC" ]]; then
        PY_SRC="$SCRIPT_DIR/python_modules"
    fi

    if [[ -d "$PY_SRC" ]]; then
        for f in "$PY_SRC"/*.txt; do
            if [[ -f "$f" ]]; then
                base=$(basename "$f" .txt)
                cp "$f" "$D/${base}"
            fi
        done
        ok "Python 模块"
    else
        warn "未找到 learning/python_modules 目录，跳过"
    fi
}

# 安装 cd_handler 模块
mk_cd_handler(){
    info "安装 cd_handler..."
    SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
    HANDLER_SRC="$SCRIPT_DIR/cd_handler"

    if [[ -f "$HANDLER_SRC/cd_handler.sh.txt" ]]; then
        cp "$HANDLER_SRC/cd_handler.sh.txt" "$D/cd_handler"
        sed -i "s|__DIR__|$D|g; s|__DEPTH__|$SEARCH_DEPTH|g" "$D/cd_handler"
        chmod +x "$D/cd_handler"
        ok "cd_handler"
    else
        warn "未找到 cd_handler.sh.txt"
    fi
}

# 安装 ll_display 模块
mk_ll_display(){
    info "安装 ll_display..."
    SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
    DISPLAY_SRC="$SCRIPT_DIR/ll_display"

    if [[ -f "$DISPLAY_SRC/ll_display.sh.txt" ]]; then
        cp "$DISPLAY_SRC/ll_display.sh.txt" "$D/ll_display"
        sed -i "s|__DIR__|$D|g" "$D/ll_display"
        chmod +x "$D/ll_display"
        ok "ll_display"
    else
        ln -sf "$D/ll_num" "$D/ll_display"
        ok "ll_display (使用 ll_num)"
    fi
}

# 创建推荐配置文件
mk_config(){
    if [[ -f "$D/config.ini" ]]; then
        info "配置文件已存在，保留用户配置"
        return
    fi

    cat > "$D/config.ini" << INI
# Smart CD 极速版 - 智能推荐配置文件

[display]
recommendation_limit = $REC_LIMIT
letter_format = [a]
letter_color = $REC_COLOR
path_color = cyan
show_stats = true

[exclude]
paths = /tmp, /var
patterns = __pycache__, .git, .cache
INI
    ok "推荐配置"
}

# 安装 ll_display 模块
mk_ll(){
    info "安装 ll_display..."
    SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
    DISPLAY_SRC="$SCRIPT_DIR/ll_display"

    if [[ -f "$DISPLAY_SRC/ll_display.sh.txt" ]]; then
        cp "$DISPLAY_SRC/ll_display.sh.txt" "$D/ll_num"
        chmod +x "$D/ll_num"
        ok "ll_display"
    else
        warn "未找到 ll_display.sh.txt，使用内联"
        cat > "$D/ll_num" << 'X'
#!/bin/bash
# ll_num - 带编号的目录列表

o=$(command ls -l "$@" 2>/dev/null)
c=$(echo "$o"|awk 'NR>1&&NF>0')
[[ -z "$c" ]]&&{ echo "(空)";exit 0;}

echo "$o"|awk 'NR==1{next}{i=NR-1;p[i]=$1;l[i]=$2;u[i]=$3;g[i]=$4;s[i]=$5;m[i]=$6;d[i]=$7;t[i]=$8;f="";for(j=9;j<=NF;j++){if(j>9)f=f" ";f=f$j}n[i]=f;mp=(length($1)>mp)?length($1):mp;ml=(length($2)>ml)?length($2):ml;mu=(length($3)>mu)?length($3):mu;mg=(length($4)>mg)?length($4):mg;ms=(length($5)>ms)?length($5):ms;mm=(length($6)>mm)?length($6):mm;T=i}END{for(i=1;i<=T;i++){tp=substr(p[i],1,1);pp=p[i];if(tp=="d")cl="\033[1;34m";else if(pp~/x/)cl="\033[0;32m";else cl="\033[0;90m";printf "%-"mp"s %"ml"s %-"mu"s %-"mg"s %"ms"s %-"mm"s %2s %5s  \033[1;36m[%d]\033[0m %s%s\033[0m\n",p[i],l[i],u[i],g[i],s[i],m[i],d[i],t[i],i,cl,n[i]}}'
X
        chmod +x "$D/ll_num"
        ok "ll_num (内联)"
    fi
}

# 安装 cd_hook 模块
mk_cd_hook(){
    info "安装 cd_hook..."
    SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
    HOOK_SRC="$SCRIPT_DIR/cd_hook"

    if [[ -f "$HOOK_SRC/cd_hook.sh.txt" ]]; then
        cp "$HOOK_SRC/cd_hook.sh.txt" "$D/cd_hook"
        sed -i "s|__SMART_CD_PY__|$D/smart_cd.py|g" "$D/cd_hook"
        chmod +x "$D/cd_hook"
        ok "cd_hook"
    else
        warn "未找到 cd_hook.sh.txt"
    fi
}

# 安装 sl 和 rec_cache_read（内联生成）
mk_sl(){
    info "安装 sl 和 rec_cache_read..."

    # sl - 显示智能推荐
    cat > "$D/sl" << 'SLSCRIPT'
#!/bin/bash
# sl - 显示智能推荐
if [[ "$1" == "--all" ]]; then
    python3 "__SMART_CD_PY__" --show
    python3 "__SMART_CD_PY__" --status
else
    python3 "__SMART_CD_PY__" --show
fi
SLSCRIPT
    sed -i "s|__SMART_CD_PY__|$D/smart_cd.py|g" "$D/sl"
    chmod +x "$D/sl"
    ok "sl"

    # rec_cache_read - 快速缓存读取（sed解析，无外部依赖）
    cat > "$D/rec_cache_read" << 'CACHESCRIPT'
#!/bin/bash
# rec_cache_read - 快速缓存读取
letter="$1"
cache_file="__CACHE_FILE__"
[[ ! -f "$cache_file" ]] && exit 0
sed 's/.*{"letter": "'$letter'", "path": "\([^"]*\)".*/\1/' "$cache_file" 2>/dev/null | head -1
CACHESCRIPT
    sed -i "s|__CACHE_FILE__|$D/.rec_cache|g" "$D/rec_cache_read"
    chmod +x "$D/rec_cache_read"
    ok "rec_cache_read"
}

# 安装 bash
inst_bash(){
    info "配置 bash..."
    R="$HOME/.bash_aliases"
    [[ ! -f "$R" ]]&&R="$HOME/.bashrc"
    if grep -q "^# >>> smart_cd" "$R"; then
        warn "已有配置"
        if [[ "$FORCE" == "true" ]]; then
            sed -i '/^# >>> smart_cd/,/^# <<< smart_cd/d' "$R"
        else
            read -p "覆盖?[Y/n]:" y
            [[ "${y:-Y}"=~[Yy] ]]&&sed -i '/^# >>> smart_cd/,/^# <<< smart_cd/d' "$R"||return
        fi
    fi

    echo "" >> "$R"
    echo "# >>> smart_cd - 极速版 >>>" >> "$R"
    echo "" >> "$R"
    echo "export SMART_CD_SESSION=\$(date +%s)_\$\$" >> "$R"
    echo "export D=\"$D\"" >> "$R"
    echo "export LAST_CD_PATH=\"\" LAST_CD_TIME=\"\"" >> "$R"
    echo "" >> "$R"

    # 终端标题更新函数
    echo '# 终端标题更新' >> "$R"
    echo '_update_title(){ printf "\\033]0;%s\\007" "${PWD/#\$HOME/~}"; }' >> "$R"
    echo "" >> "$R"

    # ll 命令
    echo "# $CMD_LL" >> "$R"
    echo "${CMD_LL}(){ $D/ll_num \"\$@\"; }" >> "$R"
    echo "" >> "$R"

    # sl 命令
    echo "# $CMD_SL" >> "$R"
    echo "${CMD_SL}(){ $D/sl \"\$@\"; }" >> "$R"
    echo "" >> "$R"

    # cd 函数（调用 cd_handler）
    echo "# $CMD_CD" >> "$R"
    cat >> "$R" << 'CDFUNC'
_cd_exec(){
    local result
    # 清除之前设置的变量
    unset CD_TARGET CD_DASH CD_HOME CD_FILE CD_ERROR CD_LETTER
    result=$(eval "$D/cd_handler \"\$1\" --shell=bash")
    if [[ -n "$result" ]]; then
        eval "$result"
        if [[ -n "$CD_TARGET" ]]; then
            builtin cd "$CD_TARGET"
            export LAST_CD_PATH="$CD_TARGET" LAST_CD_TIME=$(date +%s)
            _update_title
            $D/ll_num
        elif [[ -n "$CD_DASH" ]]; then
            builtin cd -
            export LAST_CD_PATH="$OLDPWD" LAST_CD_TIME=$(date +%s)
            _update_title
            $D/ll_num
        elif [[ -n "$CD_HOME" ]]; then
            builtin cd
            export LAST_CD_PATH="$HOME" LAST_CD_TIME=$(date +%s)
            _update_title
            $D/ll_num
            $D/ll_num
        elif [[ -n "$CD_FILE" ]]; then
            ${EDITOR:-gvim} "$CD_FILE" &
        elif [[ -n "$CD_ERROR" ]]; then
            echo "$CD_ERROR"
        fi
    fi
}
CDFUNC
    echo "${CMD_CD}(){ [[ \"\$1\" == \"--help\" ]]&&{ echo \"用法: $CMD_CD [数字|字母|目录|子串|模糊|-]\"; return; }; _cd_exec \"\$1\"; }" >> "$R"
    echo "" >> "$R"

    # 模糊命令
    if [[ "$CMD_CD" != "$CMD_FUZZY" ]]; then
        echo "# $CMD_FUZZY" >> "$R"
        echo "${CMD_FUZZY}(){ [[ -z \"\$1\" ]]&&{ echo \"用法: $CMD_FUZZY <模糊>\"; return 1; }; _cd_exec \"\$1\"; }" >> "$R"
    fi

    # Tab 补全
    echo "" >> "$R"
    echo "# Tab 补全" >> "$R"
    cat >> "$R" << 'COMPLETION'
_cd_completion() {
    local cur="${COMP_WORDS[COMP_CWORD]}"
    local i dirs files

    # 目录补全，添加 / 后缀
    dirs=($(compgen -d -- "$cur" 2>/dev/null))
    if [[ ${#dirs[@]} -gt 0 ]]; then
        for i in "${!dirs[@]}"; do
            dirs[$i]="${dirs[$i]}/"
        done
        COMPREPLY=("${dirs[@]}")
    fi

    # 没有目录时，尝试文件补全
    if [[ ${#COMPREPLY[@]} -eq 0 ]]; then
        files=($(compgen -f -- "$cur" 2>/dev/null))
        COMPREPLY=("${files[@]}")
    fi
}
COMPLETION
    echo "complete -o nospace -F _cd_completion $CMD_CD" >> "$R"
    [[ "$CMD_CD" != "$CMD_FUZZY" ]] && echo "complete -o nospace -F _cd_completion $CMD_FUZZY" >> "$R"
    echo "complete -o nospace -f $CMD_LL" >> "$R"

    echo "" >> "$R"
    echo "# <<< smart_cd <<<" >> "$R"
    ok "bash: $R"
}

# 安装 csh
inst_csh(){
    info "配置 csh..."
    # 检查是否已有配置
    if [[ -f "$HOME/.cshrc.smart_cd" ]]; then
        warn "已有 ~/.cshrc.smart_cd"
        if [[ "$FORCE" == "true" ]]; then
            rm -f "$HOME/.cshrc.smart_cd"
        else
            read -p "覆盖?[Y/n]:" y
            [[ "${y:-Y}"=~[Yy] ]]&&rm -f "$HOME/.cshrc.smart_cd"||return
        fi
    fi

    # 写入 csh 配置文件（使用 printf 避免 heredoc 的 backtick 问题）
    {
        printf '# >>> smart_cd >>>\n'
        printf "alias %s '%s/ll_num \\!*'\n" "$CMD_LL" "$D"
        printf "alias %s '%s/sl'\n" "$CMD_SL" "$D"
        printf "alias %s 'eval \`%s/cd_handler --shell=csh \\!*\`'\n" "$CMD_CD" "$D"
        printf "alias %s 'eval \`%s/cd_handler --shell=csh \\!*\`'\n" "$CMD_FUZZY" "$D"
        printf 'echo "smart_cd: %s %s %s %s"\n' "$CMD_LL" "$CMD_CD" "$CMD_SL" "$CMD_FUZZY"
        printf '# <<< smart_cd <<<\n'
        printf '\n'
        printf 'setenv LAST_CD_PATH ""\n'
        printf 'setenv LAST_CD_TIME ""\n'
    } > "$HOME/.cshrc.smart_cd"
    grep -q "cshrc.smart_cd" ~/.cshrc||echo 'if (-f ~/.cshrc.smart_cd) source ~/.cshrc.smart_cd' >> ~/.cshrc
    ok "csh: ~/.cshrc.smart_cd"
}

# 安装
inst(){
    info "安装..."

    if [[ "$ASK_SHELL" == "true" ]]; then
        echo -e "\n${C}=== Shell 选择 ===${R}"
        echo "1) bash only"
        echo "2) csh only"
        echo "3) both (bash + csh)"
        read -p "选择 [1/2/3]: " shell_choice
        case "$shell_choice" in
            1) B=true ;;
            2) S=true ;;
            3|*) B=true; S=true ;;
        esac
    fi

    cfg
    mk_python
    [[ "$CLEAN_DB" == "true" ]] && clean_db
    mk_config
    mk_ll&&ok "ll_num"
    mk_cd_handler&&ok "cd_handler"
    mk_cd_hook&&ok "cd_hook"
    mk_sl&&ok "sl"
    mk_ll_display&&ok "ll_display"
    [[ "$B" == "true" ]]&&inst_bash
    [[ "$S" == "true" ]]&&inst_csh
    ok "完成!"
    echo ""
    echo "命令: $CMD_LL(列表) $CMD_CD(切换) $CMD_SL(推荐)"
    [[ "$CMD_CD" != "$CMD_FUZZY" ]] && echo "      $CMD_FUZZY(模糊)"
    echo ""
    echo "智能推荐:"
    echo "  $CMD_SL        - 显示推荐目录"
    echo "  $CMD_CD a      - 进入推荐 a 对应目录"
    echo "  $CMD_CD b      - 进入推荐 b 对应目录"
    echo ""
    [[ "$B" == "true" ]]&&echo "生效: source ~/.bash_aliases"
    [[ "$S" == "true" ]]&&echo "生效: source ~/.cshrc"
}

# 卸载
uninst(){
    info "卸载..."
    rm -rf "$D" && ok "目录"
    sed -i '/^# >>> smart_cd/,/^# <<< smart_cd/d' ~/.bash_aliases ~/.bashrc 2>/dev/null && ok "bash"
    rm -f ~/.cshrc.smart_cd && sed -i '/cshrc.smart_cd/d' ~/.cshrc 2>/dev/null && ok "csh"
    ok "完成"
}

[[ "$A" == "uninstall" ]]&&{ uninst;exit 0; }
inst
