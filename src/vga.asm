vga_clear:
    ; VGA text memory starts at 0xB8000. Each cell has a character byte
    ; followed by a color byte. 0x0720 means a gray space on black.
    push eax
    push ecx
    push edi

    mov edi, 0xB8000
    mov ax, 0x0720
    mov ecx, 80 * 25
    rep stosw

    pop edi
    pop ecx
    pop eax
    ret

vga_write_titlebar:
    ; Paint the first row green with black characters, then write the title.
    push eax
    push ecx
    push edi
    push esi

    mov edi, 0xB8000
    mov ax, 0x2000
    mov ecx, 80
    rep stosw

    ; Start after half of the unused cells so the complete title is centered.
    mov edi, 0xB8000 + ((80 - titlebar_length) / 2) * 2
    mov esi, titlebar_text

.next_character:
    lodsb
    test al, al
    jz .done

    ; 0x20 means black text on a green background.
    mov ah, 0x20
    stosw
    jmp .next_character

.done:
    pop esi
    pop edi
    pop ecx
    pop eax
    ret

vga_write_string:
    ; Write the null-terminated string at ESI to the VGA address in EDI.
    push eax
    push esi
    push edi

.next_character:
    lodsb
    test al, al
    jz .done

    ; Keep this first writer simple: skip line-ending control characters.
    cmp al, 0x0D
    je .next_character
    cmp al, 0x0A
    je .next_character

    mov ah, 0x07
    stosw
    jmp .next_character

.done:
    pop edi
    pop esi
    pop eax
    ret
