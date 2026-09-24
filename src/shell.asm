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

    call shell_store_char
    call shell_put_char
    jmp .wait_for_key

.backspace:
    call shell_backspace
    jmp .wait_for_key

.enter:
    ; Put command output on the row below the command that was entered.
    call shell_move_to_newline
    call shell_execute_command
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

    dec dword [command_length]
    dec dword [cursor_x]
    mov al, ' '
    call shell_put_char
    dec dword [cursor_x]

.done:
    ret

shell_newline:
    ; Start a new input line and draw another prompt.
    call shell_move_to_newline
    mov al, '>'
    call shell_put_char
    mov al, ' '
    call shell_put_char
    ret

shell_move_to_newline:
    ; Move the cursor to the beginning of the next row without printing.
    inc dword [cursor_y]
    mov dword [cursor_x], 0
    ret

shell_store_char:
    ; Add AL to the command buffer, leaving room for a null terminator.
    push ebx

    mov ebx, [command_length]
    cmp ebx, COMMAND_BUFFER_SIZE - 1
    jae .done

    mov [command_buffer + ebx], al
    inc dword [command_length]

.done:
    pop ebx
    ret

shell_execute_command:
    ; Null-terminate the current command before comparing it.
    push eax
    push ebx
    push esi
    push edi

    mov ebx, [command_length]
    mov byte [command_buffer + ebx], 0

    ; Compare the input with "help".
    mov esi, command_buffer
    mov edi, help_command
.compare_help:
    mov al, [esi]
    cmp al, [edi]
    jne .check_clear
    test al, al
    jz .help
    inc esi
    inc edi
    jmp .compare_help

.help:
    mov esi, help_message
    call shell_write_message
    jmp .reset

.check_clear:
    mov esi, command_buffer
    mov edi, clear_command
.compare_clear:
    mov al, [esi]
    cmp al, [edi]
    jne .check_welcome
    test al, al
    jz .clear
    inc esi
    inc edi
    jmp .compare_clear

.clear:
    call shell_clear_screen
    jmp .reset

.check_welcome:
    mov esi, command_buffer
    mov edi, welcome_command
.compare_welcome:
    mov al, [esi]
    cmp al, [edi]
    jne .check_shutdown
    test al, al
    jz .welcome
    inc esi
    inc edi
    jmp .compare_welcome

.welcome:
    mov esi, welcome_message
    call shell_write_message
    jmp .reset

.check_shutdown:
    mov esi, command_buffer
    mov edi, shutdown_command
.compare_shutdown:
    mov al, [esi]
    cmp al, [edi]
    jne .unknown
    test al, al
    jz .shutdown
    inc esi
    inc edi
    jmp .compare_shutdown

.shutdown:
    call shell_shutdown

.unknown:
    mov esi, unknown_command_message
    call shell_write_message

.reset:
    mov dword [command_length], 0

    pop edi
    pop esi
    pop ebx
    pop eax
    ret

shell_write_message:
    ; Write a message using the shell cursor, without adding it to the buffer.
    push eax

.next_character:
    lodsb
    test al, al
    jz .done
    cmp al, 0x0D
    je .next_character
    cmp al, 0x0A
    je .next_character
    call shell_put_char
    jmp .next_character

.done:
    pop eax
    ret

shell_clear_screen:
    ; Clear the display and let shell_newline place the prompt on row 2.
    call vga_clear
    call vga_write_titlebar
    mov dword [cursor_x], 0
    mov dword [cursor_y], 0
    ret

shell_shutdown:
    ; Try ACPI power-off, then halt if firmware does not expose ACPI.
    mov esi, shutdown_message
    call shell_write_message
    call acpi_power_off
    jnc .halt_cpu

    mov esi, acpi_unavailable_message
    call shell_write_message
    call acpi_qemu_power_off

.halt_cpu:
    cli
.halt_loop:
    hlt
    jmp .halt_loop

cursor_x dd 2
cursor_y dd 1

COMMAND_BUFFER_SIZE equ 64
command_length dd 0
command_buffer times COMMAND_BUFFER_SIZE db 0

help_command db 'help', 0
help_message db 'Commands: help, clear, welcome, shutdown', 0
clear_command db 'clear', 0
welcome_command db 'welcome', 0
shutdown_command db 'shutdown', 0
shutdown_message db 'Shutting down...', 0
acpi_unavailable_message db ' ACPI unavailable; trying QEMU power-off.', 0
unknown_command_message db 'Unknown command.', 0