const std = @import("std");

// Although this function looks imperative, it does not perform the build
// directly and instead it mutates the build graph (`b`) that will be then
// executed by an external runner. The functions in `std.Build` implement a DSL
// for defining build steps and express dependencies between them, allowing the
// build runner to parallelize the build automatically (and the cache system to
// know when a step doesn't need to be re-run).
pub fn build(b: *std.Build) void {
    // Standard target options allow the person running `zig build` to choose
    // what target to build for. Here we do not override the defaults, which
    // means any target is allowed, and the default is native. Other options
    // for restricting supported target set are available.
    const target = b.standardTargetOptions(.{});
    // Standard optimization options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall. Here we do not
    // set a preferred release mode, allowing the user to decide how to optimize.
    const optimize = b.standardOptimizeOption(.{});
    // It's also possible to define more custom flags to toggle optional features
    // of this build script using `b.option()`. All defined flags (including
    // target and optimize options) will be listed when running `zig build --help`
    // in this directory.

    // This creates a module, which represents a collection of source files alongside
    // some compilation options, such as optimization mode and linked system libraries.
    // Zig modules are the preferred way of making Zig code available to consumers.
    // addModule defines a module that we intend to make available for importing
    // to our consumers. We must give it a name because a Zig package can expose
    // multiple modules and consumers will need to be able to specify which
    // module they want to access.
    const mod = b.addModule("ZirconOSLuna", .{
        // The root source file is the "entry point" of this module. Users of
        // this module will only be able to access public declarations contained
        // in this file, which means that if you have declarations that you
        // intend to expose to consumers that were defined in other files part
        // of this module, you will have to make sure to re-export them from
        // the root file.
        .root_source_file = b.path("src/root.zig"),
        // Later on we'll use this module as the root module of a test executable
        // which requires us to specify a target.
        .target = target,
    });

    // Here we define an executable. An executable needs to have a root module
    // which needs to expose a `main` function. While we could add a main function
    // to the module defined above, it's sometimes preferable to split business
    // logic and the CLI into two separate modules.
    //
    // If your goal is to create a Zig library for others to use, consider if
    // it might benefit from also exposing a CLI tool. A parser library for a
    // data serialization format could also bundle a CLI syntax checker, for example.
    //
    // If instead your goal is to create an executable, consider if users might
    // be interested in also being able to embed the core functionality of your
    // program in their own executable in order to avoid the overhead involved in
    // subprocessing your CLI tool.
    //
    // If neither case applies to you, feel free to delete the declaration you
    // don't need and to put everything under a single module.
    const exe = b.addExecutable(.{
        .name = "ZirconOSLuna",
        .root_module = b.createModule(.{
            // b.createModule defines a new module just like b.addModule but,
            // unlike b.addModule, it does not expose the module to consumers of
            // this package, which is why in this case we don't have to give it a name.
            .root_source_file = b.path("src/main.zig"),
            // Target and optimization levels must be explicitly wired in when
            // defining an executable or library (in the root module), and you
            // can also hardcode a specific target for an executable or library
            // definition if desireable (e.g. firmware for embedded devices).
            .target = target,
            .optimize = optimize,
            // List of modules available for import in source files part of the
            // root module.
            .imports = &.{
                // Here "ZirconOSLuna" is the name you will use in your source code to
                // import this module (e.g. `@import("ZirconOSLuna")`). The name is
                // repeated because you are allowed to rename your imports, which
                // can be extremely useful in case of collisions (which can happen
                // importing modules from different packages).
                .{ .name = "ZirconOSLuna", .module = mod },
            },
        }),
    });

    // This declares intent for the executable to be installed into the
    // install prefix when running `zig build` (i.e. when executing the default
    // step). By default the install prefix is `zig-out/` but can be overridden
    // by passing `--prefix` or `-p`.
    b.installArtifact(exe);

    // This creates a top level step. Top level steps have a name and can be
    // invoked by name when running `zig build` (e.g. `zig build run`).
    // This will evaluate the `run` step rather than the default step.
    // For a top level step to actually do something, it must depend on other
    // steps (e.g. a Run step, as we will see in a moment).
    const run_step = b.step("run", "Run the app");

    // This creates a RunArtifact step in the build graph. A RunArtifact step
    // invokes an executable compiled by Zig. Steps will only be executed by the
    // runner if invoked directly by the user (in the case of top level steps)
    // or if another step depends on it, so it's up to you to define when and
    // how this Run step will be executed. In our case we want to run it when
    // the user runs `zig build run`, so we create a dependency link.
    const run_cmd = b.addRunArtifact(exe);
    run_step.dependOn(&run_cmd.step);

    // By making the run step depend on the default step, it will be run from the
    // installation directory rather than directly from within the cache directory.
    run_cmd.step.dependOn(b.getInstallStep());

    // This allows the user to pass arguments to the application in the build
    // command itself, like this: `zig build run -- arg1 arg2 etc`
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    // Creates an executable that will run `test` blocks from the provided module.
    // Here `mod` needs to define a target, which is why earlier we made sure to
    // set the releative field.
    const mod_tests = b.addTest(.{
        .root_module = mod,
    });

    // A run step that will run the test executable.
    const run_mod_tests = b.addRunArtifact(mod_tests);

    // Creates an executable that will run `test` blocks from the executable's
    // root module. Note that test executables only test one module at a time,
    // hence why we have to create two separate ones.
    const exe_tests = b.addTest(.{
        .root_module = exe.root_module,
    });

    // A run step that will run the second test executable.
    const run_exe_tests = b.addRunArtifact(exe_tests);

    // A top level step for running all tests. dependOn can be called multiple
    // times and since the two run steps do not depend on one another, this will
    // make the two of them run in parallel.
    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&run_mod_tests.step);
    test_step.dependOn(&run_exe_tests.step);

    // Just like flags, top level steps are also listed in the `--help` menu.
    //
    // The Zig build system is entirely implemented in userland, which means
    // that it cannot hook into private compiler APIs. All compilation work
    // orchestrated by the build system will result in other Zig compiler
    // subcommands being invoked with the right flags defined. You can observe
    // these invocations when one fails (or you pass a flag to increase
    // verbosity) to validate assumptions and diagnose problems.
    //
    // Lastly, the Zig build system is relatively simple and self-contained,
    // and reading its source code will allow you to master it.

    // --- 内核可执行（x86-64 Multiboot2）---
    const boot_method = b.option([]const u8, "boot-method", "mbr|uefi") orelse "mbr";
    // 默认与 build.conf / scripts/fetch-ovmf.sh（edk2-nightly RELEASE X64）一致
    const ovmf_code = b.option([]const u8, "ovmf-code", "") orelse "firmware/ovmf/RELEASEX64_OVMF_CODE.fd";
    const ovmf_vars_src = b.option([]const u8, "ovmf-vars", "") orelse "firmware/ovmf/RELEASEX64_OVMF_VARS.fd";
    const kernel_desktop = b.option([]const u8, "kernel-desktop", "none|cmd") orelse "cmd";
    const kernel_line = b.option([]const u8, "kernel-version-string", "") orelse "ZirconOSLuna Kernel [x86-64] CMD — NT 5.2 ref";
    const kernel_debug_log = b.option(bool, "kernel-debug-log", "Verbose COM1 boot log (mmap/PMM/MM); false for quiet Release") orelse (optimize == .Debug);

    const kernel_target = b.resolveTargetQuery(.{
        .cpu_arch = .x86_64,
        .os_tag = .freestanding,
        .abi = .none,
    });
    const kernel_mod = b.createModule(.{
        .root_source_file = b.path("src/kernel/entry.zig"),
        .target = kernel_target,
        .optimize = optimize,
        .single_threaded = true,
        .link_libc = false,
        .red_zone = false,
    });
    const kernel_build_cfg = b.addOptions();
    kernel_build_cfg.addOption([]const u8, "desktop", kernel_desktop);
    kernel_build_cfg.addOption([]const u8, "kernel_line", kernel_line);
    kernel_build_cfg.addOption(bool, "kernel_debug_log", kernel_debug_log);
    kernel_mod.addOptions("build_config", kernel_build_cfg);
    const kernel = b.addExecutable(.{
        .name = "zirconosluna-kernel",
        .root_module = kernel_mod,
    });
    kernel.image_base = 0x100000;
    kernel.setLinkerScript(b.path("link/x86_64_kernel.ld"));
    kernel.root_module.addAssemblyFile(b.path("boot/entry.S"));
    kernel.root_module.addAssemblyFile(b.path("boot/isr_x86_64.S"));
    kernel.root_module.addAssemblyFile(b.path("boot/idt_load.S"));
    b.installArtifact(kernel);

    const zbm_target = b.resolveTargetQuery(.{
        .cpu_arch = .x86_64,
        .os_tag = .uefi,
        .abi = .msvc,
    });
    const zbm_mod = b.createModule(.{
        .root_source_file = b.path("boot/zbm/main.zig"),
        .target = zbm_target,
        .optimize = optimize,
    });
    const zbm = b.addExecutable(.{
        .name = "BOOTX64",
        .root_module = zbm_mod,
    });
    zbm.root_module.addAssemblyFile(b.path("boot/zbm/trampoline.S"));
    b.installArtifact(zbm);

    const kernel_step = b.step("kernel", "Build x86-64 kernel (Multiboot2)");
    kernel_step.dependOn(&b.addInstallArtifact(kernel, .{}).step);

    const kernel_bin_path = b.pathJoin(&.{ b.install_path, "bin", "zirconosluna-kernel" });
    const zbm_bin_path = b.pathJoin(&.{ b.install_path, "bin", "BOOTX64.efi" });
    const iso_path = b.pathJoin(&.{ b.install_path, "zirconosluna.iso" });
    const mk_iso = b.addSystemCommand(&.{ "bash", "scripts/mk-iso.sh", zbm_bin_path, kernel_bin_path, iso_path });
    mk_iso.step.dependOn(b.getInstallStep());
    const iso_step = b.step("iso", "Build UEFI ISO (ZirconOS Boot Manager + kernel)");
    iso_step.dependOn(&mk_iso.step);

    const run_kernel_step = b.step("run-kernel", "Run kernel in QEMU (ZBM UEFI ISO; scripts/run-qemu.sh)");
    const qemu_bin = b.option([]const u8, "qemu", "Path to qemu-system-x86_64") orelse "qemu-system-x86_64";
    const qemu_mem = b.option([]const u8, "qemu-mem", "QEMU guest memory (e.g. 512M)") orelse "512M";
    // 默认图形窗口；-Dqemu-nographic=true 时无窗口、COM1 走 stdio。
    const qemu_nographic = b.option(bool, "qemu-nographic", "Headless QEMU (no GUI, serial on stdio only)") orelse false;

    const ovmf_vars_dst = b.pathJoin(&.{ b.install_path, "ovmf_vars.fd" });
    const run_kernel_cmd = b.addSystemCommand(&.{
        "bash",
        "scripts/run-qemu.sh",
        qemu_bin,
        qemu_mem,
        iso_path,
        boot_method,
        ovmf_code,
        ovmf_vars_dst,
        ovmf_vars_src,
        if (qemu_nographic) "1" else "0",
    });
    run_kernel_cmd.step.dependOn(&mk_iso.step);
    run_kernel_step.dependOn(&run_kernel_cmd.step);
}
