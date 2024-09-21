const std = @import("std");

const Logger = @import("zlog");

const c = @import("x11.zig").c;

const Actions = @import("actions.zig");
const Keys = @import("keys.zig");

// Fix the design of the window manager by having each window have its own x,y w,h fullscreen, and focused attribute
const Window = struct { window: c.Window };

pub const Layout = struct {
    allocator: *std.mem.Allocator,

    x_display: *const c.Display,
    x_rootwindow: *const c.Window,
    x_screen: *const c.Screen,

    // make this an std.Array to have multiple workspaces traversible by mod4+D
    workspace: struct {
        // Why is every implementation of a window manager using a doubly linked list?
        windows: std.DoublyLinkedList(Window),
        current_focused_window: *std.DoublyLinkedList(Window).Node,

        fullscreen: bool,
        fullscreen_prev_x: c_int,
        fullscreen_prev_y: c_int,
        fullscreen_prev_h: c_int,
        fullscreen_prev_w: c_int,

        mouse: c.XButtonEvent,

        // Temp variables when a window is clicked to handle the point between clicking and clicking and dragging
        win_x: i32,
        win_y: i32,
        win_w: i32,
        win_h: i32,

        screen_w: c_uint,
        screen_h: c_uint,
    },

    pub fn init(allocator: *std.mem.Allocator, display: *const c.Display, window: *const c.Window) !Layout {
        var layout: Layout = undefined;

        layout.allocator = allocator;

        layout.x_display = display;
        layout.x_rootwindow = window;

        const screen = c.DefaultScreen(@constCast(layout.x_display));

        layout.workspace.windows = std.DoublyLinkedList(Window){};

        layout.workspace.fullscreen = false;

        layout.workspace.screen_w = @intCast(c.XDisplayWidth(@constCast(display), screen));
        layout.workspace.screen_h = @intCast(c.XDisplayHeight(@constCast(display), screen));

        return layout;
    }

    pub fn resolveKeyInput(self: *Layout, event: *c.XKeyPressedEvent) !void {
        try Logger.Log.info("ZWM_RUN_KEYPRESSED_RESOLVEKEYINPUT", "Attempting to resolve key pressed with the keycode: {any}", .{event.keycode});

        // TODO: make this more dynamic, to see keycodes run `xev` in a terminal
        if (event.keycode == 36) {
            try Logger.Log.info("ZWM_RUN_KEYPRESSED_RESOLVEKEYINPUT", "XK_Return pressed", .{});
            Actions.openTerminal(self.allocator);

            return;
        }

        if (event.keycode == 9) {
            // Exit
            try Logger.Log.fatal("ZWM_RUN_KEYPRESSED_RESOLVEKEYINPUT", "Closing Window Manager", .{});

            return; // this is unreachable
        }

        if (event.keycode == 41) {
            try Logger.Log.info("ZWM_RUN_KEYPRESSED_RESOLVEKEYINPUT", "Toggling fullscreen", .{});

            // TODO: set border width and colour in a config

            if (self.workspace.fullscreen == false) {
                var attributes: c.XWindowAttributes = undefined;
                _ = c.XGetWindowAttributes(@constCast(self.x_display), self.workspace.current_focused_window.data.window, &attributes);

                self.workspace.fullscreen_prev_x = attributes.x;
                self.workspace.fullscreen_prev_y = attributes.y;

                self.workspace.fullscreen_prev_w = attributes.width;
                self.workspace.fullscreen_prev_h = attributes.height;

                _ = c.XSetWindowBorderWidth(@constCast(self.x_display), self.workspace.current_focused_window.data.window, 1);

                _ = c.XRaiseWindow(@constCast(self.x_display), self.workspace.current_focused_window.data.window);
                _ = c.XMoveWindow(@constCast(self.x_display), self.workspace.current_focused_window.data.window, 0, 0);
                _ = c.XResizeWindow(@constCast(self.x_display), self.workspace.current_focused_window.data.window, @as(c_uint, @intCast(self.workspace.screen_w)) - 2, @as(c_uint, @intCast(self.workspace.screen_h)) - 2);

                self.workspace.fullscreen = true;

                return;
            }

            if (self.workspace.fullscreen == true) {
                _ = c.XSetWindowBorderWidth(@constCast(self.x_display), self.workspace.current_focused_window.data.window, 5);

                _ = c.XMoveWindow(@constCast(self.x_display), self.workspace.current_focused_window.data.window, self.workspace.fullscreen_prev_x, self.workspace.fullscreen_prev_y);
                _ = c.XResizeWindow(@constCast(self.x_display), self.workspace.current_focused_window.data.window, @as(c_uint, @intCast(self.workspace.fullscreen_prev_w)), @as(c_uint, @intCast(self.workspace.fullscreen_prev_h)));
                self.workspace.fullscreen = false;

                return;
            }
        }

        // TODO: could probably implement mod4+shift+tab to go backwards, but that seems trivial
        if (event.keycode == 23 and self.workspace.windows.len > 0) {
            if (self.workspace.windows.last.?.data.window == self.workspace.current_focused_window.data.window) {
                self.workspace.current_focused_window = @ptrCast(self.workspace.windows.first);
            } else if (self.workspace.current_focused_window.next == null) {
                self.workspace.current_focused_window = @ptrCast(self.workspace.windows.first);
            } else {
                self.workspace.current_focused_window = @ptrCast(self.workspace.current_focused_window.next);
            }

            _ = c.XRaiseWindow(@constCast(self.x_display), self.workspace.current_focused_window.data.window);
            _ = c.XSetInputFocus(@constCast(self.x_display), self.workspace.current_focused_window.data.window, c.RevertToParent, c.CurrentTime);
            _ = c.XSetWindowBorder(@constCast(self.x_display), self.workspace.current_focused_window.data.window, 0xFFFFFF);

            // This should either be self.workspace.windows.first or self.workspace.current_focused_window
            // The choice is solely on the design principles and UX of a window manager
            var ptr: ?*std.DoublyLinkedList(Window).Node = self.workspace.windows.first;

            while (ptr) |node| : (ptr = node.next) {
                if (node.data.window == self.workspace.current_focused_window.data.window) {
                    continue;
                } else {
                    _ = c.XSetWindowBorder(@constCast(self.x_display), node.data.window, 0x333333);
                }
            }

            return;
        }
    }

    pub fn handleCreateNotify(self: *const Layout, event: *const c.XCreateWindowEvent) !void {
        _ = self;

        try Logger.Log.info("ZWM_RUN_CREATENOTIFY_HANDLECREATENOTIFY", "Handling Create Notification: {d}", .{event.window});
    }

    pub fn handleMapRequest(self: *Layout, event: *const c.XMapRequestEvent) !void {
        try Logger.Log.info("ZWM_RUN_MAPREQUEST_HANDLEMAPREQUEST", "Mapping Window: {d}", .{event.window});

        _ = c.XSelectInput(@constCast(self.x_display), event.window, c.StructureNotifyMask | c.EnterWindowMask | c.LeaveWindowMask);

        // TODO: update this so that the doubly linked list type isnot a window but a struct containing the windows x and y and w and h vals and staccking order
        const window: Window = Window{
            .window = event.window,
        };

        var node: *std.DoublyLinkedList(Window).Node = try self.allocator.*.create(std.DoublyLinkedList(Window).Node);
        node.data = window;
        self.workspace.windows.append(node);

        _ = c.XResizeWindow(@constCast(self.x_display), event.window, self.workspace.screen_w - 10, self.workspace.screen_h - 10);

        // TODO: set border width and colour in a config
        _ = c.XMapWindow(@constCast(self.x_display), event.window);
        _ = c.XSetWindowBorderWidth(@constCast(self.x_display), event.window, 5);
        _ = c.XSetWindowBorder(@constCast(self.x_display), event.window, 0x333333);
    }

    pub fn handleDestroyNotify(self: *Layout, event: *const c.XDestroyWindowEvent) !void {
        try Logger.Log.info("ZWM_RUN_DESTROYNOTIFY_HANDLEDESTROYNOTIFY", "Destroying Window: {d}", .{event.window});

        var ptr: ?*std.DoublyLinkedList(Window).Node = self.workspace.windows.first orelse return;

        var window: ?*std.DoublyLinkedList(Window).Node = null;

        while (ptr) |node| : (ptr = node.next) {
            if (node.data.window == event.window) {
                window = node;
                break;
            } else continue;
        }

        try Logger.Log.info("ZWM_RUN_DESTROYNOTIFY_HANDLEDESTROYNOTIFY", "Window List Size: {d}", .{self.workspace.windows.len});
        if (window) |w| {
            self.workspace.windows.remove(w);
            self.allocator.destroy(w);
        }
        try Logger.Log.info("ZWM_RUN_DESTROYNOTIFY_HANDLEDESTROYNOTIFY", "Window List Size after destruction: {d}", .{self.workspace.windows.len});

        _ = c.XSetInputFocus(@constCast(self.x_display), c.DefaultRootWindow(@constCast(self.x_display)), c.RevertToParent, c.CurrentTime);
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

    pub fn handleMotionNotify(self: *Layout, event: *const c.XMotionEvent) !void {
        const diff_mag_x: c_int = event.x - self.workspace.mouse.x;
        const diff_mag_y: c_int = event.y - self.workspace.mouse.y;

        const new_x: c_int = self.workspace.win_x + diff_mag_x;
        const new_y: c_int = self.workspace.win_y + diff_mag_y;

        // investigate how this can become negative because an error showed up that caused a panic because w_y was negative.
        const w_x: c_uint = @intCast(self.workspace.win_w + (event.x - self.workspace.mouse.x));
        const w_y: c_uint = @intCast(self.workspace.win_h + (event.y - self.workspace.mouse.y));

        const button: c_uint = self.workspace.mouse.button;

        // TODO: set border width and colour in a config
        // TODO: handle window movement and reisizing when fullscreen is true
        if (button == 1) {
            self.workspace.fullscreen = false;

            _ = c.XSetWindowBorder(@constCast(self.x_display), event.subwindow, 0xFFFFFF);
            _ = c.XMoveWindow(@constCast(self.x_display), event.subwindow, new_x, new_y);
        } else if (button == 3) {
            self.workspace.fullscreen = false;

            _ = c.XSetWindowBorder(@constCast(self.x_display), event.subwindow, 0xFFFFFF);
            _ = c.XResizeWindow(@constCast(self.x_display), event.subwindow, w_x, w_y);
        } else {
            try Logger.Log.info("ZWM_RUN_MOTIONNOTIFY_HANDLEMOTIONNOTIFY", "Logical Comparison did NOT work: {d}", .{button});
        }
    }

    pub fn handleEnterNotify(self: *Layout, event: *const c.XCrossingEvent) !void {
        // TODO: set border width and colour in a config
        _ = c.XSetInputFocus(@constCast(self.x_display), event.window, c.RevertToParent, c.CurrentTime);
        _ = c.XSetWindowBorder(@constCast(self.x_display), event.window, 0xFFFFFF);

        // Traverse the window list and make the node with the data equal to the event.window the current focused
        var ptr: ?*std.DoublyLinkedList(Window).Node = self.workspace.windows.first;

        var window: ?*std.DoublyLinkedList(Window).Node = null;

        // Two while loops? Goodness Gracious!

        while (ptr) |node| : (ptr = node.next) {
            if (node.data.window == event.window) {
                window = node;
                break;
            } else continue;
        }

        while (ptr) |node| : (ptr = node.next) {
            if (node.next == null) break;

            if (node.data.window == self.workspace.current_focused_window.data.window) {
                continue;
            } else {
                _ = c.XSetWindowBorder(@constCast(self.x_display), node.data.window, 0x333333);
            }
        }

        self.workspace.current_focused_window = @ptrCast(window);
    }

    pub fn handleLeaveNotify(self: *Layout, event: *const c.XCrossingEvent) !void {
        // TODO: set border width and colour in a config
        _ = c.XSetWindowBorder(@constCast(self.x_display), event.window, 0x333333);

        // unfocus window
        _ = c.XSetInputFocus(@constCast(self.x_display), c.DefaultRootWindow(@constCast(self.x_display)), c.RevertToParent, c.CurrentTime);
    }
};
