const std = @import("std");

const c = @import("x11.zig").c;

const Config = @import("config");

pub const Layout = struct {
    allocator: *std.mem.Allocator,

    x_display: *c.Display,
    x_rootwindow: c.Window,

    // workspaces: std.ArrayList(Workspace),
    current_ws: u32,
};

pub var layout: Layout = undefined;

pub fn setupLayout() void {} // setupLayout

pub fn handleMapRequest(event: *c.xcb_generic_event_t) void {
    const map_request_event: *c.xcb_map_request_event_t = @ptrCast(event);
    _ = map_request_event;
} // handleMapRequest
