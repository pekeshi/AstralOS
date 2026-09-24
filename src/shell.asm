shell_loop:
    ; Poll the keyboard and draw each typed character after the prompt.
.wait_for_key:
    call keyboard_read_char
    test al, al
    jz .wait_for_key

    cmp al, 0x08
    je .backspace
    cmp al, 0x0D
    je .enter

    call shell_put_char
    jmp .wait_for_key

.backspace:
    call shell_backspace
    jmp .wait_for_key

.enter:
    call shell_newline
    jmp .wait_for_key

shell_put_char:
    ; Draw AL at the current cursor position and move the cursor right.
    push eax
    push ebx
    push edx
    push edi

    mov eax, [cursor_y]
    imul eax, 80
    add eax, [cursor_x]
    shl eax, 1
    mov edi, 0xB8000
    add edi, eax

    mov eax, [esp + 12]
    mov ah, 0x07
    stosw

    inc dword [cursor_x]
    cmp dword [cursor_x], 80
    jb .done
    mov dword [cursor_x], 0
    inc dword [cursor_y]

.done:
    pop edi
    pop edx
    pop ebx
    pop eax
    ret

shell_backspace:
    ; Erase the previous character, but never erase the '> ' prompt.
    cmp dword [cursor_x], 2
    jbe .done

    dec dword [cursor_x]
    mov al, ' '
    call shell_put_char
    dec dword [cursor_x]

.done:
    ret

shell_newline:
    ; Start a new input line and draw another prompt.
    inc dword [cursor_y]
    mov dword [cursor_x], 0
    mov al, '>'
    call shell_put_char
    mov al, ' '
    call shell_put_char
    ret

cursor_x dd 2
cursor_y dd 2