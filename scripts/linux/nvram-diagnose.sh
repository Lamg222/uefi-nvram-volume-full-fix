#!/usr/bin/env bash
# nvram-diagnose.sh — READ-ONLY report on the health of the UEFI variable store.
# Run it from the installed system or from a live USB (Ubuntu "Try Ubuntu"). Needs no changes to the machine.
#   sudo bash nvram-diagnose.sh
set -u

if [ ! -d /sys/firmware/efi ]; then
  echo "This session was not booted in UEFI mode, so there is no UEFI variable store to inspect."
  echo "(Legacy/CSM boot, or a non-UEFI machine.)"
  exit 1
fi

have() { command -v "$1" >/dev/null 2>&1; }
efi=/sys/firmware/efi/efivars
problems=0
flag() { echo "  [!] $*"; problems=$((problems + 1)); }

echo "== 1. Secure Boot"
if have mokutil; then mokutil --sb-state 2>&1 | sed 's/^/  /'; else echo "  mokutil not installed (sudo apt install mokutil) — skipping"; fi

echo
echo "== 2. Space used by UEFI variables (efivarfs)"
if [ -d "$efi" ]; then
  total=$(find "$efi" -type f -printf '%s\n' 2>/dev/null | awk '{s+=$1} END {print s+0}')
  count=$(find "$efi" -type f 2>/dev/null | wc -l)
  echo "  $count variables, $((total / 1024)) KiB in total (sizes include a 4-byte header each)"
  echo "  Ten largest:"
  find "$efi" -type f -printf '%s %f\n' 2>/dev/null | sort -rn | head -10 | awk '{printf "    %8d B  %s\n", $1, $2}'
  dumps=$(find "$efi" -type f -iname 'dump-*' 2>/dev/null | wc -l)
  if [ "$dumps" -gt 0 ]; then flag "$dumps crash-dump variable(s) named dump-* are stored in NVRAM (left by the kernel's EFI pstore backend). They eat space; see docs/research.md."; fi
else
  echo "  efivarfs not mounted (sudo mount -t efivarfs efivarfs $efi)"
fi

echo
echo "== 3. pstore records (crash logs backed by NVRAM)"
if [ -d /sys/fs/pstore ] && [ -n "$(ls -A /sys/fs/pstore 2>/dev/null)" ]; then
  ls -l /sys/fs/pstore | sed 's/^/  /'
  flag "pstore holds records. If the backend is efi, they occupy NVRAM."
else
  echo "  none"
fi

echo
echo "== 4. Boot entries (efibootmgr)"
if have efibootmgr; then
  out=$(efibootmgr -v 2>&1) || { echo "  efibootmgr failed: $out"; out=""; }
  if [ -n "$out" ]; then
    echo "$out" | grep -E '^(Boot|Timeout)' | sed -E 's/^(Boot[0-9A-Fa-f]{4}\*? [^\t]*)\t(.{0,60}).*/\1  \2/; s/^/  /' | cut -c1-150
    order=$(echo "$out" | sed -n 's/^BootOrder: *//p' | tr ',' ' ')
    entries=$(echo "$out" | grep -cE '^Boot[0-9A-Fa-f]{4}')
    echo "  -> $entries boot entries"
    [ "$entries" -gt 8 ] && flag "$entries boot entries is a lot; stale ones from old installers/USB sticks are the usual culprit."
    for id in $(echo "$out" | grep -oE '^Boot[0-9A-Fa-f]{4}' | sed 's/Boot//'); do
      case " $order " in *" $id "*) ;; *) flag "Boot$id is not in BootOrder (candidate for removal): $(echo "$out" | grep "^Boot$id" | cut -c1-90)";; esac
    done
    dup=$(echo "$out" | grep -E '^Boot[0-9A-Fa-f]{4}' | sed -E 's/^Boot[0-9A-Fa-f]{4}\*? //' | sort | uniq -d)
    [ -n "$dup" ] && flag "Duplicate entries (same label and path): $(echo "$dup" | head -3 | cut -c1-80)"
  fi
else
  echo "  efibootmgr not installed (sudo apt install efibootmgr)"
fi

echo
if [ "$problems" -eq 0 ]; then
  echo "Result: no obvious sign of a crowded variable store. If you still see 'Volume Full', the shim/MOK variables themselves"
  echo "may be the problem (see docs/research.md, section 'Secure Boot key databases')."
else
  echo "Result: $problems item(s) flagged above. Next step: bash nvram-cleanup.sh   (dry run — changes nothing unless you add --apply)"
fi
