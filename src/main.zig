const std = @import("std");

const Manager = @import("Manager.zig").Manager;

pub fn main() !void {
    var gpa: std.heap.GeneralPurposeAllocator(.{}) = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(gpa.deinit() == .ok);
    const allocator = gpa.allocator();

    var manager: Manager = try Manager.init(@constCast(&allocator));
    defer manager.deinit();

    try manager.run();
} // main
