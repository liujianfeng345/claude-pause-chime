# Claude Code 任务声音提醒 — 设计文档

**日期**: 2026-05-21  
**状态**: 待实现

## 概述

当 Claude Code 发生以下事件时，通过声音提醒用户：

| 事件 | 描述 | 触发 Hook |
|------|------|-----------|
| 等待输入 | Claude 完成一轮响应，等待用户下一条指令 | `Stop` |
| 权限提示 | 弹出权限确认（AskUserQuestion），等待用户批准 | `PreToolUse` (matcher: AskUserQuestion) |
| 任务完成 | 后台任务执行完成 | `Notification` (matcher: task-complete) |

每个事件支持三种声音模式，通过配置切换：
- **系统蜂鸣** (beep)：Windows 控制台蜂鸣，可调音调和时长
- **自定义音频** (audio)：播放用户指定的 mp3/wav 文件
- **TTS 播报** (tts)：Windows SAPI 语音合成朗读文字

全局生效，配置存储在 `~/.claude/` 下。

## 文件结构

```
~/.claude/
├── settings.json           # Hooks 配置
├── claude-chime.json       # 声音模式配置
└── scripts/
    └── chime.ps1            # 声音播放脚本
```

## 配置格式 (`claude-chime.json`)

```json
{
  "enabled": true,
  "events": {
    "stop": {
      "mode": "beep",
      "beep": { "frequency": 800, "duration": 300 },
      "audio": { "path": "" },
      "tts": { "text": "我在等你说话呢", "rate": 0, "volume": 100 }
    },
    "permission": {
      "mode": "beep",
      "beep": { "frequency": 1200, "duration": 200 },
      "audio": { "path": "" },
      "tts": { "text": "需要你的批准", "rate": 0, "volume": 100 }
    },
    "complete": {
      "mode": "beep",
      "beep": { "frequency": 600, "duration": 500 },
      "audio": { "path": "" },
      "tts": { "text": "任务已完成", "rate": 0, "volume": 100 }
    }
  }
}
```

每个事件独立的 `mode` 字段控制当前使用的声音模式。切换模式只需修改 `mode` 值。

## Hooks 注册 (`settings.json`)

```json
{
  "hooks": {
    "Stop": [
      {
        "command": "powershell -ExecutionPolicy Bypass -File \"C:/Users/87362/.claude/scripts/chime.ps1\" stop"
      }
    ],
    "PreToolUse": [
      {
        "command": "powershell -ExecutionPolicy Bypass -File \"C:/Users/87362/.claude/scripts/chime.ps1\" permission",
        "matcher": "AskUserQuestion"
      }
    ],
    "Notification": [
      {
        "command": "powershell -ExecutionPolicy Bypass -File \"C:/Users/87362/.claude/scripts/chime.ps1\" complete",
        "matcher": "task-complete"
      }
    ]
  }
}
```

## 脚本逻辑 (`chime.ps1`)

```
接收参数（事件名）
    ↓
读取 ~/.claude/claude-chime.json
    ↓
若 enabled=false 或文件不存在 → 静默退出
    ↓
查 events.<event_name>
    ↓
根据 mode 值选择播放方式：
  ├── "beep"  → [System.Console]::Beep(frequency, duration)
  ├── "audio" → 读取 audio.path，用 Media.SoundPlayer / Start-Process 播放
  └── "tts"   → 用 SpeechSynthesizer 朗读 tts.text
```

- 脚本本身不维护配置，只读取
- 无外部依赖，全部使用 Windows 内置 .NET API
- 播放失败时不阻塞，静默退出

## 错误处理

- 配置文件不存在 → 静默退出（未安装状态）
- 音频文件不存在 → 静默退出，不播放
- TTS 引擎不可用 → 降级到 beep
- 播放异常 → 静默退出，不影响 Claude Code 正常运行

## 实现注意事项

- Hook 名称（`Stop`、`PreToolUse`、`Notification`）和 matcher 值（`task-complete`）为实现时的最佳推测，需在实际配置中验证。若 Claude Code 实际 hook 命名不同，以实际为准。
- `settings.json` 中脚本路径使用 `$env:USERPROFILE` 或绝对路径，确保 PowerShell 能正确解析。

## 测试计划

1. 配置 `mode: "beep"`，触发 Stop 事件，验证蜂鸣声
2. 修改 `mode: "audio"`，指定有效音频文件路径，验证播放
3. 修改 `mode: "tts"`，验证 TTS 朗读
4. 指定无效音频路径，验证静默退出
5. 设置 `enabled: false`，验证不发出声音
6. 触发权限提示，验证 Permission 事件独立声音
7. 完成任务，验证 Complete 事件独立声音
