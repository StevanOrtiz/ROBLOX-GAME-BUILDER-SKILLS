# Install the Roblox skills, the ihaveadhd output style and the always-on CLAUDE.md block (Windows).
# Run from a terminal:  powershell -ExecutionPolicy Bypass -File .\install.ps1
$ErrorActionPreference = "Stop"
$Src  = Split-Path -Parent $MyInvocation.MyCommand.Path
$Dest = if ($env:CLAUDE_HOME) { $env:CLAUDE_HOME } else { Join-Path $HOME ".claude" }
$Utf8 = New-Object System.Text.UTF8Encoding($false)   # UTF-8 without BOM

function Read-Text([string]$path) {
    if (Test-Path $path) {
        $t = [System.IO.File]::ReadAllText($path, $Utf8)
        if ($null -ne $t) { return $t }
    }
    return ""
}
function Write-Text([string]$path, [string]$text) {
    [System.IO.File]::WriteAllText($path, $text, $Utf8)
}

New-Item -ItemType Directory -Force -Path (Join-Path $Dest "skills"), (Join-Path $Dest "output-styles") | Out-Null

Copy-Item -Recurse -Force (Join-Path $Src "skills\*") (Join-Path $Dest "skills")
Copy-Item -Force (Join-Path $Src "output-styles\ihaveadhd.md") (Join-Path $Dest "output-styles")

# CLAUDE.md: drop any previous copy of the block, then append the current one
$cm    = Join-Path $Dest "CLAUDE.md"
$text  = Read-Text $cm
$text  = [regex]::Replace($text, "(?s)<!-- roblox-skills:begin -->.*?<!-- roblox-skills:end -->\r?\n?", "")
$block = Read-Text (Join-Path $Src "claude-md-block.md")
$prefix = $text.TrimEnd()
if ($prefix.Length -gt 0) { $prefix += "`r`n`r`n" }
Write-Text $cm ($prefix + $block.TrimEnd() + "`r`n")

# settings.json: set outputStyle only if absent (text insertion, keeps the rest of the file untouched)
$settings = Join-Path $Dest "settings.json"
$raw = Read-Text $settings
if ([string]::IsNullOrWhiteSpace($raw)) {
    Write-Text $settings "{`r`n  `"outputStyle`": `"ihaveadhd`"`r`n}`r`n"
    Write-Host "outputStyle set to ihaveadhd"
} elseif ($raw -match '"outputStyle"\s*:') {
    Write-Host "outputStyle already set - left unchanged"
} elseif ($raw -match '^\s*\{\s*\}\s*$') {
    Write-Text $settings "{`r`n  `"outputStyle`": `"ihaveadhd`"`r`n}`r`n"
    Write-Host "outputStyle set to ihaveadhd"
} else {
    $first = New-Object System.Text.RegularExpressions.Regex('\{')   # instance Replace(input, replacement, count)
    $new = $first.Replace($raw, "{`r`n  `"outputStyle`": `"ihaveadhd`",", 1)
    Write-Text $settings $new
    Write-Host "outputStyle set to ihaveadhd"
}

Write-Host "Installed to $Dest"
Write-Host "Restart Claude Code to load the skills and the output style."
