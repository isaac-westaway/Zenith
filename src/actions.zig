const std = @import("std");

const Logger = @import("zlog");

const Config = @import("config");

pub fn openTerminal(allocator: *std.mem.Allocator) void {
    const argv: []const []const u8 = &[_][]const u8{Config.terminal_cmd};

    Logger.Log.info("ZWM_RUN_ONKEYPRESSED_OPENTERMINAL", "Opening Kitty terminal", .{}) catch return;

    var process = std.process.Child.init(argv, allocator.*);

    process.spawn() catch return;
}

// Take screenshot
pub fn scrot(allocator: *std.mem.Allocator) void {
    const argv: []const []const u8 = &[_][]const u8{"scrot"};

    var process = std.process.Child.init(argv, allocator.*);

    process.spawn() catch return;
}
