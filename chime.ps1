param(
    [string]$EventName = "stop"
)

$ErrorActionPreference = "SilentlyContinue"

# === 调试日志 ===
$DebugLog = "$env:USERPROFILE\.claude\scripts\chime-debug.log"
try {
    "[DEBUG] $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') | Event: $EventName" | Out-File -FilePath $DebugLog -Append -Encoding UTF8
} catch {}

# Config file path
$ConfigPath = "$env:USERPROFILE\.claude\claude-chime.json"

# Exit silently if config does not exist
if (-not (Test-Path $ConfigPath)) {
    try { "[DEBUG] Config not found at: $ConfigPath" | Out-File -FilePath $DebugLog -Append -Encoding UTF8 } catch {}
    exit 0
}

try {
    $Config = Get-Content $ConfigPath -Raw -Encoding UTF8 | ConvertFrom-Json
}
catch {
    try { "[DEBUG] JSON parse failed: $_" | Out-File -FilePath $DebugLog -Append -Encoding UTF8 } catch {}
    exit 0
}

# Check global switch
if ($Config.enabled -eq $false) {
    try { "[DEBUG] Disabled by config" | Out-File -FilePath $DebugLog -Append -Encoding UTF8 } catch {}
    exit 0
}

# Get event config
$EventConfig = $Config.events.$EventName
if (-not $EventConfig) {
    try { "[DEBUG] No config for event: $EventName" | Out-File -FilePath $DebugLog -Append -Encoding UTF8 } catch {}
    exit 0
}

try { "[DEBUG] Mode: $($EventConfig.mode)" | Out-File -FilePath $DebugLog -Append -Encoding UTF8 } catch {}

# Play sound based on mode
switch ($EventConfig.mode) {
    "beep" {
        $freq = $EventConfig.beep.frequency
        $dur = $EventConfig.beep.duration
        if ($freq -and $dur) {
            try {
                [System.Console]::Beep($freq, $dur)
                "[DEBUG] Beep OK: freq=$freq dur=$dur" | Out-File -FilePath $DebugLog -Append -Encoding UTF8
            } catch {
                "[DEBUG] Beep FAILED: $_" | Out-File -FilePath $DebugLog -Append -Encoding UTF8
            }
        }
    }
    "audio" {
        $AudioPath = $EventConfig.audio.path
        if ($AudioPath -and (Test-Path $AudioPath)) {
            $ext = [System.IO.Path]::GetExtension($AudioPath).ToLower()
            $audioExtensions = @(".wav", ".mp3", ".ogg", ".flac", ".wma", ".aac", ".m4a")
            if ($ext -in $audioExtensions) {
                if ($ext -eq ".wav") {
                    $player = New-Object System.Media.SoundPlayer
                    $player.SoundLocation = $AudioPath
                    $player.PlaySync()
                }
                else {
                    try {
                        Start-Process -FilePath $AudioPath -WindowStyle Hidden -ErrorAction Stop
                    } catch {}
                }
            }
        }
    }
    "tts" {
        try {
            Add-Type -AssemblyName System.Speech -ErrorAction Stop
            $tts = New-Object System.Speech.Synthesis.SpeechSynthesizer
            $tts.Rate   = if ($null -ne $EventConfig.tts.rate) { $EventConfig.tts.rate } else { 0 }
            $tts.Volume = if ($null -ne $EventConfig.tts.volume) { $EventConfig.tts.volume } else { 100 }
            $tts.Speak($EventConfig.tts.text)
            "[DEBUG] TTS OK: $($EventConfig.tts.text)" | Out-File -FilePath $DebugLog -Append -Encoding UTF8
        }
        catch {
            # TTS engine unavailable, fall back to console beep
            "[DEBUG] TTS FAILED, fallback to beep: $_" | Out-File -FilePath $DebugLog -Append -Encoding UTF8
            [System.Console]::Beep(800, 200)
        }
    }
}

exit 0
