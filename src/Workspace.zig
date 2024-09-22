const std = @import("std");

const Logger = @import("zlog");

const c = @import("x11.zig").c;

const Window = @import("Window.zig").Window;

const Actions = @import("actions.zig");
const Keys = @import("keys.zig");

pub const Workspace = struct {
    windows: std.DoublyLinkedList(Window),
    current_focused_window: *std.DoublyLinkedList(Window).Node,

    fullscreen: bool,
    fs_window: *std.DoublyLinkedList(Window).Node,

    // Could be moved into `Layout` scope
    mouse: c.XButtonEvent,

    // Temp variables when a window is clicked to handle the point between clicking and clicking and dragging
    win_x: i32,
    win_y: i32,
    win_w: i32,
    win_h: i32,
};
