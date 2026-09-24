keyboard_read_char:
    ; Read one keyboard scancode and return its Finnish-layout character in AL.
    ; Return AL = 0 when no new key is ready or when a key is released.
    push ebx
    push edx

    mov dx, 0x64
    in al, dx
    test al, 0x01
    jz .none

    mov dx, 0x60
    in al, dx

    ; E0 prefixes identify extended keys, including Right Alt (AltGr).
    cmp al, 0xE0
    je .extended_prefix

    cmp byte [keyboard_extended], 0
    je .check_modifiers
    mov byte [keyboard_extended], 0
    cmp al, 0x38
    je .altgr_press
    cmp al, 0xB8
    je .altgr_release

.check_modifiers:
    cmp al, 0x2A
    je .shift_press
    cmp al, 0x36
    je .shift_press
    cmp al, 0xAA
    je .shift_release
    cmp al, 0xB6
    je .shift_release
    cmp al, 0x38
    je .altgr_press
    cmp al, 0xB8
    je .altgr_release

    test al, 0x80
    jnz .none

    movzx ebx, al
    cmp byte [keyboard_altgr], 0
    jne .use_altgr
    cmp byte [keyboard_shift], 0
    jne .use_shift
    mov al, [keyboard_map + ebx]
    jmp .done

.use_shift:
    mov al, [keyboard_map + ebx]
    cmp al, 'a'
    jb .shift_special
    cmp al, 'z'
    ja .shift_special
    sub al, 0x20
    jmp .done

.shift_special:
    mov al, [keyboard_shift_map + ebx]
    cmp al, 0
    jne .done
    mov al, [keyboard_map + ebx]
    cmp al, 0x84
    je .shift_a_umlaut
    cmp al, 0x86
    je .shift_a_ring
    cmp al, 0x94
    je .shift_o_umlaut
    jmp .done

.shift_a_umlaut:
    mov al, 0x8E
    jmp .done
.shift_a_ring:
    mov al, 0x8F
    jmp .done
.shift_o_umlaut:
    mov al, 0x99
    jmp .done

.use_altgr:
    mov al, [keyboard_altgr_map + ebx]
    jmp .done

.extended_prefix:
    mov byte [keyboard_extended], 1
    jmp .none

.shift_press:
    mov byte [keyboard_shift], 1
    jmp .none

.shift_release:
    mov byte [keyboard_shift], 0
    jmp .none

.altgr_press:
    mov byte [keyboard_altgr], 1
    jmp .none

.altgr_release:
    mov byte [keyboard_altgr], 0
    jmp .none

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

; Shifted Finnish punctuation. Letters are converted to uppercase in code.
keyboard_shift_map:
    db 0, 0, '!', '"', '#', 0xA4, '%', '&'
    db '/', '(', ')', '=', '?', '`', 0, 0
    db 'Q', 'W', 'E', 'R', 'T', 'Y', 'U', 'I'
    db 'O', 'P', 0x8F, 0, 0x0D, 0, 'A', 'S'
    db 'D', 'F', 'G', 'H', 'J', 'K', 'L', 0x99
    db 0x8E, '*', 0, '"', 'Z', 'X', 'C', 'V'
    db 'B', 'N', 'M', ';', ':', '_', 0, 0
    db 0, ' ', 0, 0, 0, 0, 0, 0
    times 22 db 0
    db '>'
    times 41 db 0

; Common Finnish AltGr combinations: @, currency, braces, brackets, and slash.
keyboard_altgr_map:
    db 0, 0, 0, '@', 0x9C, '$', 0, 0
    db '{', '[', ']', '}', '\\', 0, 0, 0
    times 112 db 0

keyboard_shift db 0
keyboard_altgr db 0
keyboard_extended db 0
