# Research notes: why "Volume Full" happens and what actually helps

Method: web searches in October 2026. Findings below come from the search result summaries and the pages' own titles;
several pages (for example the Slimbook guide) refused automated fetching, so **I did not read every page in full**. Confidence is given per claim.

## 1. The variable store is small and shim writes to it every boot

- Reports across Linux Mint, Red Hat, Fedora and Solus show the same message cluster (`MokListRT`, `MokListXRT`, `SbatLevelRT`, `MokListTrustedRT`, then `import_mok_state() failed: Volume Full`).
- A Unix & Linux Stack Exchange answer says the firmware's space reserved for Secure Boot key variables is full, and that Windows and BIOS updates tend to add entries over time.
- A U-Boot change doubled the default variable store size for a similar failure and points to a shim error-handling bug (shim PR 577) as related.
- Confidence: **high** that the store is full (the error text says it); **moderate** on which items fill it, because it varies by machine.

## 2. What fills the store

| Cause | Evidence | Fix | Confidence |
|---|---|---|---|
| Stale boot entries (old installers, USB sticks) | forum threads suggest `efibootmgr -b XXXX -B`; users report it freed space | `nvram-cleanup.sh` | moderate |
| Crash dumps from the kernel's EFI pstore backend (`dump-type0-*` variables) | Arch bug FS#70140: pstore can fill EFI storage, block booting and bootloader installs. Guix proposed disabling the backend by default | remove files in `/sys/fs/pstore` (done by `nvram-cleanup.sh`); to prevent: kernel argument `efi_pstore.pstore_disable=1` | moderate-high |
| Large Secure Boot key lists (`dbx` was 23 KiB in our case) | Unix SE answer; Fedora thread tied the error to a dbx update | reset keys to Setup Mode / restore firmware defaults (loses custom keys), or prune dbx | moderate |

## 3. Options when Secure Boot must stay ON

1. Firmware setup → *Restore factory defaults* / *Reset to Setup Mode* / *Clear keys*. Slimbook's guide says a factory reset clears the EFI boot entries; afterwards re-enable Secure Boot and Quick Boot as needed. Cost: custom keys and settings are lost. (Source summary only.)
2. Delete stale entries with `efibootmgr` (script).
3. One Linux Mint user suggested `mokutil --disable-validation`; it changes how shim validates keys and **does not free NVRAM**, so it is not a fix for `Volume Full` itself. (Single anecdote.)
4. A SUSE shim patch lets shim keep booting when mirroring MOK variables fails, because firmware free-space reports proved unreliable. That patch addresses "Out of Resources", not "Volume Full", so it may not apply. (Stated in the commit text found via search.)

## 4. What is *not* supported by the research

- That Rufus's extra `boot*.efi` is a general cause of installer failure. One search found nothing documenting it; one forum thread about "missing 2 files" was resolved by switching to Rufus, no cause given. The check in `check-usb.sh` is based on one real case.
- Manual deletion of `dump-type0-*` through `efivarfs`: no source documents a supported command. The scripts instead remove pstore records, the kernel's own interface.
- Defragmenting NVRAM from the EFI shell (`dmpstore`): one write-up exists ([artemis.sh](https://artemis.sh/2025/02/22/uefi-nvram-defrag.html)); the author warns it can brick a machine. Not automated here.

## Sources

- Slimbook: [FIX: Something has gone seriously wrong: import_mok_state() failed: Volume Full](https://slimbook.com/en/blog/guides-2/post/fix-error-something-has-gone-seriously-wrong-import-mok-state-failed-volume-full-413)
- Linux Mint forums: [import_moks_state() failed: Volume Full after interrupted installation](https://forums.linuxmint.com/viewtopic.php?t=435082) · [Could not create MokListRT: Volume Full](https://forums.linuxmint.com/viewtopic.php?t=456989)
- Malekal forum: [MoklistRT: Volume Full](https://forum.malekal.com/viewtopic.php?t=75080)
- Unix & Linux SE (mirror): [could not create moklistrt volume full when trying to boot almost any distro](https://kompas.wasmer.app/https_unix_stackexchange_com/questions/774195/could-not-create-moklistrt-volume-full-etc-when-trying-to-boot-almost-any-distr)
- Fedora Discussion: [F38 Secure Boot dbx Configuration Update Error](https://discussion.fedoraproject.org/t/f38-secure-boot-dbx-configuration-update-error/84582)
- Red Hat Jira: [RHEL-83321](https://issues.redhat.com/browse/RHEL-83321)
- Arch Linux bug tracker: [FS#70140 pstore can fill EFI storage](https://bugs.archlinux.org/task/70140)
- Guix: [Disable EFI pstore backend by default](https://issues.guix.gnu.org/75808)
- artemis.sh: [Defragging my old Dell's UEFI NVRAM](https://artemis.sh/2025/02/22/uefi-nvram-defrag.html)
- Rocky Linux shim commit (SUSE patch): [shim-unsigned-x64 8faaf3c](https://git.rockylinux.org/staging/rpms/shim-unsigned-x64/-/commit/8faaf3cf03d074ddd51d30d21f23cd784559a21c)
- U-Boot variable store size change: [Kconfig commit](https://git.org.ru/Djam/u-boot/src/commit/def898c458e65a71fb64cda370b4281cd026e48c/lib/efi_loader/Kconfig)
