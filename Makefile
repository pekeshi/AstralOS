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

.PHONY: all run run-test clean

all: $(IMAGE)

$(BOOT): src/boot.asm
	@if not exist "$(BUILD)" mkdir "$(BUILD)"
	$(NASM) -f bin -o $@ $<

$(KERNEL): src/kernel.asm src/vga.asm src/serial.asm src/keyboard.asm src/shell.asm
	@if not exist "$(BUILD)" mkdir "$(BUILD)"
	$(NASM) -f bin -o $@ $<

$(IMAGE): $(BOOT) $(KERNEL)
	@if exist "$@" del /q "$@"
	copy /b build\boot.bin+build\kernel.bin build\astralos.img

run: $(IMAGE)
	$(QEMU) -fda $<

run-test: $(IMAGE)
	$(QEMU) -display none -serial stdio -fda $<

clean:
	@if exist "$(BUILD)" rmdir /s /q "$(BUILD)"
