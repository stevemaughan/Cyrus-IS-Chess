# Regenerate disasm/cyrus.skool and disasm/cyrus.asm from the control files in disasm/ctl.
# Usage: powershell -File tools/scripts/build-disasm.ps1
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$py = Join-Path $env:USERPROFILE 'scoop\apps\python\current\python.exe'
$scripts = Join-Path $env:USERPROFILE 'scoop\apps\python\current\Scripts'
Push-Location $root
try {
    & $py -I (Join-Path $scripts 'sna2skool.py') -H -c disasm\ctl reference\snapshots\cyrus48-entry-6000.z80 |
        Set-Content disasm\cyrus.skool -Encoding ascii
    & $py -I (Join-Path $scripts 'skool2asm.py') -H disasm\cyrus.skool |
        Set-Content disasm\cyrus.asm -Encoding ascii
    Write-Output "disasm/cyrus.skool: $((Get-Content disasm\cyrus.skool).Count) lines"
} finally {
    Pop-Location
}
