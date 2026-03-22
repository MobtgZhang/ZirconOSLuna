//! 内核态 I/O 端口（freestanding，无 std）。

pub fn outb(port: u16, value: u8) void {
    asm volatile ("outb %[v], %[p]"
        :
        : [v] "{al}" (value),
          [p] "{dx}" (port),
        : .{ .memory = true });
}

pub fn inb(port: u16) u8 {
    return asm volatile ("inb %[p], %[v]"
        : [v] "={al}" (-> u8),
        : [p] "{dx}" (port),
        : .{ .memory = true });
}

pub fn outl(port: u16, value: u32) void {
    asm volatile ("outl %[v], %[p]"
        :
        : [v] "{eax}" (value),
          [p] "{dx}" (port),
        : .{ .memory = true });
}
