# Makefile for building and running the AstralOS operating system
NASM := nasm
QEMU := qemu-system-i386
BOOT := build/boot.bin
KERNEL := build/kernel.bin
IMAGE := build/astralos.img

# Target to build the bootloader, kernel, and create the disk image
all: $(IMAGE)

# Target to build the bootloader from assembly source
$(BOOT): src/boot.asm
	@powershell -NoProfile -Command "if (!(Test-Path 'build')) { New-Item -ItemType Directory -Force -Path 'build' | Out-Null }"
	$(NASM) -f bin -o $@ $<

# Target to build the kernel from assembly source
$(KERNEL): src/kernel.asm
	@powershell -NoProfile -Command "if (!(Test-Path 'build')) { New-Item -ItemType Directory -Force -Path 'build' | Out-Null }"
	$(NASM) -f bin -o $@ $<

# Target to create the disk image by combining the bootloader and kernel
$(IMAGE): $(BOOT) $(KERNEL)
	@powershell -NoProfile -Command "$$boot = [System.IO.File]::ReadAllBytes('build/boot.bin'); $$kernel = [System.IO.File]::ReadAllBytes('build/kernel.bin'); $$total = 512 + $$kernel.Length; if ($$boot.Length -ne 512) { throw 'Boot sector size is not 512 bytes.' }; $$img = New-Object byte[] $$total; [System.Array]::Copy($$boot, 0, $$img, 0, $$boot.Length); [System.Array]::Copy($$kernel, 0, $$img, 512, $$kernel.Length); [System.IO.File]::WriteAllBytes('build/astralos.img', $$img)"

# Target to run the operating system in QEMU
run: $(IMAGE)
	$(QEMU) -fda $<

run-test: $(IMAGE)
	$(QEMU) -display none -serial stdio -fda $<

# Target to clean up the build artifacts
clean:
	@powershell -NoProfile -Command "if (Test-Path 'build') { Remove-Item -Recurse -Force 'build' }"

# Phony targets to avoid conflicts with files of the same nameÖ
.PHONY: all run clean
