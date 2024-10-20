const std = @import("std");

const x11 = @import("x11.zig");
const c = @import("x11.zig").c;

const Window = @import("Window.zig").Window;
const Workspace = @import("Workspace.zig").Workspace;
const Statusbar = @import("Statusbar.zig").Statusbar;
const Background = @import("Background.zig").Background;

const A = @import("Atoms.zig");
const Atoms = @import("Atoms.zig").Atoms;

const Actions = @import("actions.zig");

const Config = @import("config");

pub const Layout = struct {
    allocator: *std.mem.Allocator,

    x_display: *const c.Display,
    x_screen: *const c.Screen,
    x_rootwindow: c.Window,

    screen_w: c_int,
    screen_h: c_int,

    statusbar: Statusbar,
    background: Background,
    workspaces: std.ArrayList(Workspace),
    current_ws: u32,

    bg_thread: std.Thread,

    atoms: Atoms,
};

pub var layout: Layout = undefined;

pub fn setupLayout() void {} // setupLayout
