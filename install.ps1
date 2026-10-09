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

Write-Host "Installed to $Dest"
Write-Host "Next: in Claude Code run  /output-style ihaveadhd  then restart Claude Code."
