# Smart CD 极速版

**纯 Shell + 智能推荐，极致速度**

## 架构对比（原版 vs 极速版）

### 原版架构（纯 Python）

```
用户输入 cd 1
    ↓
Python smart_cd.py --resolve "1"  (~32ms)
    ↓
解析参数 → 查询数据库 → 匹配路径 → 返回结果
    ↓
builtin cd + Python --ll 显示 (~34ms)
    ↓
总计: ~66ms
```

**问题**：每次 cd 都启动 Python，有 ~30ms 启动开销。

### 极速版架构（Shell + 后台 Python）

```
用户输入 cd 1
    ↓
Shell 函数直接处理 (~2ms)
    ↓
ls | awk 匹配 → builtin cd → ll_num 显示 (~10ms)
    ↓
(后台) Python rec_visit.py 记录访问 (非阻塞)
    ↓
总计: ~12ms (不含后台任务)
```

**核心改变**：Shell 处理热路径，Python 仅做后台任务。

### 关键技术对比

| 功能 | 原版 | 极速版 | 提升 |
|------|------|--------|------|
| cd 数字/子串 | Python `--resolve` (32ms) | Shell awk (2ms) | **93%** |
| ll 显示 | Python `--ll` (34ms) | Shell awk (10ms) | **71%** |
| 推荐缓存读取 | Python (18ms) | jq (3ms) | **83%** |
| 推荐生成 | Python 同步 (阻塞) | Python 后台 (非阻塞) | 用户无感 |
| 访问记录 | Python 同步 | Python 后台 `(...)` | 非阻塞 |
| 字母推荐 | Python rec_letter.py (60ms) | jq 缓存 (35ms含显示) | **42%** |

### 架构设计原则

1. **Shell 处理热路径**
   - 数字导航、子串匹配、模糊搜索全部用 Shell/awk 实现
   - 避免 Python 启动开销（~30ms）

2. **jq 替代 Python JSON 解析**
   - 推荐缓存 `.rec_cache` 用 jq 读取（~2ms）
   - 原版用 Python json.load（~18ms）

3. **Python 仅做后台任务**
   - 推荐生成 `rec_gen.py` → 后台 `(python3 ... &)`
   - 访问记录 `rec_visit.py` → 后台 `(python3 ... &)`
   - 用户操作立即返回，Python 异步处理

4. **保留 Python 推荐算法**
   - 评分算法（频率+时间+转换+停留）保留 Python 实现
   - SQLite 数据库保留，不影响 cd 速度

5. **缓存机制**
   - `ll` 执行时后台生成推荐缓存 `.rec_cache`
   - `cd a` 用 jq 快速读取缓存，无需启动 Python

### 数据流对比

**原版（同步阻塞）**：
```
cd → Python解析(阻塞) → cd完成 → Python显示(阻塞) → 完成
      ↑ 用户等待 30ms          ↑ 用户等待 30ms
```

**极速版（异步非阻塞）**：
```
cd → Shell处理(2ms) → cd完成 → Shell显示(10ms) → 完成
      ↑ 用户无感              ↑ 用户无感
      ↓ 后台Python记录访问(异步)
      ↓ 后台Python生成推荐(异步)
```

## 功能

### 基础命令

| 命令 | 说明 |
|------|------|
| `ll` | 带编号的目录列表 |
| `cd` | 智能切换目录（数字/字母/子串匹配） |
| `cdd` | 模糊搜索跳转（递归2层，超时1s） |
| `sl` | 显示智能推荐 |

### cd 匹配优先级

1. **字母推荐**: `cd a` → 进入推荐目录 a
2. **数字**: `cd 1` → 第1个目录
3. **直接路径**: `cd /tmp` → 直接进入
4. **子串匹配**: `cd smart` → 进入包含"smart"的目录
5. **模糊匹配**: 仅当 `cdd=cd` 时集成

### 智能推荐

基于访问频率、时间模式、路径转换等生成推荐：

```bash
sl              # 显示推荐列表
cd a            # 进入推荐 a 对应目录
cd b            # 进入推荐 b 对应目录
```

推荐字母显示为 `[a]` `[b]` 等醒目格式。

### 模糊搜索 (cdd)

**算法**：字符按序出现，不必连续

