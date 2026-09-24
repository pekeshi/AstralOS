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
