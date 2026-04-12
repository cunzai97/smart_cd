# Smart CD - 智能目录导航工具

**Author: panyu**

基于访问频率、时间规律、跳转概率等多维度评分的智能目录推荐工具。

## 核心特性

- **智能推荐**: 根据访问频率、停留时间、时间段规律、跳转概率综合评分
- **快捷导航**: 支持编号、字母、子串匹配、模糊搜索多种方式
- **双 Shell 支持**: 同时支持 bash 和 csh/tcsh
- **后台守护**: 自动记录目录访问数据，计算停留时间
- **高度可配置**: 配置文件自定义显示数量、颜色、评分权重等

## 安装

```bash
# bash 用户
./install.sh

# csh/tcsh 用户
./install.sh --csh

# 同时安装两种 shell
./install.sh --both

# 卸载
./install.sh --uninstall
```

安装后会提示重新加载配置：
```bash
source ~/.bashrc  # 或 source ~/.cshrc
```

## 使用方法

### 目录导航

| 命令 | 说明 |
|------|------|
| `cd` | 回到 home 目录，显示目录列表和推荐 |
| `cd 3` | 进入当前目录第 3 个条目 |
| `cd a` | 进入推荐 a 对应的目录 (a=第1推荐, b=第2推荐...) |
| `cd proj` | 子串匹配，进入包含 "proj" 的目录 |
| `cd -` | 返回上一次目录 |
| `cdd query` | 模糊搜索跳转 (允许跳字符，如 `cdd psc` 匹配 `project/src`) |

### 文件操作

| 命令 | 说明 |
|------|------|
| `cd 5` (文件) | 用编辑器打开第 5 个条目（如果是文件） |
| `cd readme.md` | 用编辑器打开文件 |

### 辅助命令

| 命令 | 说明 |
|------|------|
| `ll` | 带编号和颜色的目录列表 |
| `sl` | 只显示推荐，不切换目录 |
| `sr` | 切换推荐显示开关 |
| `so` | 切换输出顺序（目录先/推荐先） |
| `sc` | 切换底部对齐输出 |
| `cd --help` | 显示详细帮助 |

## 智能推荐算法

推荐评分基于四个维度：

1. **访问频率 (Frequency)**: 访问次数越多，分数越高
2. **停留时间 (Dwell Time)**: 在目录停留时间越长，说明越重要
3. **时间规律 (Time Pattern)**: 当前时间段常访问的目录得分更高
4. **跳转概率 (Transition)**: 从当前目录跳转到目标目录的历史概率

## 配置文件

位置: `~/.local/share/smart_cd/config.ini`

```ini
[display]
recommendation_limit = 5      # 推荐数量
color_recommendation = green  # 推荐颜色
color_directory = blue        # 目录颜色
color_executable = green      # 可执行文件颜色
color_other = gray            # 其他文件颜色

[scoring]
frequency_weight = 0.30       # 频率权重
recency_weight = 0.25         # 最近访问权重
time_pattern_weight = 0.20    # 时间规律权重
transition_weight = 0.15      # 跳转概率权重
dwell_weight = 0.10           # 停留时间权重

[editor]
command = gvim                # 默认编辑器 (可用 $EDITOR 覆盖)

[fuzzy]
max_depth = 3                 # 模糊搜索最大深度
```

## 文件结构

```
smart_cd/
├── install.sh              # 安装脚本
├── smart_cd.py.txt         # 主程序入口
├── config.py.txt           # 配置管理
├── database.py.txt         # SQLite 数据库操作
├── tracker.py.txt          # 访问记录追踪
├── scorer.py.txt           # 评分算法
├── predictor.py.txt        # 预测引擎
├── daemon.py.txt           # 后台守护进程
├── display.py.txt          # 输出格式化
├── fuzzy.py.txt            # 模糊搜索
├── ll_num.txt              # 编号目录列表脚本
├── smart_cd_wrapper.txt    # tcsh/csh wrapper
├── cdd_wrapper.txt         # cdd 命令 wrapper
├── cshrc.smart_cd.txt      # csh 配置模板
├── config.example.ini.txt  # 配置示例
└── README.md               # 说明文档
```

## 安装后目录结构

```
~/.local/share/smart_cd/
├── smart_cd.py             # 主程序
├── config.py               # 配置模块
├── database.py             # 数据库模块
├── tracker.py              # 追踪模块
├── scorer.py               # 评分模块
├── predictor.py            # 预测模块
├── daemon.py               # 守护进程
├── display.py              # 显示模块
├── fuzzy.py                # 模糊搜索
├── ll_num                  # 目录列表脚本
├── smart_cd_wrapper        # csh wrapper
├── cdd_wrapper             # cdd wrapper
├── config.ini              # 用户配置
└── smart_cd.db             # SQLite 数据库

~/.local/bin/
├── smart_cd                # 可执行入口
└── smart_cd_daemon         # 守护进程入口
```

## 跨平台支持

- Python 文件使用 `$HOME` 和 `XDG_DATA_HOME`，无硬编码路径
- 编辑器使用 `$EDITOR` 环境变量，默认 gvim
- `/proc` 文件系统检测仅限 Linux，其他平台自动跳过

## 自定义命令名称

安装时可自定义命令名称：
- 目录列表命令（默认 `ll`）
- 切换目录命令（默认 `cd`）
- 模糊搜索命令（默认 `cdd`）

如果 cd 和 cdd 设为同一命令，会优先尝试 cd 逻辑，失败后自动尝试模糊搜索。

## 依赖

- Python 3.6+
- SQLite3 (Python 内置)

## License

MIT