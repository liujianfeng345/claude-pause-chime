# Claude Code 声音提醒 — 实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在 Claude Code 等待输入、权限提示、任务完成时播放声音提醒用户

**Architecture:** 通过 Claude Code hooks 系统（settings.json）在事件触发时调用 PowerShell 脚本，脚本读取 claude-chime.json 配置，根据事件名和 mode 设置播放系统蜂鸣、自定义音频或 TTS 播报

**Tech Stack:** PowerShell 5.1（Windows 内置）, Claude Code hooks 系统

---

## 文件结构

```
~/.claude/
├── settings.json           # 修改：添加 hooks 配置
├── claude-chime.json       # 新建：声音模式配置文件
└── scripts/
    └── chime.ps1            # 新建：声音播放脚本
```

---

### Task 1: 创建目录和默认配置文件

**Files:**
- Create: `~/.claude/scripts/` (directory)
- Create: `~/.claude/claude-chime.json`

- [ ] **Step 1: 创建 scripts 目录**

```powershell
New-Item -ItemType Directory -Force -Path "$env:USERPROFILE\.claude\scripts"
```

- [ ] **Step 2: 写入 claude-chime.json 默认配置**

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

目标路径：`$env:USERPROFILE\.claude\claude-chime.json`

- [ ] **Step 3: 验证配置文件**

```powershell
Get-Content "$env:USERPROFILE\.claude\claude-chime.json" | ConvertFrom-Json
```

预期：成功解析，无错误

- [ ] **Step 4: 提交**

```bash
# 配置文件在 ~/.claude/ 下，不在仓库中。仓库中的文件先不提交。
# 此时无需 git 操作。
```

---

### Task 2: 编写声音播放脚本

**Files:**
- Create: `~/.claude/scripts/chime.ps1`

- [ ] **Step 1: 写入完整脚本**

```powershell
param(
    [string]$EventName = "stop"
)

$ErrorActionPreference = "SilentlyContinue"

# 配置文件路径
$ConfigPath = "$env:USERPROFILE\.claude\claude-chime.json"

# 配置文件不存在则静默退出
if (-not (Test-Path $ConfigPath)) {
    exit 0
}

try {
    $Config = Get-Content $ConfigPath -Raw | ConvertFrom-Json
}
catch {
    exit 0
}

# 检查全局开关
if (-not $Config.enabled) {
    exit 0
}

# 获取事件对应配置
$EventConfig = $Config.events.$EventName
if (-not $EventConfig) {
    exit 0
}

# 根据模式播放声音
switch ($EventConfig.mode) {
    "beep" {
        $freq = $EventConfig.beep.frequency
        $dur = $EventConfig.beep.duration
        if ($freq -and $dur) {
            [System.Console]::Beep($freq, $dur)
        }
    }
    "audio" {
        $AudioPath = $EventConfig.audio.path
        if ($AudioPath -and (Test-Path $AudioPath)) {
            $ext = [System.IO.Path]::GetExtension($AudioPath).ToLower()
            if ($ext -eq ".wav") {
                $player = New-Object System.Media.SoundPlayer
                $player.SoundLocation = $AudioPath
                $player.PlaySync()
                $player.Dispose()
            }
            else {
                # mp3 等格式用系统默认播放器（后台播放，不阻塞）
                Start-Process -FilePath $AudioPath -WindowStyle Hidden
            }
        }
    }
    "tts" {
        try {
            Add-Type -AssemblyName System.Speech -ErrorAction Stop
            $tts = New-Object System.Speech.Synthesis.SpeechSynthesizer
            $tts.Rate = $EventConfig.tts.rate
            $tts.Volume = $EventConfig.tts.volume
            $tts.Speak($EventConfig.tts.text)
            $tts.Dispose()
        }
        catch {
            # TTS 引擎不可用，降级到 beep
            $freq = $EventConfig.beep.frequency
            $dur = $EventConfig.beep.duration
            if ($freq -and $dur) {
                [System.Console]::Beep($freq, $dur)
            }
        }
    }
}

exit 0
```

目标路径：`$env:USERPROFILE\.claude\scripts\chime.ps1`

- [ ] **Step 2: 手动测试 beep 模式**

```powershell
powershell -ExecutionPolicy Bypass -File "$env:USERPROFILE\.claude\scripts\chime.ps1" stop
```

预期：听到一声短促蜂鸣（频率 800Hz，时长 300ms）

- [ ] **Step 3: 手动测试 permission 事件**

```powershell
powershell -ExecutionPolicy Bypass -File "$env:USERPROFILE\.claude\scripts\chime.ps1" permission
```

预期：听到较高频蜂鸣（频率 1200Hz，时长 200ms）

- [ ] **Step 4: 手动测试 complete 事件**

```powershell
powershell -ExecutionPolicy Bypass -File "$env:USERPROFILE\.claude\scripts\chime.ps1" complete
```

预期：听到较低频长音（频率 600Hz，时长 500ms）

- [ ] **Step 5: 测试 enabled=false 时静默**

临时修改 `claude-chime.json` 中 `enabled` 为 `false`，再次运行：

```powershell
powershell -ExecutionPolicy Bypass -File "$env:USERPROFILE\.claude\scripts\chime.ps1" stop
```

预期：无任何声音，无任何输出

