ACPI_PM1_CONTROL_OFFSET equ 0x40
ACPI_DSDT_OFFSET equ 0x28
ACPI_SLP_EN equ 1 << 13

acpi_power_off:
    ; Find the ACPI tables and return CF=1 when power-off is unavailable.
    call acpi_find_rsdp
    test eax, eax
    jnz .rsdp_found
    mov esi, acpi_rsdp_error
    call serial_write_string
    jmp .unavailable

.rsdp_found:

    mov esi, eax
    mov eax, [esi + 0x10]
    call acpi_find_fadt
    test eax, eax
    jnz .fadt_found
    mov esi, acpi_fadt_error
    call serial_write_string
    jmp .unavailable

.fadt_found:

    mov edi, eax
    mov dx, [edi + ACPI_PM1_CONTROL_OFFSET]
    test dx, dx
    jnz .pm1_found
    mov esi, acpi_pm1_error
    call serial_write_string
    jmp .unavailable

.pm1_found:
    mov [acpi_pm1a_port], dx
    mov dx, [edi + ACPI_PM1_CONTROL_OFFSET + 4]
    mov [acpi_pm1b_port], dx

    mov eax, [edi + ACPI_DSDT_OFFSET]
    call acpi_find_s5
    test eax, eax
    jnz .s5_found
    mov esi, acpi_s5_error
    call serial_write_string
    jmp .unavailable

.s5_found:

    or eax, ACPI_SLP_EN
    mov [acpi_sleep_value], ax

    mov dx, [acpi_pm1a_port]
    mov ax, [acpi_sleep_value]
    out dx, ax

    mov dx, [acpi_pm1b_port]
    test dx, dx
    jz .success
    mov ax, [acpi_sleep_value]
    out dx, ax

.success:
    clc
    ret

.unavailable:
    stc
    ret

acpi_qemu_power_off:
    ; QEMU's standard ACPI-compatible fallback power-control port.
    mov dx, 0x604
    mov ax, 0x2000
    out dx, ax
    ret

acpi_find_rsdp:
    ; Search the EBDA first, then the BIOS read-only area.
    push ebx
    push ecx
    push edx
    push esi
    push edi

    xor eax, eax
    mov ax, [0x40E]
    shl eax, 4
    test eax, eax
    jz .search_bios

    mov esi, eax
    mov edi, eax
    add edi, 1024
    call acpi_scan_rsdp
    test eax, eax
    jnz .done

.search_bios:
    mov esi, 0xE0000
    mov edi, 0x100000
    call acpi_scan_rsdp

.done:
    pop edi
    pop esi
    pop edx
    pop ecx
    pop ebx
    ret

acpi_scan_rsdp:
    ; Search 16-byte-aligned addresses for the RSDP signature and checksum.
.loop:
    cmp esi, edi
    jae .not_found

    cmp dword [esi], 0x20534452
    jne .next
    cmp dword [esi + 4], 0x20525450
    jne .next

    push esi
    mov ecx, 20
    call acpi_checksum
    pop esi
    test al, al
    jz .found

.next:
    add esi, 16
    jmp .loop

.found:
    mov eax, esi
    ret

.not_found:
    xor eax, eax
    ret

acpi_find_fadt:
    ; EAX points to the RSDT. Return the FADT address or zero.
    push ebx
    push ecx
    push edx
    push esi
    push edi

    mov esi, eax
    mov ecx, [esi + 4]
    sub ecx, 36
    jc .not_found
    shr ecx, 2
    lea esi, [esi + 36]

.next_entry:
    test ecx, ecx
    jz .not_found
    mov eax, [esi]
    cmp dword [eax], 0x50434146
    je .found
    add esi, 4
    dec ecx
    jmp .next_entry

.found:
    pop edi
    pop esi
    pop edx
    pop ecx
    pop ebx
    ret

.not_found:
    xor eax, eax
    pop edi
    pop esi
    pop edx
    pop ecx
    pop ebx
    ret

acpi_find_s5:
    ; EAX points to the DSDT. Return SLP_TYP << 10, or zero on failure.
    push ebx
    push ecx
    push edx
    push esi
    push edi

    mov esi, eax
    mov ecx, [esi + 4]
    sub ecx, 36
    jc .not_found
    lea esi, [esi + 36]

.search:
    cmp ecx, 4
    jb .not_found
    cmp dword [esi], 0x5F35535F
    je .found_name
    inc esi
    dec ecx
    jmp .search

.found_name:
    add esi, 4
    cmp byte [esi], 0x12
    jne .not_found
    inc esi
    movzx ebx, byte [esi]
    and ebx, 0x3F
    cmp ebx, 2
    jb .not_found
    add esi, 2

    cmp byte [esi], 0x0A
    jne .direct_value
    inc esi

.direct_value:
    movzx eax, byte [esi]
    and eax, 7
    shl eax, 10
    jmp .done

.not_found:
    xor eax, eax

.done:
    pop edi
    pop esi
    pop edx
    pop ecx
    pop ebx
    ret

acpi_checksum:
    ; Return AL=0 when ECX bytes at ESI sum to zero modulo 256.
    xor eax, eax
.sum:
    test ecx, ecx
    jz .done
    add al, [esi]
    inc esi
    dec ecx
    jmp .sum
.done:
    ret

acpi_pm1a_port dw 0
acpi_pm1b_port dw 0
acpi_sleep_value dw 0

acpi_rsdp_error db 'ACPI: RSDP not found', 0x0D, 0x0A, 0
acpi_fadt_error db 'ACPI: FADT not found', 0x0D, 0x0A, 0
acpi_pm1_error db 'ACPI: PM1 control block not found', 0x0D, 0x0A, 0
acpi_s5_error db 'ACPI: _S5_ not found', 0x0D, 0x0A, 0
