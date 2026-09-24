# AstralOS build file for GNU Make on Windows.
# Recipes use native cmd.exe commands.

SHELL := cmd.exe
.SHELLFLAGS := /C

NASM := nasm
QEMU := qemu-system-i386
BUILD := build
BOOT := $(BUILD)/boot.bin
KERNEL := $(BUILD)/kernel.bin
IMAGE := $(BUILD)/astralos.img
UEFI_KERNEL := $(BUILD)/kernel-uefi.bin
UEFI_OBJ := $(BUILD)/uefi.obj
UEFI_APP := $(BUILD)/BOOTX64.EFI
UEFI_IMAGE := $(BUILD)/astralos-uefi.img
DISK_SIZE := 1474560
DISK_PADDING := 1465856
WSL_ROOT := $(shell wsl.exe wslpath -a "$(CURDIR)")

.PHONY: all uefi run run-test run-uefi clean

all: $(IMAGE)

$(BOOT): src/boot.asm
	@if not exist "$(BUILD)" mkdir "$(BUILD)"
	$(NASM) -f bin -o $@ $<

$(KERNEL): src/kernel.asm src/vga.asm src/serial.asm src/keyboard.asm src/acpi.asm src/shell.asm
	@if not exist "$(BUILD)" mkdir "$(BUILD)"
	$(NASM) -f bin -o $@ $<

$(UEFI_KERNEL): src/kernel.asm src/vga.asm src/serial.asm src/keyboard.asm src/acpi.asm src/shell.asm
	@if not exist "$(BUILD)" mkdir "$(BUILD)"
	$(NASM) -f bin -dKERNEL_ORG=0x100000 -o $@ $<

$(UEFI_OBJ): src/uefi.asm $(UEFI_KERNEL)
	@if not exist "$(BUILD)" mkdir "$(BUILD)"
	$(NASM) -f win64 -o $@ $<

$(UEFI_APP): $(UEFI_OBJ)
	wsl.exe ld -mi386pep --subsystem 10 --entry efi_main --image-base 0x400000 -o "$(WSL_ROOT)/$(UEFI_APP)" "$(WSL_ROOT)/$(UEFI_OBJ)"

uefi: $(UEFI_IMAGE)

$(UEFI_IMAGE): $(UEFI_APP) $(UEFI_KERNEL) tools/make_uefi_image.py requirements.txt
	python tools/make_uefi_image.py "$@" "$(UEFI_APP)" "$(UEFI_KERNEL)"

$(IMAGE): $(BOOT) $(KERNEL)
	@if exist "$@" del /q "$@"
	@if exist "$(BUILD)\padding.bin" del /q "$(BUILD)\padding.bin"
	fsutil file createnew "$(BUILD)\padding.bin" $(DISK_PADDING)
	copy /b build\boot.bin+build\kernel.bin+build\padding.bin "$@"
	@if not "$(DISK_SIZE)"=="" fsutil file seteof "$@" $(DISK_SIZE)

run: $(IMAGE)
	$(QEMU) -fda $<

run-test: $(IMAGE)
	$(QEMU) -display none -serial stdio -fda $<

run-uefi: $(UEFI_IMAGE)
	qemu-system-x86_64 -drive if=pflash,format=raw,readonly=on,file="C:/msys64/mingw64/share/qemu/edk2-x86_64-code.fd" -drive if=none,id=astralos-usb,format=raw,file=$< -device qemu-xhci,id=xhci -device usb-storage,bus=xhci.0,drive=astralos-usb -serial stdio

clean:
	@if exist "$(BUILD)" rmdir /s /q "$(BUILD)"