```bash
# 示例：当前目录有 smart_cd
cdd scf  → 进入 smart_cd
cdd sdf  → 进入 smart_cd
```

**评分**：位置分数 + 名称长度惩罚 - 连续匹配奖励

**默认配置**：
- 搜索深度：2层（含子目录）
- 搜索超时：1000ms

## 安装

```bash
cd smart_cd
./install_fast.sh          # 默认 bash（交互式配置）
./install_fast.sh --bash   # 仅 bash
./install_fast.sh --csh    # 仅 csh
./install_fast.sh --both   # bash + csh
./install_fast.sh --clean-db   # 安装并清理数据库错误路径
./install_fast.sh --uninstall  # 卸载
```

### 安装选项

| 选项 | 说明 |
|------|------|
| `--bash` | 仅配置 bash |
| `--csh` | 仅配置 csh |
| `--both` | 配置 bash + csh |
| `--clean-db` | 清理数据库中的错误路径（双斜杠、..路径等） |
| `--no-rec` | 禁用智能推荐功能 |
| `--uninstall` | 卸载 |

### 自定义命令

安装时交互式配置：
- 目录列表命令（默认: ll）
- 切换目录命令（默认: cd）
- 模糊搜索命令（默认: cdd，设为 cd 则集成）
- 推荐显示命令（默认: sl）
- 推荐显示行数（默认: 5）
- 推荐字母颜色（默认: yellow）

**集成模式**：设模糊搜索为 cd 时，cd 自动包含模糊匹配功能。

## 文件

```
smart_cd/
├── install_fast.sh      # 安装脚本（含 sl/rec_cache_read 内联）
├── test_fast.sh         # 测试脚本
├── README.md
├── cd_handler/          # cd模块
│   └── cd_handler.sh.txt
├── ll_display/          # ll模块
│   └── ll_display.sh.txt
├── cd_hook/             # 后台任务模块
│   └── cd_hook.sh.txt
└── learning/            # Python模块（.txt 后缀）
    ├── smart_cd.py.txt  # 统一入口脚本
    ├── config.py.txt    # 配置模块
    ├── database.py.txt  # 数据库模块
    ├── predictor.py.txt # 推荐预测模块
    ├── scorer.py.txt    # 评分模块
    └ learner.py.txt   # 学习模块
```

安装后：
```
~/.local/share/smart_cd/
├── ll_num          # ls 脚本
├── sl              # 显示推荐脚本
├── rec_cache_read  # sed 快速缓存读取
├── cd_handler      # cd 处理脚本
├── cd_hook         # 后台任务脚本
├── config.ini      # 推荐配置文件
├── smart_cd.db     # 访问历史数据库
├── .rec_cache      # 推荐缓存
├── smart_cd.py     # 统一入口脚本
├── config.py       # 配置模块
├── database.py     # 数据库模块
├── predictor.py    # 推荐预测模块
├── scorer.py       # 评分模块
└── learner.py      # 学习模块
```

## 使用示例

```bash
ll              # 带编号列表
sl              # 显示智能推荐
cd a            # 进入推荐目录 a
cd 1            # 进入第1个目录
cd smart        # 子串匹配
cd -            # 返回上一目录
cd              # 回到 home
cd ..           # 进入父目录
cdd psc         # 模糊搜索跳转（递归2层）
cdd sub/dir     # 模糊搜索子目录
```

## 特点

- **极速**：纯 Shell 核心，jq 缓存读取 ~2ms
- **智能推荐**：基于历史数据的智能目录推荐
- **兼容**：保留原有 cd 全部功能
- **灵活**：命令名可自定义，推荐可禁用
- **轻量**：安装仅 ~30KB

## 配置文件

推荐配置文件：`~/.local/share/smart_cd/config.ini`

```ini
[display]
recommendation_limit = 5     # 显示行数，0 则禁用
letter_format = [a]          # 字母格式
letter_color = yellow        # 字母颜色
path_color = cyan            # 路径颜色
show_stats = true            # 显示访问统计

[exclude]
paths = /tmp, /var           # 排除的路径
patterns = __pycache__, .git # 排除的模式
```

禁用推荐：将 `recommendation_limit` 设为 0。

## 诊断与修复

```bash
./debug.sh      # 诊断脚本，检查安装状态
./fix_data.sh   # 修复脚本，清理错误数据
```

## License

MIT