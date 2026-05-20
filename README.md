# Claude Code 声音提醒

当 Claude Code 等待用户输入、弹出权限提示或任务完成时，自动发出声音提醒——让你不必一直盯着屏幕。

## 功能特性

- **三事件独立提醒**：等待输入 / 权限提示 / 任务完成，各有独立声音
- **三种声音模式**：系统蜂鸣（beep）、自定义音频文件、TTS 语音播报
- **按事件切换模式**：每个事件可独立选择声音模式，修改配置文件即时生效
- **全局生效**：配置在 `~/.claude/` 下，所有项目通用
- **无外部依赖**：仅使用 Windows 内置 PowerShell + .NET API

## 技术栈

| 组件 | 技术 |
|------|------|
| 声音播放 | PowerShell 5.1 |
| 音频输出 | `System.Speech.Synthesis` (TTS) / `System.Media.SoundPlayer` (WAV) / `System.Console.Beep` |
| 事件触发 | Claude Code Hooks (`Stop` / `PermissionRequest` / `Notification`) |
| 配置存储 | JSON（`~/.claude/claude-chime.json`） |

## 快速开始

### 1. 部署文件

将以下文件复制到 `~/.claude/` 目录：

```powershell
# 创建脚本目录
New-Item -ItemType Directory -Force -Path "$env:USERPROFILE\.claude\scripts"

# 复制配置文件
Copy-Item claude-chime.json "$env:USERPROFILE\.claude\claude-chime.json"

# 复制播放脚本
Copy-Item chime.ps1 "$env:USERPROFILE\.claude\scripts\chime.ps1"
```

### 2. 注册 Hooks

在 `~/.claude/settings.json` 中添加 hooks 配置：

```json
"hooks": {
  "Stop": [
    {
      "matcher": "",
      "hooks": [
        {
          "type": "command",
          "command": "powershell -ExecutionPolicy Bypass -File \"C:/Users/<你的用户名>/.claude/scripts/chime.ps1\" stop"
        }
      ]
    }
  ],
  "PermissionRequest": [
    {
      "matcher": "",
      "hooks": [
        {
          "type": "command",
          "command": "powershell -ExecutionPolicy Bypass -File \"C:/Users/<你的用户名>/.claude/scripts/chime.ps1\" permission"
        }
      ]
    }
  ],
  "Notification": [
    {
      "matcher": "task-complete",
      "hooks": [
        {
          "type": "command",
          "command": "powershell -ExecutionPolicy Bypass -File \"C:/Users/<你的用户名>/.claude/scripts/chime.ps1\" complete"
        }
      ]
    }
  ]
}
```

> 将 `<你的用户名>` 替换为你的 Windows 用户名，确保脚本路径为绝对路径。

### 3. 验证

在 PowerShell 中运行以下命令，确认能听到声音：

```powershell
# 测试等待输入
powershell -ExecutionPolicy Bypass -File "$env:USERPROFILE\.claude\scripts\chime.ps1" stop

# 测试权限提示
powershell -ExecutionPolicy Bypass -File "$env:USERPROFILE\.claude\scripts\chime.ps1" permission

# 测试任务完成
powershell -ExecutionPolicy Bypass -File "$env:USERPROFILE\.claude\scripts\chime.ps1" complete
```

## 使用说明

### 事件说明

| 事件 | 触发时机 | Hook 类型 |
|------|----------|-----------|
| `stop` | Claude 完成一轮响应，等待用户下一条指令 | `Stop` |
| `permission` | 弹出权限确认窗口，等待用户批准 | `PermissionRequest` |
| `complete` | 后台任务执行完成 | `Notification` |

### 切换声音模式

编辑 `~/.claude/claude-chime.json`，修改对应事件的 `mode` 字段：

- `"beep"` — 系统蜂鸣，可调频率（Hz）和时长（ms）
- `"audio"` — 播放自定义 mp3/wav 文件，填入 `audio.path`
- `"tts"` — Windows 语音合成朗读，自定义 `tts.text`

修改后即时生效，无需重启 Claude Code。

### 禁用与启用

将 `enabled` 设为 `false` 可全局静音：

```json
{
  "enabled": false,
  "events": { ... }
}
```

## 项目结构

```
claude-pause-chime/
├── chime.ps1                     # 声音播放脚本
├── claude-chime.json             # 声音模式配置
├── docs/
│   └── superpowers/
│       ├── specs/
│       │   └── 2026-05-21-...-design.md  # 设计文档
│       └── plans/
│           └── 2026-05-21-...-plan.md    # 实现计划
└── README.md
```

部署后的 `~/.claude/` 目录结构：

```
~/.claude/
├── settings.json                 # 全局配置（含 hooks）
├── claude-chime.json             # 声音模式配置
└── scripts/
    └── chime.ps1                 # 播放脚本
```

## 配置说明

### claude-chime.json

| 字段 | 类型 | 说明 |
|------|------|------|
| `enabled` | boolean | 全局开关，`false` 静音 |
| `events.<name>.mode` | string | 声音模式：`"beep"` / `"audio"` / `"tts"` |
| `events.<name>.beep.frequency` | number | 蜂鸣频率（Hz），默认 600-1200 |
| `events.<name>.beep.duration` | number | 蜂鸣时长（ms），默认 200-500 |
| `events.<name>.audio.path` | string | 音频文件绝对路径 |
| `events.<name>.tts.text` | string | TTS 播报文本 |
| `events.<name>.tts.rate` | number | 语速，-10（慢）到 10（快），默认 0 |
| `events.<name>.tts.volume` | number | 音量，0 到 100，默认 100 |

## 测试

```powershell
# 正常模式测试
powershell -ExecutionPolicy Bypass -File "$env:USERPROFILE\.claude\scripts\chime.ps1" stop
powershell -ExecutionPolicy Bypass -File "$env:USERPROFILE\.claude\scripts\chime.ps1" permission
powershell -ExecutionPolicy Bypass -File "$env:USERPROFILE\.claude\scripts\chime.ps1" complete

# 静音测试：临时将 claude-chime.json 中 enabled 设为 false，运行上述命令应无声音

# TTS 测试：临时将 mode 改为 "tts"，运行命令应听到语音播报
```

## 常见问题

### 听不到声音？

1. 检查 `claude-chime.json` 中 `enabled` 是否为 `true`
2. 确认 `chime.ps1` 路径与 `settings.json` hooks 中一致
3. 如果使用 beep 模式：部分笔记本没有 PC 扬声器，建议切换到 `tts` 模式
4. 检查 `~/.claude/scripts/chime-debug.log`（如存在）查看脚本执行日志

### TTS 语音不流畅？

可在配置中调整 `tts.rate`（语速）和 `tts.volume`（音量）。

### 如何回滚？

```powershell
# 恢复 settings.json 备份
Copy-Item "$env:USERPROFILE\.claude\settings.json.bak" "$env:USERPROFILE\.claude\settings.json" -Force

# 删除功能文件
Remove-Item "$env:USERPROFILE\.claude\scripts\chime.ps1"
Remove-Item "$env:USERPROFILE\.claude\claude-chime.json"
```

## 许可证

MIT
