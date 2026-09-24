# AstralOS

A small x86 operating-system prototype written in NASM assembly. AstralOS currently
boots through a BIOS boot sector, loads a 32-bit protected-mode kernel, and draws a
basic VGA text interface.

The project is currently a bootable OS prototype, not yet a complete operating
system or interactive shell.

## Current Features

- 16-bit BIOS bootloader
- Kernel loading from a BIOS disk image using INT 13h extensions, with CHS fallback
- 32-bit protected-mode transition using a GDT
- COM1 serial output for debugging
- 80x25 VGA text output
- Green title bar with centered `AstralOS - 0.1.0 - pekeshi` text
- PS/2 keyboard input with an interactive `> ` shell prompt
- Basic shell commands: `help`, `clear`, `welcome`, and `shutdown`

The shell is still intentionally minimal. Memory management, interrupts, and
filesystem support are not implemented yet.

## Project Layout

```text
src/boot.asm    BIOS bootloader and protected-mode transition
src/kernel.asm  32-bit kernel entry and subsystem includes
src/vga.asm     VGA text-mode output
src/serial.asm  COM1 serial output
src/keyboard.asm PS/2 keyboard input
src/acpi.asm    ACPI and QEMU power-off support
src/shell.asm   Interactive shell and command handling
Makefile        Build, run, and clean targets
build/          Generated binaries and disk image
```

## Requirements

- NASM
- GNU Make
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

## Run

Start QEMU with VGA output:

```text
make run
```

The screen shows a title bar, kernel startup text, and an interactive prompt.

For serial-only testing and boot diagnostics:

```text
make run-test
```

The serial output should include:

```text
Loading AstralOS kernel...
Kernel loaded. Switching to protected mode...
Welcome to AstralOS, type help to get a list of the commands.
```

At the VGA prompt, enter `help` to list the available commands. `shutdown`
attempts to power off QEMU through ACPI.

## Real hardware

For legacy BIOS/CSM systems, write `build/astralos.img` to a USB drive as a
raw disk image. Use a tool such as Rufus or balenaEtcher and select the legacy
BIOS boot option.

## Roadmap

The next planned stages are:

- command history and improved line editing
- interrupt handling
- memory management
- filesystem support
