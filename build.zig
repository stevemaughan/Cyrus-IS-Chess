const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const options = b.addOptions();
    // Relative to the build root; test runs use the build root as their cwd.
    options.addOption([]const u8, "golden_dir", "tests/golden");
    // Heavy tests (deep-search robustness), off by default: -Ddeep=true.
    const DeepTests = struct { enabled: bool, positions: usize };
    options.addOption(DeepTests, "deep", .{
        .enabled = b.option(bool, "deep", "Run the deep-search robustness test") orelse false,
        .positions = b.option(usize, "deep-positions", "Positions for the deep test (default 30)") orelse 30,
    });

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
    const test_step = b.step("test", "Run unit and golden-file tests");
    test_step.dependOn(addTestRun(b, mod));

    // Per-unit test steps: each compiles only its unit and that unit's imports,
    // so units can be developed independently (`zig build test-eval`, ...).
    inline for (.{ "board", "eval", "book", "search", "game", "driver", "engine", "perft" }) |unit| {
        const unit_mod = b.createModule(.{
            .root_source_file = b.path("src/test_" ++ unit ++ ".zig"),
            .target = target,
            .optimize = optimize,
        });
        unit_mod.addAnonymousImport("cyrus_bin", .{
            .root_source_file = b.path("reference/extracted/cyrus48-6000-9FFF.bin"),
        });
        unit_mod.addOptions("build_options", options);
        b.step("test-" ++ unit, "Run the " ++ unit ++ " unit's tests").dependOn(addTestRun(b, unit_mod));
    }
}

fn addTestRun(b: *std.Build, module: *std.Build.Module) *std.Build.Step {
    const t = b.addTest(.{ .root_module = module });
    const run = b.addRunArtifact(t);
    run.setCwd(b.path("."));
    return &run.step;
}
