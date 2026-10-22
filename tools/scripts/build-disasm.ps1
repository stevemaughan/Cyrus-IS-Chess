# Regenerate disasm/cyrus.skool and disasm/cyrus.asm from the control files in disasm/ctl.
# Usage: powershell -File tools/scripts/build-disasm.ps1
$root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$py = Join-Path $env:USERPROFILE 'scoop\apps\python\current\python.exe'
$scripts = Join-Path $env:USERPROFILE 'scoop\apps\python\current\Scripts'
Push-Location $root
try {
    # SkoolKit writes progress to stderr; Windows PowerShell would treat that as an error record.
    cmd /c "`"$py`" -I `"$scripts\sna2skool.py`" -H -c disasm\ctl reference\snapshots\cyrus48-entry-6000.z80 > disasm\cyrus.skool 2>nul"
    if ($LASTEXITCODE -ne 0) { throw "sna2skool failed ($LASTEXITCODE)" }
    cmd /c "`"$py`" -I `"$scripts\skool2asm.py`" -H -w disasm\cyrus.skool > disasm\cyrus.asm 2>nul"
    if ($LASTEXITCODE -ne 0) { throw "skool2asm failed ($LASTEXITCODE)" }
    Write-Output "disasm/cyrus.skool: $((Get-Content disasm\cyrus.skool).Count) lines; disasm/cyrus.asm: $((Get-Content disasm\cyrus.asm).Count) lines"
} finally {
    Pop-Location
}
