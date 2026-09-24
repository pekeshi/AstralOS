keyboard_read_char:
    ; Read one keyboard scancode and return its character in AL.
    ; Return AL = 0 when no new key is ready or when a key is released.
    push ebx
    push edx

    mov dx, 0x64
    in al, dx
    test al, 0x01
    jz .none

    mov dx, 0x60
    in al, dx
    test al, 0x80
    jnz .none

    movzx ebx, al
    mov al, [keyboard_map + ebx]
    jmp .done

.none:
    xor al, al

.done:
    pop edx
    pop ebx
    ret

; Finnish keyboard layout, using Set 1 keyboard scancodes.
; VGA codes 0x84, 0x86, and 0x94 display ä, å, and ö.
keyboard_map:
    db 0, 0, '1', '2', '3', '4', '5', '6'
    db '7', '8', '9', '0', '-', '+', 0x08, 0
    db 'q', 'w', 'e', 'r', 't', 'y', 'u', 'i'
    db 'o', 'p', 0x86, 0, 0x0D, 0, 'a', 's'
    db 'd', 'f', 'g', 'h', 'j', 'k', 'l', 0x94
    db 0x84, 0x27, 0, '*', 'z', 'x', 'c', 'v'
    db 'b', 'n', 'm', ',', '.', '-', 0, 0
    db 0, ' ', 0, 0, 0, 0, 0, 0
    times 22 db 0
    db '<'
    times 41 db 0
