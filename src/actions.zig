const std = @import("std");

const Config = @import("config");

pub fn openTerminal(allocator: *std.mem.Allocator) void {
    const argv: []const []const u8 = &[_][]const u8{Config.terminal_cmd};

    var process = std.process.Child.init(argv, allocator.*);

    process.spawn() catch return;
}

// Take screenshot
pub fn scrot(allocator: *std.mem.Allocator) void {
    const argv: []const []const u8 = &[_][]const u8{"scrot"};

    var process = std.process.Child.init(argv, allocator.*);

    process.spawn() catch return;
}
