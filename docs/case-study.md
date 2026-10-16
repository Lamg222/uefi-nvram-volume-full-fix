# Case study: Ubuntu 26.04 next to Windows on a 2017 laptop

Anonymised on purpose: no names, addresses or credentials.

## Machine

Intel i7-7500U laptop, 16 GB RAM, 1 TB SATA SSD, UEFI firmware, Windows already installed. Goal: Ubuntu alongside Windows, then use it as a home server.

## What happened

1. **Installer would not start cleanly.** The Ubuntu stick was written with Rufus. Its `EFI/BOOT` folder held two `boot*.efi` files
   (the usual `bootx64.efi` plus an extra `bootx64-shim-original.efi`). After renaming the extra one to `shim-original-rufus.efi`
   (any non-`boot*.efi` name works), the installer ran. *Observed once; the research found no documented cause, so treat it as a lead, not a rule.*
2. **Install finished, first boot of Ubuntu printed** `Could not create MokListRT: Volume Full` and stopped.
3. **Diagnosis** (the same checks `nvram-diagnose.sh` now does):
   - Secure Boot: **disabled**.
   - Variable store: only **75 variables / 51 KiB**, of which the `dbx` list was 23 KiB, `db` 6 KiB, `KEK`/`PK` a few KiB, plus the `*Default` copies of each.
   - Only 3 boot entries, no pstore dumps. So it was **not** a crowded entry list: the firmware's store is simply tiny and the key databases occupy most of it.
4. **Fix.** Add a boot entry that starts GRUB directly (skipping shim, which is what writes the `Mok*` variables) and put it first in `BootOrder`:
   ```bash
   sudo efibootmgr -c -d /dev/sda -p 1 -L "Ubuntu (GRUB direct)" -l '\EFI\ubuntu\grubx64.efi'
   ```
   The original shim entry stays as a second option. From then on the machine boots Ubuntu by default; Windows is reached from the firmware's one-time boot menu.
   This only works because Secure Boot was off.

## Side note: resizing the Windows partition

The Windows partition was resized with `ntfsresize` from Linux, and Windows then ran an automatic disk check on its first boot.
That is expected after a resize; do not interrupt it.

## Remote repair over SSH

After the first successful boot the rest (packages, services, config) was done from another computer over SSH with key-based login.
If a machine can boot even partly, doing the follow-up remotely saves moving a monitor and keyboard around.
