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

    ; Print a success message to confirm the kernel actually started.
    mov esi, kernel_started
    call serial_write_string

    ; Stay here so the VM does not immediately reset of its own accord.
    jmp $

serial_init:
    ; Configure COM1 at port 0x3F8 for 8N1.
    mov dx, 0x3F8 + 3
    mov al, 0x80
    out dx, al

    mov dx, 0x3F8 + 0
    mov al, 0x03
    out dx, al

    mov dx, 0x3F8 + 1
    mov al, 0x00
    out dx, al

    mov dx, 0x3F8 + 3
    mov al, 0x03
    out dx, al

    mov dx, 0x3F8 + 2
    mov al, 0xC7
    out dx, al

    mov dx, 0x3F8 + 4
    mov al, 0x0B
    out dx, al
    ret

serial_write_char:
    ; Wait until the transmitter is empty before writing one byte.
    push eax
    push edx

    mov dx, 0x3F8 + 5
.wait:
    in al, dx
    test al, 0x20
    jz .wait

    pop edx
    pop eax
    mov dx, 0x3F8
    out dx, al
    ret

serial_write_string:
    ; Print a null-terminated string over COM1.
    push esi
.loop:
    lodsb
    or al, al
    jz .done
    call serial_write_char
    jmp .loop
.done:
    pop esi
    ret

kernel_started db 'Kernel entered protected mode', 0x0D, 0x0A, 0
