#!/usr/bin/env bash
# check-usb.sh — inspect an Ubuntu installer USB (Linux or macOS) BEFORE you boot from it.
#   bash check-usb.sh /path/to/mounted/usb [--fix] [--iso file.iso --sha256 <hash>]
#
# Looks for the situation seen in one real case: Rufus left TWO bootloader files named boot*.efi in EFI/BOOT,
# and the Ubuntu installer then failed to start properly. With --fix, extra boot*.efi files are renamed to
# *.efi.disabled (nothing is deleted; rename back to undo).
set -u

usb=""; fix=0; iso=""; want=""
while [ $# -gt 0 ]; do
  case "$1" in
    --fix) fix=1 ;;
    --iso) iso="$2"; shift ;;
    --sha256) want="$2"; shift ;;
    -h|--help) sed -n '2,9p' "$0"; exit 0 ;;
    *) usb="$1" ;;
  esac
  shift
done
[ -n "$usb" ] || { echo "Usage: bash $0 /path/to/usb [--fix] [--iso file --sha256 hash]"; exit 2; }

sha() { if command -v sha256sum >/dev/null; then sha256sum "$1" | cut -d' ' -f1; else shasum -a 256 "$1" | cut -d' ' -f1; fi; }

if [ -n "$iso" ]; then
  echo "== ISO checksum"
  have=$(sha "$iso"); echo "  $have"
  if [ -n "$want" ]; then
    [ "$(echo "$have" | tr A-F a-f)" = "$(echo "$want" | tr A-F a-f)" ] && echo "  OK: matches" || { echo "  [!] DOES NOT MATCH the expected hash. Download the ISO again."; exit 1; }
  fi
fi

dir=$(find "$usb" -maxdepth 2 -type d -iname BOOT -path '*EFI*' 2>/dev/null | head -1)
[ -n "$dir" ] || { echo "No EFI/BOOT folder under $usb — is this the right drive?"; exit 1; }

echo "== Files in $dir"
ls -l "$dir" | sed 's/^/  /'

# Expected fallback loaders: bootx64.efi (+ bootia32/aa64/arm), and next to it grubx64.efi / mmx64.efi
extra=$(find "$dir" -maxdepth 1 -type f -iname 'boot*.efi' | grep -viE '/boot(x64|ia32|aa64|arm)\.efi$')
count=$(find "$dir" -maxdepth 1 -type f -iname 'boot*.efi' | wc -l | tr -d ' ')
echo
echo "== boot*.efi files: $count"
if [ -n "$extra" ]; then
  echo "  [!] Unexpected extra bootloader file(s):"
  echo "$extra" | sed 's/^/      /'
  if [ "$fix" -eq 1 ]; then
    echo "$extra" | while IFS= read -r f; do mv -v -- "$f" "$f.disabled"; done
    echo "  Renamed. Eject the USB properly and try again."
  else
    echo "  Run again with --fix to rename them (reversible)."
  fi
elif [ "$count" -gt 1 ]; then
  echo "  [!] More than one standard boot*.efi (different CPU architectures?). Check that each belongs to your machine."
else
  echo "  Looks normal."
fi
