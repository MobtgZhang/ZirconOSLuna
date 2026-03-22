//! 异常分发（KE 子系统入口的雏形）。IF=0 时仍响应 fault 类向量。

const serial = @import("../hal/serial.zig");

pub const CpuFrame = extern struct {
    vector: u64,
    error_code: u64,
    rip: u64,
    cs: u64,
    rflags: u64,
};

fn readCr2() u64 {
    return asm volatile ("mov %%cr2, %[o]"
        : [o] "={rax}" (-> u64),
        :
        : .{ .memory = true });
}

export fn exceptionDispatch(stack_top: usize) callconv(.c) noreturn {
    // isr_common 压入 15 个 GPR（rax..r15），再是桩里 push 的 vector / error_code，再是 CPU 压入的 rip/cs/rflags。
    const gprs_size = 15 * 8;
    const cpu: *align(1) const CpuFrame = @ptrFromInt(stack_top + gprs_size);

    serial.writeStr("\r\n[KE] *** STOP ");
    serial.writeStr(vectorName(cpu.vector));
    serial.writeStr(" *** err=0x");
    serial.writeHex(cpu.error_code, 16);
    serial.writeStr(" rip=0x");
    serial.writeHex(cpu.rip, 16);
    serial.writeStr(" cs=0x");
    serial.writeHex(cpu.cs, 4);
    serial.writeStr(" rflags=0x");
    serial.writeHex(cpu.rflags, 16);
    if (cpu.vector == 14) {
        serial.writeStr(" cr2=0x");
        serial.writeHex(readCr2(), 16);
    }
    serial.writeNewline();
    hang();
}

fn vectorName(v: u64) []const u8 {
    return switch (v) {
        0 => "#DE divide",
        1 => "#DB debug",
        2 => "NMI",
        3 => "#BP breakpoint",
        4 => "#OF overflow",
        5 => "#BR bound",
        6 => "#UD invalid opcode",
        7 => "#NM device not available",
        8 => "#DF double fault",
        10 => "#TS invalid TSS",
        11 => "#NP segment",
        12 => "#SS stack",
        13 => "#GP general protection",
        14 => "#PF page fault",
        16 => "#MF x87",
        17 => "#AC alignment",
        18 => "#MC machine check",
        19 => "#XM SIMD",
        else => "#?? reserved",
    };
}

fn hang() noreturn {
    while (true) {
        asm volatile ("cli; hlt"
            :
            :
            : .{ .memory = true });
    }
}
