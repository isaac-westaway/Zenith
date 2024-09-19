const std = @import("std");

const zlog = @import("zlog");

const Manager = @import("Manager.zig").Manager;

fn LogPrefix(allocator: *std.mem.Allocator, log_level: []const u8) []const u8 {
    const current_time = zlog.timestampToDatetime(allocator.*, std.time.timestamp());
    const str: []u8 = std.fmt.allocPrint(allocator.*, "{s}: Some Extra Messages!, such as the time: {s}: ", .{ log_level, current_time }) catch {
        return undefined;
    };
    return str;
}

pub fn main() !void {
    var gpa: std.heap.GeneralPurposeAllocator(.{}) = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(gpa.deinit() == .ok);
    const allocator = gpa.allocator();

    try zlog.initializeLogging(@constCast(&allocator), .{ .absolute_path = "/home/isaacwestaway/Documents/zig/zwm", .file_name = "zwm" }, .none);
    // try zlog.installLogPrefix(@constCast(&allocator), &LogPrefix);
    defer zlog.Log.close();

    const Logger = zlog.Log;
    _ = Logger;

    var manager: Manager = try Manager.init(@constCast(&allocator));
    defer manager.deinit();
    std.debug.assert(@TypeOf(manager) == Manager);

    try manager.run();
}
