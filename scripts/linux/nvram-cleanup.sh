#!/usr/bin/env bash
# nvram-cleanup.sh — free UEFI variable space and/or work around shim's "Volume Full".
# DRY RUN by default: it only prints what it would do. Add --apply to really do it.
#
#   sudo bash nvram-cleanup.sh                      # show the plan
#   sudo bash nvram-cleanup.sh --apply              # remove pstore records + stale boot entries
#   sudo bash nvram-cleanup.sh --direct-grub --apply  # also add a boot entry that starts GRUB directly (skips shim)
#
# --direct-grub only works with Secure Boot DISABLED: without shim, the firmware must trust GRUB's signature itself.
# Every change is preceded by a backup of the boot configuration in ./nvram-backup-<date>/.
set -u

APPLY=0; DIRECT=0; FORCE=0
for a in "$@"; do
  case "$a" in
    --apply) APPLY=1 ;;
    --direct-grub) DIRECT=1 ;;
    --force) FORCE=1 ;;
    -h|--help) sed -n '2,12p' "$0"; exit 0 ;;
    *) echo "Unknown option: $a"; exit 2 ;;
  esac
done

[ -d /sys/firmware/efi ] || { echo "Not booted in UEFI mode. Nothing to do."; exit 1; }
[ "$(id -u)" -eq 0 ] || { echo "Run as root: sudo bash $0 $*"; exit 1; }
command -v efibootmgr >/dev/null || { echo "Install efibootmgr first: apt install efibootmgr"; exit 1; }

run() { if [ "$APPLY" -eq 1 ]; then echo "  + $*"; "$@"; else echo "  (dry run) $*"; fi; }

backup="nvram-backup-$(date +%Y%m%d-%H%M%S)"
echo "== Backup"
if [ "$APPLY" -eq 1 ]; then
  mkdir -p "$backup"
  efibootmgr -v > "$backup/efibootmgr.txt"
  [ -d /sys/fs/pstore ] && cp -a /sys/fs/pstore "$backup/pstore" 2>/dev/null
  echo "  saved to $backup/"
else
  echo "  (dry run) would save efibootmgr output and pstore records to ./$backup/"
fi

echo "== 1. pstore records stored in NVRAM"
if [ -d /sys/fs/pstore ] && [ -n "$(ls -A /sys/fs/pstore 2>/dev/null)" ]; then
  for f in /sys/fs/pstore/*; do run rm -f -- "$f"; done   # removing a pstore file erases the backing EFI variable
else
  echo "  none"
fi

echo "== 2. Stale boot entries (not in BootOrder, not the current/next boot)"
out=$(efibootmgr)
order=$(echo "$out" | sed -n 's/^BootOrder: *//p' | tr ',' ' ')
cur=$(echo "$out" | sed -n 's/^BootCurrent: *//p')
next=$(echo "$out" | sed -n 's/^BootNext: *//p')
found=0
for id in $(echo "$out" | grep -oE '^Boot[0-9A-Fa-f]{4}' | sed 's/Boot//'); do
  case " $order $cur $next " in *" $id "*) continue ;; esac
  echo "  Boot$id: $(echo "$out" | grep "^Boot$id" | cut -c1-80)"
  run efibootmgr -b "$id" -B
  found=1
done
[ "$found" -eq 0 ] && echo "  none"

if [ "$DIRECT" -eq 1 ]; then
  echo "== 3. Direct GRUB boot entry (bypasses shim, so no MokListRT write)"
  sb=$(mokutil --sb-state 2>/dev/null)
  if echo "$sb" | grep -qi "enabled" && [ "$FORCE" -eq 0 ]; then
    echo "  Secure Boot is ENABLED. A direct GRUB entry would be refused by the firmware."
    echo "  Disable Secure Boot in the firmware setup first, or use the Secure Boot options in docs/research.md. (--force skips this check.)"
    exit 3
  fi
  esp=$(findmnt -n -o SOURCE /boot/efi 2>/dev/null)
  if [ -z "$esp" ]; then echo "  /boot/efi is not mounted — mount the EFI System Partition first."; exit 4; fi
  disk="/dev/$(lsblk -no PKNAME "$esp")"
  part=$(cat "/sys/class/block/$(basename "$esp")/partition")
  loader='\EFI\ubuntu\grubx64.efi'
  [ -e /boot/efi/EFI/ubuntu/grubx64.efi ] || { echo "  $loader not found on the ESP."; exit 5; }
  if echo "$out" | grep -qi 'GRUB direct'; then
    echo "  An entry labelled 'GRUB direct' already exists — skipping."
  else
    run efibootmgr -c -d "$disk" -p "$part" -L "Ubuntu (GRUB direct)" -l "$loader"
    if [ "$APPLY" -eq 1 ]; then
      new=$(efibootmgr | grep -i 'GRUB direct' | grep -oE '^Boot[0-9A-Fa-f]{4}' | sed 's/Boot//' | head -1)
      rest=$(efibootmgr | sed -n 's/^BootOrder: *//p' | tr ',' '\n' | grep -v "^$new$" | paste -sd,)
      efibootmgr -o "$new${rest:+,$rest}" >/dev/null && echo "  new entry Boot$new is now first in BootOrder"
    fi
  fi
fi

echo
[ "$APPLY" -eq 1 ] && echo "Done. Reboot and check that the machine starts. Undo: efibootmgr -b <id> -B, or restore from $backup/." \
                   || echo "Dry run finished. Nothing was changed. Re-run with --apply to do it."
