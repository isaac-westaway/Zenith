const std = @import("std");

const Manager = @import("Manager.zig");

pub fn main() !void {
    var gpa: std.heap.GeneralPurposeAllocator(.{}) = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(gpa.deinit() == .ok);
    var allocator = gpa.allocator();

    Manager.setupManager(&allocator) catch |err| {
        switch (err) {
            error.XorgDisplayFail, error.XCBConnectionFail => {
                std.posix.exit(1);
            },
        }
    };
    defer Manager.closeManager();

    Manager.runManager();
} // main
