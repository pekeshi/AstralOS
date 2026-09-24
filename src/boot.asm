[org 0x7c00]
bits 16

; BIOS loads this boot sector at 0x7C00.
; It loads the kernel from the floppy image and jumps into protected mode.

KERNEL_OFFSET equ 0x1000
SECTORS_TO_READ equ 16
DISK_RETRIES equ 3

start:
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7c00
    mov [boot_drive], dl

    call serial_init

    ; Tell the user we are loading the kernel.
    mov si, msg_loading
    call print_string

    ; Prefer LBA reads so USB BIOS implementations do not have to emulate
    ; floppy geometry. Keep the CHS path for older BIOSes.
    call read_kernel
    jc disk_error

    ; Kernel is loaded; now switch to protected mode.
    mov si, msg_loaded
    call print_string

    cli
    lgdt [gdt_desc]
    mov eax, cr0
    or eax, 1
    mov cr0, eax

    ; Far jump into the kernel at 0x1000 in protected mode.
    jmp CODE_SEG:0x1000

read_kernel:
    ; INT 13h extensions are the reliable path for hard disks and USB media.
    mov ah, 0x41
    mov bx, 0x55aa
    mov dl, [boot_drive]
    int 0x13
    jc .chs
    cmp bx, 0xaa55
    jne .chs
    test cx, 1
    jz .chs

    mov byte [read_attempts], DISK_RETRIES
.edd_retry:
    mov ah, 0x42
    mov dl, [boot_drive]
    mov si, disk_address_packet
    int 0x13
    jnc .success
    xor ah, ah
    int 0x13
    dec byte [read_attempts]
    jnz .edd_retry
    stc
    ret

.chs:
    mov byte [read_attempts], DISK_RETRIES
.chs_retry:
    ; Read the kernel from the floppy image into memory at 0x1000.
    mov ah, 0x02
    mov al, SECTORS_TO_READ
    mov ch, 0x00
    mov cl, 0x02
    mov dh, 0x00
    mov dl, [boot_drive]
    mov bx, KERNEL_OFFSET
    int 0x13
    jnc .success
    xor ah, ah
    int 0x13
    dec byte [read_attempts]
    jnz .chs_retry
    stc
    ret

.success:
    clc
    ret

serial_init:
    mov dx, 0x3f8 + 3
    mov al, 0x80
    out dx, al

    mov dx, 0x3f8 + 0
    mov al, 0x03
    out dx, al

    mov dx, 0x3f8 + 1
    mov al, 0x00
    out dx, al

    mov dx, 0x3f8 + 3
    mov al, 0x03
    out dx, al

    mov dx, 0x3f8 + 2
    mov al, 0xC7
    out dx, al

    mov dx, 0x3f8 + 4
    mov al, 0x0B
    out dx, al
    ret

serial_write_char:
    push eax
    push edx
    mov dx, 0x3f8 + 5
.wait:
    in al, dx
    test al, 0x20
    jz .wait
    pop edx
    pop eax
    mov dx, 0x3f8
    out dx, al
    ret

serial_write_string:
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

print_string:
    ; Save registers so we do not disturb the caller.
    pusha

.loop:
    ; Load one byte from the string into AL and advance SI.
    lodsb
    ; If AL is zero, the string ended.
    or al, al
    jz .done

    ; BIOS teletype output: print the character in AL.
    mov ah, 0x0e
    mov bx, 0x0007
    int 0x10
    call serial_write_char
    jmp .loop

.done:
    popa
    ret

disk_error:
    ; If the disk read failed, print an error and stop.
    mov si, msg_disk_error
    call print_string

hang:
    hlt
    jmp hang

gdt_start:
    ; Null descriptor required by the CPU.
    dq 0

gdt_code:
    ; Code segment descriptor for 32-bit execution.
    dw 0xffff
    dw 0
    db 0
    db 10011010b
    db 11001111b
    db 0

gdt_data:
    ; Data segment descriptor.
    dw 0xffff
    dw 0
    db 0
    db 10010010b
    db 11001111b
    db 0

gdt_end:

gdt_desc:
    ; Describe the GDT to the CPU.
    dw gdt_end - gdt_start - 1
    dd gdt_start

CODE_SEG equ gdt_code - gdt_start
DATA_SEG equ gdt_data - gdt_start

; Store the boot drive number so we can reuse it later for disk reads.
boot_drive: db 0
read_attempts: db 0

; Messages shown during the boot process.
msg_loading db 'Loading AstralOS kernel...', 0x0d, 0x0a, 0
msg_loaded db 'Kernel loaded. Switching to protected mode...', 0x0d, 0x0a, 0
msg_disk_error db 'Disk read error!', 0x0d, 0x0a, 0

disk_address_packet:
    db 0x10, 0
    dw SECTORS_TO_READ
    dw KERNEL_OFFSET
    dw 0
    dq 1

; Fill the boot sector with zeros up to 510 bytes, then add the boot signature.
times 510 - ($ - $$) db 0
dw 0xAA55