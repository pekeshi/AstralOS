[org 0x7c00]
bits 16

start:
    cli
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7c00
    sti

    mov si, msg
    call print_string

hang:
    hlt
    jmp hang

print_string:
    pusha

.loop:
    lodsb
    or al, al
    jz .done

    mov ah, 0x0e
    mov bx, 0x0007
    int 0x10
    jmp .loop

.done:
    popa
    ret

msg db 'AstralOS booting...', 0x0d, 0x0a, 0

; Pad the boot sector to 510 bytes and add the boot signature.
times 510 - ($ - $$) db 0
dw 0xAA55
