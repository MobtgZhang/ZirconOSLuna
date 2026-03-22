/* 装载由 Zig 填写的 `kernel_idt_descriptor`（10 字节 lidt 操作数）。 */
.code64
.section .text
.global arch_load_idt
.type arch_load_idt, @function
arch_load_idt:
    leaq kernel_idt_descriptor(%rip), %rax
    lidt (%rax)
    ret
