/* 映像物理末地址标记：须排在 link/x86_64_kernel.ld 中 .bss 之后，供 pmm.kernelReservedTopPhys。 */
.section .bss.kernel_tail,"aw",@nobits
.global kernel_image_end
.p2align 4
kernel_image_end:
.byte 0
