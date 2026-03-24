//! 重导出：`src/kernel/common/nt52_spec.zig`（保持 `kernel/nt52/spec.zig` 路径稳定）。
const c = @import("../common/nt52_spec.zig");

pub const version_major = c.version_major;
pub const version_minor = c.version_minor;
pub const build_xp_x64_rtm = c.build_xp_x64_rtm;
pub const user_space_max_tb = c.user_space_max_tb;
pub const syswow64_hint = c.syswow64_hint;
pub const describeProductLine = c.describeProductLine;
