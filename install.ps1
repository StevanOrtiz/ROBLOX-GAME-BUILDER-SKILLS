# Install the Roblox skills, the ihaveadhd output style and the always-on CLAUDE.md block (Windows).
$ErrorActionPreference = "Stop"
$Src  = Split-Path -Parent $MyInvocation.MyCommand.Path
$Dest = if ($env:CLAUDE_HOME) { $env:CLAUDE_HOME } else { Join-Path $HOME ".claude" }
New-Item -ItemType Directory -Force -Path "$Dest\skills", "$Dest\output-styles" | Out-Null

Copy-Item -Recurse -Force "$Src\skills\*" "$Dest\skills\"
Copy-Item -Force "$Src\output-styles\ihaveadhd.md" "$Dest\output-styles\"

$cm = Join-Path $Dest "CLAUDE.md"
if (-not (Test-Path $cm)) { New-Item -ItemType File -Path $cm | Out-Null }
$text = Get-Content -Raw $cm
$text = [regex]::Replace($text, "(?s)<!-- roblox-skills:begin -->.*?<!-- roblox-skills:end -->\r?\n?", "")
$block = Get-Content -Raw "$Src\claude-md-block.md"
Set-Content -Path $cm -Value ($text.TrimEnd() + "`n`n" + $block) -NoNewline

# set the global output style only if the user has not set one
$settings = Join-Path $Dest "settings.json"
if (-not (Test-Path $settings)) { Set-Content -Path $settings -Value "{}" }
$obj = Get-Content -Raw $settings | ConvertFrom-Json
if ($null -eq $obj.PSObject.Properties["outputStyle"]) {
    $obj | Add-Member -NotePropertyName outputStyle -NotePropertyValue "ihaveadhd"
    $obj | ConvertTo-Json -Depth 20 | Set-Content -Path $settings
    Write-Host "outputStyle set to ihaveadhd"
} else {
    Write-Host "outputStyle already set to $($obj.outputStyle) - left unchanged"
}

Write-Host "Installed to $Dest"
Write-Host "Restart Claude Code to load the skills and the output style."
