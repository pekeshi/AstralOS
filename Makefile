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
DISK_SIZE := 1474560
DISK_PADDING := 1465856

.PHONY: all run run-test clean

all: $(IMAGE)

$(BOOT): src/boot.asm
	@if not exist "$(BUILD)" mkdir "$(BUILD)"
	$(NASM) -f bin -o $@ $<

$(KERNEL): src/kernel.asm src/vga.asm src/serial.asm src/keyboard.asm src/acpi.asm src/shell.asm
	@if not exist "$(BUILD)" mkdir "$(BUILD)"
	$(NASM) -f bin -o $@ $<

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

clean:
	@if exist "$(BUILD)" rmdir /s /q "$(BUILD)"
