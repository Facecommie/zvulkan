const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const maybe_registry = b.option(std.Build.LazyPath, "registry", "Set the path to the Vulkan registry (vk.xml)");
    const maybe_video = b.option(std.Build.LazyPath, "video", "Set the path to the Vulkan Video registry (video.xml)");
    const test_step = b.step("test", "Run all the tests");

    const root_module = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Using the package manager, this artifact can be obtained by the user
    // through `b.dependency(<name in build.zig.zon>, .{}).artifact("vulkan-zig-generator")`.
    // with that, the user need only `.addArg("path/to/vk.xml")`, and then obtain
    // a file source to the generated code with `.addOutputArg("vk.zig")`
    const generator_exe = b.addExecutable(.{
        .name = "vulkan-zig-generator",
        .root_module = root_module,
    });
    b.installArtifact(generator_exe);

    // Or they can skip all that, and just make sure to pass `.registry = "path/to/vk.xml"` to `b.dependency`,
    // and then obtain the module directly via `.module("vulkan-zig")`.
    if (maybe_registry) |registry| {
        const vk_generate_cmd = b.addRunArtifact(generator_exe);

        if (maybe_video) |video| {
            vk_generate_cmd.addArg("--video");
            vk_generate_cmd.addFileArg(video);
        }

        vk_generate_cmd.addFileArg(registry);

        const vk_zig = vk_generate_cmd.addOutputFileArg("vk.zig");
        const vk_zig_module = b.addModule("vulkan-zig", .{
            .root_source_file = vk_zig,
        });

        // Also install vk.zig, if passed.

        const vk_zig_install_step = b.addInstallFile(vk_zig, "src/vk.zig");
        b.getInstallStep().dependOn(&vk_zig_install_step.step);

        // And run tests on this vk.zig too.

        // This test needs to be an object so that vulkan-zig can import types from the root.
        // It does not need to run anyway.
        const ref_all_decls_test = b.addObject(.{
            .name = "ref-all-decls-test",
            .root_module = b.createModule(.{
                .root_source_file = b.path("test/ref_all_decls.zig"),
                .target = target,
                .optimize = optimize,
            }),
        });
        ref_all_decls_test.root_module.addImport("vulkan", vk_zig_module);
        test_step.dependOn(&ref_all_decls_test.step);
    }

    const test_target = b.addTest(.{ .root_module = root_module });
    test_step.dependOn(&b.addRunArtifact(test_target).step);
}
