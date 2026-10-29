const std = @import("std");
const dir = std.Io.Dir;

pub fn main(init: std.process.Init) !u8 {
    const io = init.io;

    var stdout_buffer: [1024]u8 = undefined;
    var stdout_file_writer: std.Io.File.Writer = .init(.stdout(), io, &stdout_buffer);
    const stdout = &stdout_file_writer.interface;

    var stdin_buffer: [1024]u8 = undefined;
    var stdin_file_reader: std.Io.File.Reader = .init(.stdin(), io, &stdin_buffer);
    const stdin = &stdin_file_reader.interface;

    const arena: std.mem.Allocator = init.arena.allocator();

    const args = try init.minimal.args.toSlice(arena);

    if (args.len == 1) {
        try cat_stdin(stdin, stdout);
        return 0;
    }

    if (args.len > 2) {
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
        try print_error(stdout, "{} failed to access '{s}'\n", .{ err, path });
        try stdout.flush();
        return 1;
    };

    // Not sure why this wouldn't work, but if stat fails, we'll catch it!
    const file_stat = cwd.statFile(io, path, .{}) catch |err| {
        try print_error(stdout, "{} while statting file '{s}'\n", .{ err, path });
        try stdout.flush();
        return 1;
    };

    // Make sure we're trying to cat a file
    if (file_stat.kind != .file) {
        try stdout.print(Color.red ++ "[bat error]" ++ Color.reset ++ ": '{s}' is a directory.\n", .{path});
        try stdout.flush();
        return 1;
    }

    var buffer: [1024]u8 = undefined;
    const file = cwd.readFile(io, path, &buffer) catch |err| {
        try print_error(stdout, "{} error reading file '{s}'\n", .{ err, path });
        try stdout.flush();
        return 1;
    };

    try stdout.writeAll(file);
    try stdout.flush();

    return 0;
}

fn cat_stdin(stdin: *std.Io.Reader, stdout: *std.Io.Writer) !void {
    while (true) {
        _ = stdin.stream(stdout, .limited(1024)) catch |err| switch (err) {
            error.EndOfStream => break,
            else => return err,
        };
    }
    try stdout.flush();
}

fn usage() []const u8 {
    return "Usage: zig-cat <file>\n";
}

fn print_error(stdout: *std.Io.Writer, comptime message: []const u8, args: anytype) !void {
    try stdout.print(Color.red ++ "[Error]" ++ Color.reset ++ ": " ++ message, args);
}

const Color = struct {
    pub const red = "\x1b[31m";
    pub const green = "\x1b[32m";
    pub const yellow = "\x1b[33m";
    pub const blue = "\x1b[34m";
    pub const cyan = "\x1b[36m";
    pub const reset = "\x1b[0m";
};
