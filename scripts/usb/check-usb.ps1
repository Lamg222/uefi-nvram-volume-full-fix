<#
.SYNOPSIS
  Inspect an Ubuntu installer USB (Windows) before booting from it.
.EXAMPLE
  powershell -ExecutionPolicy Bypass -File check-usb.ps1 -Drive E:
  powershell -ExecutionPolicy Bypass -File check-usb.ps1 -Drive E: -Fix
  powershell -ExecutionPolicy Bypass -File check-usb.ps1 -Drive E: -Iso C:\ubuntu.iso -Sha256 <hash>
.DESCRIPTION
  Looks for extra boot*.efi files in EFI\BOOT (seen in one real case after writing the stick with Rufus).
  With -Fix they are renamed to *.efi.disabled. Nothing is deleted; rename back to undo.
#>
param(
  [Parameter(Mandatory = $true)][string]$Drive,
  [switch]$Fix,
  [string]$Iso,
  [string]$Sha256
)

if ($Iso) {
  Write-Host "== ISO checksum"
  $have = (Get-FileHash -Algorithm SHA256 -LiteralPath $Iso).Hash.ToLower()
  Write-Host "  $have"
  if ($Sha256) {
    if ($have -eq $Sha256.ToLower()) { Write-Host "  OK: matches" }
    else { Write-Host "  [!] DOES NOT MATCH the expected hash. Download the ISO again."; exit 1 }
  }
}

$root = $Drive.TrimEnd('\') + '\'
$dir = Join-Path $root 'EFI\BOOT'
if (-not (Test-Path -LiteralPath $dir)) { Write-Host "No EFI\BOOT folder on $Drive - is this the right drive?"; exit 1 }

Write-Host "== Files in $dir"
Get-ChildItem -LiteralPath $dir -File | ForEach-Object { "  {0,10}  {1}" -f $_.Length, $_.Name }

$boot = Get-ChildItem -LiteralPath $dir -File -Filter 'boot*.efi'
$extra = $boot | Where-Object { $_.Name -notmatch '^boot(x64|ia32|aa64|arm)\.efi$' }
Write-Host ""
Write-Host ("== boot*.efi files: {0}" -f @($boot).Count)
if ($extra) {
  Write-Host "  [!] Unexpected extra bootloader file(s):"
  $extra | ForEach-Object { Write-Host ("      " + $_.Name) }
  if ($Fix) {
    $extra | ForEach-Object { Rename-Item -LiteralPath $_.FullName -NewName ($_.Name + '.disabled'); Write-Host ("  renamed " + $_.Name) }
    Write-Host "  Done. Eject the USB (safely remove) and try again."
  } else {
    Write-Host "  Run again with -Fix to rename them (reversible)."
  }
} else {
  Write-Host "  Looks normal."
}
