/* ZirconOS Boot Manager：长模式 → 32 位保护模式，以 Multiboot2 状态 jmp 内核 _start。
 * 整段拷贝到物理 0x8000；Zig 写入 0x87F0=magic、0x87F4=info_phys、0x87F8=entry_phys。 */
.intel_syntax noprefix
.section .zbmtramp,"ax"
.align 16
.global zbm_trampoline_blob_start
.global zbm_trampoline_blob_end

zbm_trampoline_blob_start:
.code64
zbm_trampoline_entry:
    cli
    mov rsp, 0x90000
    lea rax, [rip + gdt32]
    mov [rip + gdtr32 + 2], rax
    lgdt [rip + gdtr32]

    /* 64 位下 far ret 默认 8+8；用 m16:32 远 jmp 进入 32 位兼容段 */
    lea rax, [rip + compat32]
    mov dword ptr [rip + fj32], eax
    mov word ptr [rip + fj32 + 4], 0x08
    jmp fword ptr [rip + fj32]

.align 8
fj32:
    .long 0
    .short 0

.code32
compat32:
    mov eax, cr0
    and eax, 0x7fffffff
    mov cr0, eax

    mov ecx, 0xC0000080
    rdmsr
    and eax, 0xfffffeff
    wrmsr

    jmp pure32

pure32:
    mov ax, 0x10
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax
    mov esp, 0x90000

    mov eax, dword ptr [0x87f0]
    mov ebx, dword ptr [0x87f4]
    jmp dword ptr [0x87f8]

.align 8
gdt32:
    .quad 0
    .quad 0x00cf9a000000ffff
    .quad 0x00cf92000000ffff
gdt32_end:

.align 8
gdtr32:
    .word gdt32_end - gdt32 - 1
    .quad 0

zbm_trampoline_blob_end:
.code64
