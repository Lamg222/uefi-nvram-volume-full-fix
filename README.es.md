# Ubuntu: «Could not create MokListRT: Volume Full» / «import_mok_state() failed»

Cómo diagnosticar y rodear el error de UEFI (el arranque moderno de las computadoras) que impide instalar o arrancar Ubuntu,
con scripts para Linux, Windows y macOS. Versión en inglés: [README.md](README.md).

## Qué significa

`shim` (el cargador pequeño con el que Ubuntu arranca primero) escribe sus variables de llaves en la **memoria de variables del firmware**
(NVRAM, la memoria diminuta de la placa madre donde se guardan las entradas de arranque). Muchas laptops tienen una memoria de decenas o pocos cientos de KiB.
Si está llena, la escritura falla con `Volume Full` y el arranque se detiene. **No** es falta de espacio en el disco.

Lo que la llena: entradas de arranque viejas de instaladores y memorias USB, volcados de fallos que guarda el núcleo (`efi-pstore`) y,
en algunos equipos, las listas grandes de llaves de Secure Boot (la lista `dbx` sola puede pesar ~23 KiB). Fuentes: [docs/research.md](docs/research.md).

## Camino rápido

1. **Mirar primero (no cambia nada).** Con el sistema instalado o con un USB de Ubuntu en modo «Probar Ubuntu»:
   `sudo bash scripts/linux/nvram-diagnose.sh`
2. **Liberar espacio.** Por defecto solo simula; con `--apply` lo hace, guardando antes una copia:
   `sudo bash scripts/linux/nvram-cleanup.sh` y luego `... --apply`
3. **¿Sigue fallando y Secure Boot está APAGADO?** Arranca GRUB directo, sin shim:
   `sudo bash scripts/linux/nvram-cleanup.sh --direct-grub --apply`
   Esto fue lo que resolvió el caso de [docs/case-study.md](docs/case-study.md). Con Secure Boot ENCENDIDO el firmware lo rechaza.
4. **Revisar la memoria USB** antes de arrancar con ella:
   - macOS / Linux: `bash scripts/usb/check-usb.sh /ruta/a/la/usb --iso ubuntu.iso --sha256 <hash de ubuntu.com>`
   - Windows: `powershell -ExecutionPolicy Bypass -File scripts\usb\check-usb.ps1 -Drive E: -Iso C:\ubuntu.iso -Sha256 <hash>`
   Si hay archivos `boot*.efi` de más en `EFI/BOOT` (visto tras grabar con Rufus), `--fix` / `-Fix` los renombra a `*.disabled` (reversible).

En Windows, `scripts\windows\nvram-diagnose.ps1` (PowerShell como administrador) lista las entradas y el estado de Secure Boot, pero la limpieza
confiable se hace desde un USB de Ubuntu.

## Qué se probó y qué no

Probado en una laptop Ubuntu 26.04 de 2017 con UEFI y Secure Boot apagado: el diagnóstico y la simulación de limpieza. La entrada de GRUB directo se creó a mano con
`efibootmgr` y el script automatiza esos pasos, pero **su modo `--apply` aún no se corrió completo**. `check-usb` se probó con memorias de mentira en Linux y Windows;
`nvram-diagnose.ps1` solo en sintaxis; macOS sin probar. Los reportes de otros equipos ayudan mucho: abre un issue.

## Seguridad

Los scripts no tocan discos ni particiones. Con `--apply` solo borran entradas de arranque/registros pstore y agregan una entrada, tras guardar una copia
(deshacer: `efibootmgr -b <id> -B`). Licencia MIT.
