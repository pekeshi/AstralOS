# AstralOS

A small x86 operating-system prototype written in NASM assembly. AstralOS currently
boots through a BIOS boot sector, loads a 32-bit protected-mode kernel, and draws a
basic VGA text interface.

The project is currently a bootable OS prototype, not yet a complete operating
system or interactive shell.

## Current Features

- 16-bit BIOS bootloader
- Kernel loading from a BIOS disk image using INT 13h extensions, with CHS fallback
- x86-64 UEFI bootloader and FAT16 UEFI disk image
- 32-bit protected-mode transition using a GDT
- COM1 serial output for debugging
- 80x25 VGA text output
- Green title bar with centered `AstralOS - 0.1.0 - pekeshi` text
- Static `> ` shell prompt

The prompt is display-only at the moment. Keyboard input, command parsing,
memory management, interrupts, and filesystem support are not implemented yet.

## Project Layout

```text
src/boot.asm    BIOS bootloader and protected-mode transition
src/uefi.asm    x86-64 UEFI loader and protected-mode transition
src/kernel.asm  32-bit kernel entry and VGA/serial output
tools/          UEFI FAT image generator
Makefile        Build, run, and clean targets
build/          Generated binaries and disk image
```

## Requirements

- NASM
- GNU Make
- Python 3
- WSL with GNU binutils (`ld`)
- QEMU with `qemu-system-i386`

On Windows, run these commands from PowerShell in the project directory.

## Build

```bash
make clean
make
```

The build creates:

- `build/boot.bin` - the 512-byte boot sector
- `build/kernel.bin` - the raw kernel binary
- `build/astralos.img` - a 1.44 MiB BIOS-bootable disk image
- `build/astralos-uefi.img` - a 16 MiB FAT16 UEFI disk image
- `build/BOOTX64.EFI` - the x86-64 UEFI boot application

To build the UEFI image:

```bash
make uefi
```

## Run

Start QEMU with VGA output:

```text
make run
```

The screen currently shows a title bar, kernel startup text, and a static prompt.

For serial-only testing and boot diagnostics:

```text
make run-test
```

To run the UEFI image in QEMU:

```text
make run-uefi
```

The serial output should include:

```text
Loading AstralOS kernel...
Kernel loaded. Switching to protected mode...
Welcome to AstralOS, type help to get a list of the commands.
```

## Real hardware

For legacy BIOS/CSM systems, write `build/astralos.img` to a USB drive as a
raw disk image. For UEFI systems, write `build/astralos-uefi.img` instead. Use
a tool such as Rufus or balenaEtcher and select the matching firmware boot
entry. The UEFI image contains the standard `EFI/BOOT/BOOTX64.EFI` path.

## Roadmap

The next planned stages are:

- keyboard input from the PS/2 controller
- an interactive VGA cursor and input line
- command parsing
- basic shell commands
- interrupt handling
- memory management
- filesystem support
