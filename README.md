# AstralOS

A tiny x86 operating system boot sector that prints a message and halts.

## Build

```bash
nasm -f bin -o build/astralos.bin src/boot.asm
```

## Run

```bash
qemu-system-i386 -display none -serial stdio -fda build/astralos.bin
```

The boot sector loads at memory address 0x7c00 and prints:

```text
AstralOS booting...
```

## Notes

This is only a starting point. You can extend it with:

- a protected mode kernel
- a simple VGA or text console
- keyboard input
- memory management
- a basic shell
