bits 64
default rel

section .text

global efi_main

efi_main:
    push rbp
    mov rbp, rsp
    sub rsp, 0x80
    mov r12, rcx
    mov r13, rdx

    ; Reserve pages below 4 GiB for the embedded 32-bit kernel.
    mov rax, [r13 + 96]
    mov ecx, 2
    mov edx, 2
    mov r8d, (kernel_embedded_end - kernel_embedded_start + 0xfff) / 0x1000
    mov qword [rel kernel_address], 0x100000
    lea r9, [rel kernel_address]
    call qword [rax + 40]
    test rax, rax
    js .fail

    ; Copy the embedded kernel into the address it was assembled for.
    mov rsi, kernel_embedded_start
    mov rdi, [rel kernel_address]
    mov ecx, kernel_embedded_end - kernel_embedded_start
    rep movsb

    ; The kernel no longer needs UEFI services. Leave long mode and enter it
    ; in the same 32-bit protected-mode environment used by the BIOS loader.
    cli
    lea rax, [rel gdt_start]
    mov [rel gdt_descriptor + 2], rax
    lgdt [rel gdt_descriptor]

    mov rax, cr0
    and eax, 0x7fffffff
    mov cr0, rax

    mov ecx, 0xc0000080
    rdmsr
    and eax, 0xfffffeff
    wrmsr

    mov rax, cr4
    and eax, 0xffffffdf
    mov cr4, rax

    push qword 0x08
    push qword protected_entry
    retf

.fail:
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

section .data
align 8
section .bss
align 8
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

section .data
align 4
kernel_embedded_start:
    incbin "build/kernel-uefi.bin"
kernel_embedded_end:
