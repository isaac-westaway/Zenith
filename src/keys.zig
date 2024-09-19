const std = @import("std");

const c = @import("x11.zig").c;

const actions = @import("actions.zig");

const Key = struct {
    keysym: c.KeySym,
    action: *const fn (allocator: *std.mem.Allocator) void,
};

pub const Keys = [_]Key{.{ .keysym = c.XK_Return, .action = &actions.openTerminal }};
