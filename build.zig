const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const options = b.addOptions();
    // Relative to the build root; test runs use the build root as their cwd.
    options.addOption([]const u8, "golden_dir", "tests/golden");

    // The engine library. The original binary is embedded so that tables and
    // the opening book are taken from it, never retyped.
    const mod = b.addModule("cyrus", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });
    mod.addAnonymousImport("cyrus_bin", .{
        .root_source_file = b.path("reference/extracted/cyrus48-6000-9FFF.bin"),
    });
    mod.addOptions("build_options", options);

    const exe = b.addExecutable(.{
        .name = "cyrus",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{.{ .name = "cyrus", .module = mod }},
        }),
    });
    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    run_cmd.addPassthruArgs();
    b.step("run", "Run the engine").dependOn(&run_cmd.step);

    // Unit and golden-file tests (golden tests read tests/golden/*.jsonl.gz).
    const mod_tests = b.addTest(.{ .root_module = mod });
    const run_mod_tests = b.addRunArtifact(mod_tests);
    run_mod_tests.setCwd(b.path("."));
    const test_step = b.step("test", "Run unit and golden-file tests");
    test_step.dependOn(&run_mod_tests.step);
}
