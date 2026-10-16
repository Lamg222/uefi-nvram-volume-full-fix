<#
.SYNOPSIS
  READ-ONLY look at UEFI boot entries and Secure Boot state from Windows (run PowerShell as Administrator).
.EXAMPLE
  powershell -ExecutionPolicy Bypass -File nvram-diagnose.ps1
.NOTES
  Windows cannot reliably free firmware variable space. If this shows many stale entries, boot an Ubuntu live USB
  ("Try Ubuntu") and run scripts/linux/nvram-cleanup.sh from there. Nothing here changes the machine.
#>
$ErrorActionPreference = 'Stop'
$admin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $admin) { Write-Host "Run this from an elevated (Administrator) PowerShell."; exit 1 }

Write-Host "== Secure Boot"
try { if (Confirm-SecureBootUEFI) { Write-Host "  enabled" } else { Write-Host "  disabled" } }
catch { Write-Host "  not available (legacy BIOS boot, or Secure Boot unsupported)" }

Write-Host ""
Write-Host "== Firmware boot entries (bcdedit /enum firmware)"
$raw = bcdedit /enum firmware | Out-String
$blocks = $raw -split "(?m)^-{5,}\s*$" | Where-Object { $_ -match 'identifier' }
$n = 0
foreach ($b in $blocks) {
  $id = ([regex]::Match($b, 'identifier\s+(\S+)')).Groups[1].Value
  $desc = ([regex]::Match($b, 'description\s+(.+)')).Groups[1].Value.Trim()
  if ($id -and $id -ne '{fwbootmgr}') { $n++; Write-Host ("  {0}  {1}" -f $id, $desc) }
}
Write-Host ("  -> {0} entries" -f $n)
if ($n -gt 8) { Write-Host "  [!] That is a lot. Stale entries from old installers/USB sticks fill the firmware's small variable store." }

Write-Host ""
Write-Host "Next step if you saw 'Volume Full': boot an Ubuntu live USB and run scripts/linux/nvram-diagnose.sh, then nvram-cleanup.sh."
