const std = @import("std");
const dir = std.Io.Dir;
const color = @import("color.zig").Color;

pub fn main(init: std.process.Init) !u8 {
    const io = init.io;
    var stdout_buffer: [1024]u8 = undefined;
    var stdout_file_writer: std.Io.File.Writer = .init(.stdout(), io, &stdout_buffer);
    const stdout = &stdout_file_writer.interface;

    const arena: std.mem.Allocator = init.arena.allocator();

    const args = try init.minimal.args.toSlice(arena);

    if (args.len != 2) {
        // NOTE: This isn't how cat works. This is just my own spin for now until I can learn how to actually
        // do what cat does :)
        try stdout.print(usage(), .{});
        try stdout.flush();
        return 1;
    }

    const path = args[1];

    const cwd = dir.cwd();

    // Make sure the file exists
    cwd.access(io, path, .{}) catch |err| {
        try print_error(stdout, "Failed to access '{s}' with error: {}\n", .{ path, err });
        try stdout.flush();
        return 1;
    };

    // Not sure why this wouldn't work, but if stat fails, we'll catch it!
    const file_stat = cwd.statFile(io, path, .{}) catch |err| {
        try print_error(stdout, "Error statting file '{s}' with error {}", .{ path, err });
        try stdout.flush();
        return 1;
    };

    // Make sure we're trying to cat a file
    if (file_stat.kind != .file) {
        try stdout.print(color.red ++ "[bat error]" ++ color.reset ++ ": '{s}' is a directory.\n", .{path});
        try stdout.flush();
        return 1;
    }

    try stdout.flush();

    return 0;
}

fn usage() []const u8 {
    return "Usage: zig-cat <file>\n";
}

fn print_error(stdout: *std.Io.Writer, comptime message: []const u8, args: anytype) !void {
    try stdout.print(color.red ++ "[Error]" ++ color.reset ++ ": " ++ message, args);
}
