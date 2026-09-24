bits 64
default rel

section .text

global efi_main

efi_main:
    push rbp
    mov rbp, rsp
    sub rsp, 0x80
    call debug_init
    lea rsi, [rel msg_entry]
    call debug_string
    mov r12, rcx
    mov r13, rdx

    ; Locate the filesystem protocol exposed by the boot device.
    mov rax, [r13 + 96]
    lea rcx, [rel simple_file_system_guid]
    xor edx, edx
    lea r8, [rel file_system]
    call qword [rax + 320]
    test rax, rax
    js .fail
    lea rsi, [rel msg_filesystem]
    call debug_string

    ; Open the filesystem volume and the kernel file at its root.
    mov rcx, [rel file_system]
    lea rdx, [rel root_directory]
    call qword [rcx + 8]
    test rax, rax
    js .fail
    lea rsi, [rel msg_root]
    call debug_string

    mov rcx, [rel root_directory]
    lea rdx, [rel kernel_file]
    lea r8, [rel kernel_path]
    mov r9d, 1
    mov qword [rsp + 0x28], 0
    call qword [rcx + 8]
    test rax, rax
    js .fail
    lea rsi, [rel msg_file]
    call debug_string

    ; Reserve one page below 4 GiB for the 32-bit protected-mode kernel.
    mov rax, [r13 + 96]
    mov ecx, 2
    mov edx, 2
    mov r8d, 1
    mov qword [rel kernel_address], 0x100000
    lea r9, [rel kernel_address]
    call qword [rax + 40]
    test rax, rax
    js .fail
    lea rsi, [rel msg_memory]
    call debug_string

    ; Read the raw kernel into the address it was assembled for.
    mov rcx, [rel kernel_file]
    lea rdx, [rel kernel_size]
    mov r8, [rel kernel_address]
    call qword [rcx + 32]
    test rax, rax
    js .fail
    lea rsi, [rel msg_read]
    call debug_string

    ; The kernel no longer needs UEFI services. Leave long mode and enter it
    ; in the same 32-bit protected-mode environment used by the BIOS loader.
    cli
    lea rsi, [rel msg_jump]
    call debug_string
    lea rax, [rel gdt_start]
    mov [rel gdt_descriptor + 2], rax
    lgdt [rel gdt_descriptor]

    mov ecx, 0xc0000080
    rdmsr
    and eax, 0xfffffeff
    wrmsr

    mov rax, cr0
    and eax, 0x7fffffff
    mov cr0, rax

    mov rax, cr4
    and eax, 0xffffffdf
    mov cr4, rax

    jmp far [rel transition_pointer]

.fail:
    lea rsi, [rel msg_fail]
    call debug_string
    mov eax, 1
    leave
    ret

bits 32
protected_entry:
    mov ax, 0x10
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax
    mov esp, 0x90000
    jmp 0x08:0x00100000

bits 64

debug_string:
    lodsb
    test al, al
    jz .done
    call debug_char
    jmp debug_string
.done:
    ret

debug_init:
    mov dx, 0x3fb
    mov al, 0x80
    out dx, al
    mov dx, 0x3f8
    mov al, 0x03
    out dx, al
    mov dx, 0x3f9
    xor al, al
    out dx, al
    mov dx, 0x3fb
    mov al, 0x03
    out dx, al
    mov dx, 0x3fa
    mov al, 0xc7
    out dx, al
    mov dx, 0x3fc
    mov al, 0x0b
    out dx, al
    ret

debug_char:
    push rax
    push rdx
    mov dx, 0x3fd
.wait:
    in al, dx
    test al, 0x20
    jz .wait
    pop rdx
    pop rax
    mov dx, 0x3f8
    out dx, al
    ret

section .data
align 8
msg_entry db 'EFI entry', 0x0d, 0x0a, 0
msg_filesystem db 'filesystem', 0x0d, 0x0a, 0
msg_root db 'root', 0x0d, 0x0a, 0
msg_file db 'file', 0x0d, 0x0a, 0
msg_memory db 'memory', 0x0d, 0x0a, 0
msg_read db 'read', 0x0d, 0x0a, 0
msg_jump db 'jump', 0x0d, 0x0a, 0
msg_fail db 'fail', 0x0d, 0x0a, 0
simple_file_system_guid:
    dd 0x964e5b22
    dw 0x6459, 0x11d2
    db 0x8e, 0x39, 0x00, 0xa0, 0xc9, 0x69, 0x72, 0x3b

kernel_path:
    dw '\\', 'A', 'S', 'T', 'R', 'A', 'L', 'O', 'S', '.', 'K', 'R', 'N', 0

kernel_size: dq 4096
transition_pointer:
    dw 0x08
    dd protected_entry

section .bss
align 8
file_system: resq 1
root_directory: resq 1
kernel_file: resq 1
kernel_address: resq 1

section .text
align 8
gdt_start:
    dq 0
    dw 0xffff
    dw 0
    db 0
    db 10011010b
    db 11001111b
    db 0
    dw 0xffff
    dw 0
    db 0
    db 10010010b
    db 11001111b
    db 0
gdt_descriptor:
    dw 23
    dq 0
