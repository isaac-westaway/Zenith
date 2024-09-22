const std = @import("std");

const Logger = @import("zlog");

const c = @import("x11.zig").c;

const Actions = @import("actions.zig");
const Keys = @import("keys.zig");

// TODO: investigate the "unable to find window" errors in windowToNode, especially regarding windows and subwindows

const Window = struct {
    window: c.Window,
    fullscreen: bool,
    modified: bool,

    // We need fullscreen window data because what if the user chooses to move around the fullscreen window
    f_x: i32,
    f_y: i32,

    f_w: u32,
    f_h: u32,

    w_x: i32,
    w_y: i32,

    w_w: u32,
    w_h: u32,
};

// Is there an elegant way of maintaining the stacking index of windows?
const Workspace = struct {
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

pub const Layout = struct {
    allocator: *std.mem.Allocator,

    x_display: *const c.Display,
    x_rootwindow: *const c.Window,
    x_screen: *const c.Screen,

    screen_w: c_int,
    screen_h: c_int,

    // Allow for dynamic workspace creation, similar to windows creating desktops
    workspaces: std.ArrayList(Workspace),
    current_ws: u32,

    fn windowToNode(self: *const Layout, window: c.Window) ?*std.DoublyLinkedList(Window).Node {
        var ptr: ?*std.DoublyLinkedList(Window).Node = self.workspaces.items[self.current_ws].windows.first;

        while (ptr) |node| : (ptr = node.next) {
            if (node.data.window == window) {
                Logger.Log.info("ZWM_RUN_WINTONODE", "Found Window: {d} in workspace: {d}", .{ node.data.window, self.current_ws }) catch {};
                return node;
            } else continue;
        }

        Logger.Log.err("ZWM_RUN_WINTONODE", "Unable to find window in window list: {d}", .{window}) catch {};
        return null;
    }

    pub fn init(allocator: *std.mem.Allocator, display: *const c.Display, window: *const c.Window) !Layout {
        var layout: Layout = undefined;

        layout.allocator = allocator;

        layout.x_display = display;
        layout.x_rootwindow = window;

        const screen = c.DefaultScreen(@constCast(layout.x_display));

        const initial_number_of_workspaces: comptime_int = 5;

        layout.workspaces = std.ArrayList(Workspace).init(layout.allocator.*);

        for (0..initial_number_of_workspaces) |index| {
            _ = index;

            const workspace: Workspace = undefined;

            try layout.workspaces.append(workspace);
        }

        // 0 for the start of the array, in the window manager's taskbar, this should be one
        layout.current_ws = 0;
        for (layout.workspaces.items) |*workspace| {
            workspace.* = Workspace{
                .windows = std.DoublyLinkedList(Window){},
                .fullscreen = false,
                .fs_window = undefined,
                .current_focused_window = undefined,
                .mouse = undefined,
                .win_x = 0,
                .win_y = 0,
                .win_w = 0,
                .win_h = 0,
            };
        }

        layout.screen_w = @intCast(c.XDisplayWidth(@constCast(display), screen));
        layout.screen_h = @intCast(c.XDisplayHeight(@constCast(display), screen));

        return layout;
    }

    // Should be broken into its own functions in actions.zig
    pub fn resolveKeyInput(self: *Layout, event: *c.XKeyPressedEvent) !void {
        // TODO: make this more dynamic, to see keycodes run `xev` in a terminal
        if (event.keycode == 36) {
            Actions.openTerminal(self.allocator);

            return;
        }

        if (event.keycode == 9) {
            try Logger.Log.fatal("ZWM_RUN_KEYPRESSED_RESOLVEKEYINPUT", "Closing Window Manager", .{});
        }

        if (event.keycode == 41) {
            // TODO: set border width and colour in a config

            if (self.workspaces.items[self.current_ws].fullscreen == false) {
                var attributes: c.XWindowAttributes = undefined;
                _ = c.XGetWindowAttributes(@constCast(self.x_display), self.workspaces.items[self.current_ws].current_focused_window.data.window, &attributes);

                const window = self.windowToNode(self.workspaces.items[self.current_ws].current_focused_window.data.window);

                if (window) |win| {
                    win.data.f_x = attributes.x;
                    win.data.f_y = attributes.y;

                    // Why is it possible that the width and height of the window be negative????
                    win.data.f_w = @abs(attributes.width);
                    win.data.f_h = @abs(attributes.height);

                    _ = c.XSetWindowBorderWidth(@constCast(self.x_display), win.data.window, 1);

                    _ = c.XRaiseWindow(@constCast(self.x_display), win.data.window);
                    _ = c.XMoveWindow(@constCast(self.x_display), win.data.window, 0, 0);
                    _ = c.XResizeWindow(@constCast(self.x_display), win.data.window, @as(c_uint, @intCast(self.screen_w)) - 2, @as(c_uint, @intCast(self.screen_h)) - 2);

                    self.workspaces.items[self.current_ws].fs_window = @ptrCast(window);
                }

                self.workspaces.items[self.current_ws].fullscreen = true;

                return;
            }

            if (self.workspaces.items[self.current_ws].fullscreen == true) {
                _ = c.XSetWindowBorderWidth(@constCast(self.x_display), self.workspaces.items[self.current_ws].fs_window.data.window, 5);

                _ = c.XMoveWindow(@constCast(self.x_display), self.workspaces.items[self.current_ws].fs_window.data.window, self.workspaces.items[self.current_ws].fs_window.data.f_x, self.workspaces.items[self.current_ws].fs_window.data.f_y);
                _ = c.XResizeWindow(@constCast(self.x_display), self.workspaces.items[self.current_ws].fs_window.data.window, @as(c_uint, @intCast(self.workspaces.items[self.current_ws].fs_window.data.f_w)), @as(c_uint, @intCast(self.workspaces.items[self.current_ws].fs_window.data.f_h)));
                self.workspaces.items[self.current_ws].fullscreen = false;

                return;
            }
        }

        if (event.keycode == 23 and self.workspaces.items[self.current_ws].windows.len >= 1 and (event.state & c.Mod4Mask) != 0) {
            // -1 left, 1 right
            const direction: i2 = if ((event.state & c.ShiftMask) != 0) -1 else 1;

            if (direction == 1) {
                if (self.workspaces.items[self.current_ws].windows.last.?.data.window == self.workspaces.items[self.current_ws].current_focused_window.data.window) {
                    self.workspaces.items[self.current_ws].current_focused_window = @ptrCast(self.workspaces.items[self.current_ws].windows.first);
                } else if (self.workspaces.items[self.current_ws].current_focused_window.next == null) {
                    self.workspaces.items[self.current_ws].current_focused_window = @ptrCast(self.workspaces.items[self.current_ws].windows.first);
                } else {
                    self.workspaces.items[self.current_ws].current_focused_window = @ptrCast(self.workspaces.items[self.current_ws].current_focused_window.next);
                }
            } else {
                if (self.workspaces.items[self.current_ws].windows.first.?.data.window == self.workspaces.items[self.current_ws].current_focused_window.data.window) {
                    self.workspaces.items[self.current_ws].current_focused_window = @ptrCast(self.workspaces.items[self.current_ws].windows.last);
                } else if (self.workspaces.items[self.current_ws].current_focused_window.prev == null) {
                    self.workspaces.items[self.current_ws].current_focused_window = @ptrCast(self.workspaces.items[self.current_ws].windows.last);
                } else {
                    self.workspaces.items[self.current_ws].current_focused_window = @ptrCast(self.workspaces.items[self.current_ws].current_focused_window.prev);
                }
            }

            _ = c.XRaiseWindow(@constCast(self.x_display), self.workspaces.items[self.current_ws].current_focused_window.data.window);
            _ = c.XSetInputFocus(@constCast(self.x_display), self.workspaces.items[self.current_ws].current_focused_window.data.window, c.RevertToParent, c.CurrentTime);
            _ = c.XSetWindowBorder(@constCast(self.x_display), self.workspaces.items[self.current_ws].current_focused_window.data.window, 0xFFFFFF);

            var ptr: ?*std.DoublyLinkedList(Window).Node = self.workspaces.items[self.current_ws].windows.first;
            while (ptr) |node| : (ptr = node.next) {
                if (node.data.window != self.workspaces.items[self.current_ws].current_focused_window.data.window) {
                    _ = c.XSetWindowBorder(@constCast(self.x_display), node.data.window, 0x333333);
                }
            }

            return;
        }

        // right
        // Create a `workspace` struct in another file and offload a lot of this file
        // Lots of indentaation, could easily move this into another separate file and function
        if (event.keycode == 40) {
            try Logger.Log.info("ZWM_RUN_ONKEYPRESS_HANDLEKEYPRESS", "Current Workspace: {d}", .{self.current_ws});
            if (self.current_ws == self.workspaces.items.len - 1) {
                self.current_ws = 0;

                try Logger.Log.info("ZWM_RUN_ONKEYPRESS_HANDLEKEYPRESS", "Mapping a bunch of windows", .{});
                var ptr: ?*std.DoublyLinkedList(Window).Node = self.workspaces.items[self.current_ws].windows.last;

                while (ptr) |node| : (ptr = node.prev) {
                    _ = c.XMapWindow(@constCast(self.x_display), node.data.window);
                }
            } else {
                self.current_ws += 1;
                // If the previous has windows, unmap all of it
                // unmap previous windows and map current index in self.current_ws
                if (self.workspaces.items[self.current_ws - 1].windows.len > 0) {

                    // Unmap all windows of the previous workspace
                    var ptr: ?*std.DoublyLinkedList(Window).Node = self.workspaces.items[self.current_ws - 1].windows.first;
                    while (ptr) |node| : (ptr = node.next) {
                        _ = c.XUnmapWindow(@constCast(self.x_display), node.data.window);
                    }
                }

                if (self.workspaces.items[self.current_ws].windows.len > 0) {
                    try Logger.Log.info("ZWM_RUN_ONKEYPRESS_HANDLEKEYPRESS", "Mapping a bunch of windows", .{});
                    var ptr: ?*std.DoublyLinkedList(Window).Node = self.workspaces.items[self.current_ws].windows.last;

                    while (ptr) |node| : (ptr = node.prev) {
                        _ = c.XMapWindow(@constCast(self.x_display), node.data.window);
                    }
                }
            }
        }

        if (event.keycode == 38) {
            if (self.current_ws == 0) {
                self.current_ws = @intCast(self.workspaces.items.len);
            } else {
                self.current_ws -= 1;
            }
        }
    }

    pub fn handleCreateNotify(self: *const Layout, event: *const c.XCreateWindowEvent) !void {
        _ = self;

        try Logger.Log.info("ZWM_RUN_CREATENOTIFY_HANDLECREATENOTIFY", "Handling Create Notification: {d}", .{event.window});
    }

    pub fn handleMapRequest(self: *Layout, event: *const c.XMapRequestEvent) !void {
        try Logger.Log.info("ZWM_RUN_MAPREQUEST", "Handling Map Request", .{});
        _ = c.XSelectInput(@constCast(self.x_display), event.window, c.StructureNotifyMask | c.EnterWindowMask | c.LeaveWindowMask);

        // TODO: update this so that the doubly linked list type isnot a window but a struct containing the windows x and y and w and h vals and staccking order
        const window: Window = Window{ .window = event.window, .modified = false, .fullscreen = false, .w_x = 0, .w_y = 0, .w_w = 0, .w_h = 0, .f_x = 0, .f_y = 0, .f_w = 0, .f_h = 0 };

        var node: *std.DoublyLinkedList(Window).Node = try self.allocator.*.create(std.DoublyLinkedList(Window).Node);
        node.data = window;
        self.workspaces.items[self.current_ws].windows.prepend(node);

        if (self.workspaces.items[self.current_ws].windows.len >= 2) {
            _ = c.XMapWindow(@constCast(self.x_display), event.window);
            _ = c.XSetWindowBorderWidth(@constCast(self.x_display), event.window, 5);
            _ = c.XSetWindowBorder(@constCast(self.x_display), event.window, 0x333333);

            _ = c.XResizeWindow(@constCast(self.x_display), self.workspaces.items[self.current_ws].windows.first.?.data.window, @divFloor(@abs(self.screen_w - 10), 2), @abs(self.screen_h - 10));
            _ = c.XMoveWindow(@constCast(self.x_display), self.workspaces.items[self.current_ws].windows.first.?.data.window, 0, 0);

            var start: ?*std.DoublyLinkedList(Window).Node = self.workspaces.items[self.current_ws].windows.first.?.next.?;

            // Todo: fix some small details in the width and height
            // Todo: add mod4 + spacebar to auto till again
            // Auto tile just makes the currently focused window take up the entire sceren without fullscreening
            var index: u64 = 0;
            while (start) |win| : (start = win.next) {
                _ = c.XResizeWindow(@constCast(self.x_display), win.data.window, @intCast(@divFloor(@abs(self.screen_w - 10), 2)), @intCast((@divFloor(@abs(self.screen_h - 10), (self.workspaces.items[self.current_ws].windows.len - 1)) - (1 * self.workspaces.items[self.current_ws].windows.len) - 10)));

                // so much casting :(
                const height_of_each_window: c_int = @intCast(@divFloor(self.screen_h, @as(c_int, @intCast((self.workspaces.items[self.current_ws].windows.len - 1)))));

                // This could be done by updating the `Window` type to store all of its parameters
                _ = c.XMoveWindow(@constCast(self.x_display), win.data.window, @intCast(@divFloor(self.screen_w, 2) + 10), @intCast(((height_of_each_window) * @as(c_int, @intCast(index)))));
                _ = c.XRaiseWindow(@constCast(self.x_display), win.data.window);
                index += 1;
            }

            // TODO: set border width and colour in a config
        } else {
            _ = c.XResizeWindow(@constCast(self.x_display), event.window, @abs(self.screen_w - 10), @abs(self.screen_h - 10));

            // TODO: set border width and colour in a config
            _ = c.XMapWindow(@constCast(self.x_display), event.window);
            _ = c.XSetWindowBorderWidth(@constCast(self.x_display), event.window, 5);
            _ = c.XSetWindowBorder(@constCast(self.x_display), event.window, 0x333333);
        }

        var attributes: c.XWindowAttributes = undefined;
        _ = c.XGetWindowAttributes(@constCast(self.x_display), event.window, &attributes);

        self.workspaces.items[self.current_ws].windows.last.?.data.w_x = attributes.x;
        self.workspaces.items[self.current_ws].windows.last.?.data.w_y = attributes.y;

        // Again, why can the width and height of the window be negative?
        self.workspaces.items[self.current_ws].windows.last.?.data.w_w = @abs(attributes.width);
        self.workspaces.items[self.current_ws].windows.last.?.data.w_h = @abs(attributes.height);
    }

    pub fn handleDestroyNotify(self: *Layout, event: *const c.XDestroyWindowEvent) !void {
        try Logger.Log.info("HANDLEDESTROYNOTIFY", "Current Workspace: {d}", .{self.current_ws});
        const window = self.windowToNode(event.window);

        if (window) |w| {
            self.workspaces.items[self.current_ws].windows.remove(w);
            self.allocator.destroy(w);

            if (self.workspaces.items[self.current_ws].windows.len >= 1) {
                self.workspaces.items[self.current_ws].current_focused_window = @ptrCast(self.workspaces.items[self.current_ws].windows.last);
            }
        }

        _ = c.XSetInputFocus(@constCast(self.x_display), c.DefaultRootWindow(@constCast(self.x_display)), c.RevertToParent, c.CurrentTime);
    }

    pub fn handleButtonPress(self: *Layout, event: *const c.XButtonPressedEvent) !void {
        if (event.subwindow == 0) return;
        var attributes: c.XWindowAttributes = undefined;
        _ = c.XGetWindowAttributes(@constCast(self.x_display), event.subwindow, &attributes);

        self.workspaces.items[self.current_ws].win_w = attributes.width;
        self.workspaces.items[self.current_ws].win_h = attributes.height;
        self.workspaces.items[self.current_ws].win_x = attributes.x;
        self.workspaces.items[self.current_ws].win_y = attributes.y;

        self.workspaces.items[self.current_ws].mouse = @constCast(event).*;

        _ = c.XRaiseWindow(@constCast(self.x_display), event.subwindow);

        const window = self.windowToNode(event.window);
        if (window) |w| {
            self.workspaces.items[self.current_ws].windows.remove(w);
            self.workspaces.items[self.current_ws].windows.prepend(w);
        }
    }

    // TODO: raise the window when clicked
    pub fn handleMotionNotify(self: *Layout, event: *const c.XMotionEvent) !void {
        const diff_mag_x: c_int = event.x - self.workspaces.items[self.current_ws].mouse.x;
        const diff_mag_y: c_int = event.y - self.workspaces.items[self.current_ws].mouse.y;

        const new_x: c_int = self.workspaces.items[self.current_ws].win_x + diff_mag_x;
        const new_y: c_int = self.workspaces.items[self.current_ws].win_y + diff_mag_y;

        const w_x: c_uint = @abs(self.workspaces.items[self.current_ws].win_w + (event.x - self.workspaces.items[self.current_ws].mouse.x));
        const w_y: c_uint = @abs(self.workspaces.items[self.current_ws].win_h + (event.y - self.workspaces.items[self.current_ws].mouse.y));

        const button: c_uint = self.workspaces.items[self.current_ws].mouse.button;

        const window = self.windowToNode(event.window);
        if (window) |w| {
            w.data.modified = true;
            self.workspaces.items[self.current_ws].windows.remove(w);
            self.workspaces.items[self.current_ws].windows.prepend(w);
        }

        _ = c.XRaiseWindow(@constCast(self.x_display), event.window);

        // TODO: set border width and colour in a config
        // TODO: handle window movement and reisizing when fullscreen is true
        if (button == 1 and self.workspaces.items[self.current_ws].fullscreen == false) {
            _ = c.XSetWindowBorder(@constCast(self.x_display), event.subwindow, 0xFFFFFF);
            _ = c.XMoveWindow(@constCast(self.x_display), event.subwindow, new_x, new_y);
        }

        if (button == 3 and self.workspaces.items[self.current_ws].fullscreen == false) {
            self.workspaces.items[self.current_ws].fullscreen = false;

            _ = c.XSetWindowBorder(@constCast(self.x_display), event.subwindow, 0xFFFFFF);
            _ = c.XResizeWindow(@constCast(self.x_display), event.subwindow, w_x, w_y);
        }
    }

    // TODO: on hover, raise window
    pub fn handleEnterNotify(self: *Layout, event: *const c.XCrossingEvent) !void {
        // TODO: set border width and colour in a config
        _ = c.XSetInputFocus(@constCast(self.x_display), event.window, c.RevertToParent, c.CurrentTime);
        _ = c.XSetWindowBorder(@constCast(self.x_display), event.window, 0xFFFFFF);

        // Traverse the window list and make the node with the data equal to the event.window the current focused
        const window = self.windowToNode(event.window);

        self.workspaces.items[self.current_ws].current_focused_window = @ptrCast(window);
    }

    pub fn handleLeaveNotify(self: *Layout, event: *const c.XCrossingEvent) !void {
        // TODO: set border width and colour in a config
        _ = c.XSetWindowBorder(@constCast(self.x_display), event.window, 0x333333);

        // unfocus window
        _ = c.XSetInputFocus(@constCast(self.x_display), c.DefaultRootWindow(@constCast(self.x_display)), c.RevertToParent, c.CurrentTime);
    }
};
