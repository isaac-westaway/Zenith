const std = @import("std");

const Logger = @import("zlog");

const c = @import("x11.zig").c;

pub const Layout = struct {
    allocator: *std.mem.Allocator,

    x_display: *const c.Display,
    x_rootwindow: *const c.Window,
    x_screen: *const c.Screen,

    workspace: struct {
        mouse: c.XButtonEvent,

        win_x: i32,
        win_y: i32,
        win_w: i32,
        win_h: i32,

        screen_w: c_uint,
        screen_h: c_uint,
        center_w: c_uint,
        center_h: c_uint,
    },

    pub fn init(allocator: *std.mem.Allocator, display: *const c.Display, window: *const c.Window) !Layout {
        var layout: Layout = undefined;

        layout.allocator = allocator;

        layout.x_display = display;
        layout.x_rootwindow = window;

        const screen = c.DefaultScreen(@constCast(layout.x_display));

        layout.workspace.mouse = undefined;

        layout.workspace.win_x = undefined;
        layout.workspace.win_y = undefined;
        layout.workspace.win_w = undefined;
        layout.workspace.win_h = undefined;

        layout.workspace.screen_w = @intCast(c.XDisplayWidth(@constCast(display), screen));
        layout.workspace.screen_h = @intCast(c.XDisplayHeight(@constCast(display), screen));

        layout.workspace.center_w = undefined;
        layout.workspace.center_h = undefined;

        return layout;
    }

    pub fn handleCreateNotify(self: *const Layout, event: *const c.XCreateWindowEvent) !void {
        _ = self;

        try Logger.Log.info("ZWM_RUN_CREATENOTIFY_HANDLECREATENOTIFY", "Handling Create Notification: {any}", .{event.window});
    }

    pub fn handleMapRequest(self: *const Layout, event: *const c.XMapRequestEvent) !void {
        _ = c.XMapWindow(@constCast(self.x_display), event.window);
        _ = c.XSetWindowBorderWidth(@constCast(self.x_display), event.window, 5);
        _ = c.XSetWindowBorder(@constCast(self.x_display), event.window, 0x333333);

        // for tiling, set the window size here
        _ = c.XResizeWindow(@constCast(self.x_display), event.window, self.workspace.screen_w - 10, self.workspace.screen_h - 10);

        var attributes: c.XWindowAttributes = undefined;
        _ = c.XGetWindowAttributes(@constCast(self.x_display), event.window, &attributes);
    }

    pub fn handleButtonPress(self: *Layout, event: *const c.XButtonPressedEvent) !void {
        if (event.subwindow == 0) return;
        var attributes: c.XWindowAttributes = undefined;
        _ = c.XGetWindowAttributes(@constCast(self.x_display), event.subwindow, &attributes);

        self.workspace.win_w = attributes.width;
        self.workspace.win_h = attributes.height;
        self.workspace.win_x = attributes.x;
        self.workspace.win_y = attributes.y;

        self.workspace.mouse = @constCast(event).*;
    }

    pub fn handleMotionNotify(self: *const Layout, event: *const c.XMotionEvent) !void {
        const diff_mag_x: c_int = event.x - self.workspace.mouse.x;
        const diff_mag_y: c_int = event.y - self.workspace.mouse.y;

        const new_x: c_int = self.workspace.win_x + diff_mag_x;
        const new_y: c_int = self.workspace.win_y + diff_mag_y;

        const w_x: c_uint = @intCast(self.workspace.win_w + (event.x - self.workspace.mouse.x));
        const w_y: c_uint = @intCast(self.workspace.win_h + (event.y - self.workspace.mouse.y));

        const button: c_uint = self.workspace.mouse.button;

        if (button == 1) {
            _ = c.XMoveWindow(@constCast(self.x_display), event.subwindow, new_x, new_y);
        } else if (button == 3) {
            _ = c.XResizeWindow(@constCast(self.x_display), event.subwindow, w_x, w_y);
        } else {
            try Logger.Log.info("ZWM_RUN_MOTIONNOTIFY_HANDLEMOTIONNOTIFY", "Logical Comparison did NOT work: {d}", .{button});
        }
    }
};