测试完毕后恢复 `enabled` 为 `true`。

- [ ] **Step 6: 测试 TTS 模式**

临时修改 `claude-chime.json` 中 `events.stop.mode` 为 `"tts"`，运行：

```powershell
powershell -ExecutionPolicy Bypass -File "$env:USERPROFILE\.claude\scripts\chime.ps1" stop
```

预期：听到语音播报"我在等你说话呢"

测试完毕后恢复 `mode` 为 `"beep"`。

- [ ] **Step 7: 测试 audio 模式（可选，需要音频文件）**

若有测试音频文件 `/tmp/test.wav`，修改 `events.stop.mode` 为 `"audio"` 并将 `audio.path` 设为该路径，运行：

```powershell
powershell -ExecutionPolicy Bypass -File "$env:USERPROFILE\.claude\scripts\chime.ps1" stop
```

预期：播放指定音频

测试完毕后恢复配置。

- [ ] **Step 8: 提交（暂不提交，脚本在仓库外）**

---

### Task 3: 配置 Claude Code Hooks

**Files:**
- Modify: `~/.claude/settings.json` (添加 hooks 配置)

- [ ] **Step 1: 备份当前 settings.json**

```powershell
Copy-Item "$env:USERPROFILE\.claude\settings.json" "$env:USERPROFILE\.claude\settings.json.bak"
```

- [ ] **Step 2: 读取当前 settings.json**

```powershell
Get-Content "$env:USERPROFILE\.claude\settings.json"
```

记录当前完整内容，确保合并时不错漏。

- [ ] **Step 3: 添加 hooks 配置**

在 settings.json 中添加 `hooks` 字段（与现有的 `env`、`model`、`enabledPlugins` 等平级）：

```json
{
  "env": { "...保持原有不变..." },
  "model": "deepseek-v4-flash[1m]",
  "enabledPlugins": { "...保持原有不变..." },
  "extraKnownMarketplaces": { "...保持原有不变..." },
  "skipDangerousModePermissionPrompt": true,
  "hooks": {
    "Stop": [
      {
        "command": "powershell -ExecutionPolicy Bypass -File \"$env:USERPROFILE\\.claude\\scripts\\chime.ps1\" stop"
      }
    ],
    "PreToolUse": [
      {
        "matcher": "AskUserQuestion",
        "command": "powershell -ExecutionPolicy Bypass -File \"$env:USERPROFILE\\.claude\\scripts\\chime.ps1\" permission"
      }
    ],
    "Notification": [
      {
        "matcher": "task-complete",
        "command": "powershell -ExecutionPolicy Bypass -File \"$env:USERPROFILE\\.claude\\scripts\\chime.ps1\" complete"
      }
    ]
  }
}
```

> **注意**：Hook 名称（`Stop`、`PreToolUse`、`Notification`）和 matcher 值（`task-complete`）为实现推测。实际写入时需确认 Claude Code 支持的 hook 命名。若 settings.json 中 hook 字段名使用小驼峰或其他格式，以实际为准。

- [ ] **Step 4: 验证 settings.json 语法**

```powershell
Get-Content "$env:USERPROFILE\.claude\settings.json" | ConvertFrom-Json
```

预期：成功解析，无 JSON 语法错误

- [ ] **Step 5: 验证 Stop hook 生效**

在 Claude Code 中发送任意消息（如"你好"），等 Claude 回复完毕后：

预期：听到 stop 事件的蜂鸣声

- [ ] **Step 6: 验证 Permission hook 生效**

在 Claude Code 中执行需要权限的操作（如运行需要批准的 Bash 命令）：

预期：弹出权限提示时听到 permission 事件的蜂鸣声

- [ ] **Step 7: 验证 Complete hook 生效**

等待后台任务（如有）完成：

预期：任务完成时听到 complete 事件的蜂鸣声

- [ ] **Step 8: 提交**

```bash
# settings.json 在仓库外，无需 git 操作
# 保留备份文件 settings.json.bak 以便回滚
```

---

### Task 4: 回滚预案

如果 hooks 配置导致问题，通过备份快速恢复：

```powershell
Copy-Item "$env:USERPROFILE\.claude\settings.json.bak" "$env:USERPROFILE\.claude\settings.json" -Force
```

移除功能时删除以下文件：
```powershell
Remove-Item "$env:USERPROFILE\.claude\claude-chime.json"
Remove-Item "$env:USERPROFILE\.claude\scripts\chime.ps1"
Remove-Item "$env:USERPROFILE\.claude\scripts" -Recurse
```
并移除 `settings.json` 中的 `hooks` 字段。

---

## 实现注意事项

1. **Hook 名称验证**：`Stop`、`PreToolUse`、`Notification` 以及 matcher 值 `task-complete` 需要在 Task 3 Step 3 写入前，根据 Claude Code 实际支持的 hook 命名做最终确认
2. **脚本路径**：settings.json 中 command 字段使用 `$env:USERPROFILE` 环境变量可能不会被展开，如遇问题改用 `$HOME/` 绝对路径
3. **字符编码**：PowerShell 脚本和 JSON 配置均使用 UTF-8 编码保存
4. **权限**：chime.ps1 通过 `-ExecutionPolicy Bypass` 执行，无需设置系统执行策略
