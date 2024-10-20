const std = @import("std");

const Manager = @import("Manager.zig").Manager;

pub fn main() !void {
    var gpa: std.heap.GeneralPurposeAllocator(.{}) = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(gpa.deinit() == .ok);
    const allocator = gpa.allocator();

    var manager = Manager.init(&allocator) catch |err| {
        switch (err) {
            error.XorgDisplayFail, error.XCBConnectionFail => {
                std.posix.exit(1);
            },
        }
    };
    defer manager.deinit();

    try manager.run();
} // main
