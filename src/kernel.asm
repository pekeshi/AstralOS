[org 0x1000]
bits 32

start:
    cli

    ; Set the segment registers for a valid 32-bit protected-mode environment.
    mov ax, 0x10
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax
    mov esp, 0x90000

    ; Initialize COM1 so we can see debug output in QEMU serial output.
    call serial_init

    ; Print the welcome message to the serial console.
    mov esi, welcome_message
    call serial_write_string

    ; Draw the VGA interface and place the first shell prompt.
    call vga_clear
    call vga_write_titlebar
    mov edi, 0xB80A0
    mov esi, prompt_text
    call vga_write_string

    ; Start the polling shell loop. It returns one character at a time.
    call shell_loop

    ; The shell loop should never return, but keep a safe halt here.
    jmp $

; Keep each subsystem in its own source file while producing one flat binary.
%include "src/vga.asm"
%include "src/serial.asm"
%include "src/keyboard.asm"
%include "src/acpi.asm"
%include "src/shell.asm"

titlebar_text db 'AstralOS - 0.1.0 - pekeshi', 0
titlebar_length equ $ - titlebar_text - 1
welcome_message db 'Welcome to AstralOS, type help to get a list of the commands.', 0x0D, 0x0A, 0
prompt_text db '> ', 0
