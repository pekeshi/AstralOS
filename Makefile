all: build/astralos.bin

build:
	@mkdir build

build/astralos.bin: src/boot.asm | build
	nasm -f bin -o $@ $<

run: build/astralos.bin
	qemu-system-i386 -fda $<

clean:
	rm -rf build

.PHONY: all run clean
