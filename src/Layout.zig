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
        mouse_button: u32,

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

        layout.workspace.screen_w = @intCast(c.XDisplayWidth(@constCast(display), screen));
        layout.workspace.screen_h = @intCast(c.XDisplayHeight(@constCast(display), screen));

        layout.workspace = undefined;

        return layout;
    }

    pub fn handleCreateNotify(self: *const Layout, event: *const c.XCreateWindowEvent) !void {
        _ = self;

        try Logger.Log.info("ZWM_RUN_HANDLECREATENOTIFY", "Handling Create Notification: {any}", .{event.window});
    }

    pub fn handleMapRequest(self: *const Layout, event: *const c.XMapRequestEvent) !void {
        var window_attributes: c.XWindowAttributes = undefined;
        _ = c.XGetWindowAttributes(@constCast(self.x_display), event.window, &window_attributes);

        _ = c.XMapWindow(@constCast(self.x_display), event.window);
        _ = c.XSetWindowBorderWidth(@constCast(self.x_display), event.window, 5);
        _ = c.XSetWindowBorder(@constCast(self.x_display), event.window, 0x333333);
    }

    pub fn handleButtonPress(self: *Layout, event: *const c.XButtonPressedEvent) !void {
        // This outputs a 1, one
        try Logger.Log.info("ZWM_RUN_BUTTONPRESSED_HANDLEBUTTONPRESSED", "Button Pressed: {d}", .{event.button});

        if (event.subwindow == 0) return;
        var attributes: c.XWindowAttributes = undefined;
        _ = c.XGetWindowAttributes(@constCast(self.x_display), event.subwindow, &attributes);

        self.workspace.win_w = attributes.width;
        self.workspace.win_h = attributes.height;
        self.workspace.win_x = attributes.x;
        self.workspace.win_y = attributes.y;

        self.workspace.mouse = @constCast(event).*;
        self.workspace.mouse_button = @intCast(event.button);

        // This outputs a 1, one
        try Logger.Log.info("ZWM_RUN_BUTTON_PRESSED_HANDLEBUTTONPRESSED", "Button Window Details: W:{d}, H:{d}, X:{d}, Y:{d}", .{ self.workspace.win_w, self.workspace.win_h, self.workspace.win_x, self.workspace.win_y });
    }

    pub fn handleMotionNotify(self: *const Layout, event: *const c.XMotionEvent) !void {
        // const dx: i32 = @intCast(event.x_root - self.workspace.mouse.x_root);
        // const dy: i32 = @intCast(event.y_root - self.workspace.mouse.y_root);
        try Logger.Log.info("ZWM_RUN_BUTTON_PRESSED_HANDLEBUTTONPRESSED", "Motion Window Details: X:{d}, Y:{d}", .{ event.x, event.y });

        // We want to move relative from the initial position to the pointer, not make the windows x and y coords (top left) THE coords of the pointer

        const button: c_uint = self.workspace.mouse.button;

        if (button == 1) {
            try Logger.Log.info("ZWM_RUN_HANDLEMOTIONNOTIFY", "Moving Window", .{});
            _ = c.XMoveWindow(@constCast(self.x_display), event.subwindow, event.x, event.y);
        } else if (button == 3) {
            try Logger.Log.info("ZWM_RUN_MOTIONNOTIFY_HANDLEMOTIONNOTIFY", "Unhandled", .{});
            // _ = c.XMoveResizeWindow(@constCast(self.x_display), event.window, self.workspace.win_x, self.workspace.win_y, @as(c_uint, @intCast(self.workspace.win_w)) + dx, @as(c_uint, @intCast(self.workspace.win_h)) + dy);
        } else {
            try Logger.Log.info("ZWM_RUN_MOTIONNOTIFY_HANDLEMOTIONNOTIFY", "Logical Comparison did NOT work: {d}", .{button});
        }
    }
};
