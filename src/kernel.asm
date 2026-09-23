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

    ; Clear VGA text memory and display the startup message on screen.
    call vga_clear
    call vga_write_titlebar
    mov edi, 0xB80A0
    mov esi, kernel_started
    call vga_write_string

    ; Put the shell prompt on the third row, ready for future keyboard input.
    mov edi, 0xB8140
    mov esi, prompt_text
    call vga_write_string

    ; Stay here so the VM does not immediately reset of its own accord.
    jmp $

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

titlebar_text db 'AstralOS - 0.1.0 - pekeshi', 0
titlebar_length equ $ - titlebar_text - 1
kernel_started db 'Kernel entered protected mode', 0x0D, 0x0A, 0
prompt_text db '> ', 0
