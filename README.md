# Ubuntu: "Could not create MokListRT: Volume Full" / "import_mok_state() failed"

Diagnose and work around the UEFI error that stops Ubuntu (and other shim-based distros) from installing or booting,
with scripts for Linux, Windows and macOS. Spanish version: [README.es.md](README.es.md).

```
Could not create MokListRT: Volume Full
Something has gone seriously wrong: import_mok_state() failed: Volume Full
```

## What it means

`shim` (the small Secure Boot loader Ubuntu starts first) tries to write its key variables (`MokListRT`, `MokListXRT`, …)
into the firmware's **variable store** (NVRAM) at every boot. Many laptops have a very small store (tens to a few hundred KiB).
When it is full, the write fails with `Volume Full` and boot stops. This is **not** a disk-space problem.

What fills it: leftover boot entries from old installers and USB sticks, crash dumps stored by the kernel's `efi-pstore`,
and, on some machines, large Secure Boot key lists (the `dbx` list alone can be ~23 KiB). Details and sources: [docs/research.md](docs/research.md).

## Quick path

1. **Look first (changes nothing).** Boot the installed system or an Ubuntu live USB ("Try Ubuntu"):
   ```bash
   sudo bash scripts/linux/nvram-diagnose.sh
   ```
2. **Free space.** Dry run by default; `--apply` does it, after saving a backup:
   ```bash
   sudo bash scripts/linux/nvram-cleanup.sh            # shows the plan
   sudo bash scripts/linux/nvram-cleanup.sh --apply    # removes pstore records and boot entries not in BootOrder
   ```
3. **Still failing and Secure Boot is OFF?** Boot GRUB directly and skip shim:
   ```bash
   sudo bash scripts/linux/nvram-cleanup.sh --direct-grub --apply
   ```
   This adds an entry for `\EFI\ubuntu\grubx64.efi` and puts it first. It is what fixed the case in [docs/case-study.md](docs/case-study.md).
   With Secure Boot ON the firmware refuses an unsigned-by-its-keys GRUB; use the firmware options in the research notes instead.
4. **Check the USB stick** before booting from it (macOS / Linux / Windows):
   ```bash
   bash scripts/usb/check-usb.sh /media/you/UBUNTU --iso ubuntu.iso --sha256 <hash-from-ubuntu.com>
   ```
   ```powershell
   powershell -ExecutionPolicy Bypass -File scripts\usb\check-usb.ps1 -Drive E: -Iso C:\ubuntu.iso -Sha256 <hash>
   ```
   If the stick has extra `boot*.efi` files in `EFI/BOOT` (seen after writing with Rufus), `--fix` / `-Fix` renames them to `*.disabled`.

On Windows, `scripts\windows\nvram-diagnose.ps1` (Administrator PowerShell) lists firmware entries and Secure Boot state. It cannot clean the store reliably; do that from an Ubuntu live USB.

## Documentation

- [docs/case-study.md](docs/case-study.md): the real case, step by step (anonymised).
- [docs/research.md](docs/research.md): causes, options when Secure Boot must stay on, what is and is not supported, sources.

## What was tested

| Piece | Tested on |
|---|---|
| `nvram-diagnose.sh`, `nvram-cleanup.sh` (dry run, `--direct-grub`) | Ubuntu 26.04 on a 2017 laptop (Intel i7-7500U), UEFI, Secure Boot off |
| `nvram-cleanup.sh --apply` | the same direct-GRUB entry was created by hand with `efibootmgr`; the script automates those steps but **its `--apply` path has not been run end to end yet** |
| `check-usb.sh` | Linux, with a mock stick |
| `check-usb.ps1` | Windows 11, with a mock stick |
| `nvram-diagnose.ps1` | syntax check only; not yet run as Administrator on real firmware |
| macOS | not tested (the bash script uses only `find`, `ls`, `shasum`); Macs do not use this UEFI path, so only the USB check applies |

Reports, fixes and results from other hardware are welcome as issues.

## Safety

- Scripts never touch disks or partitions. They read UEFI variables and, only with `--apply`, delete boot entries/pstore records and add one boot entry.
- A backup of `efibootmgr -v` and pstore records is written before any change. Undo: `efibootmgr -b <id> -B`.
- Deleting firmware variables by hand (outside `efibootmgr`/pstore) can brick some machines; these scripts do not do that.

MIT licensed.
