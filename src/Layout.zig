const std = @import("std");

const Logger = @import("zlog");

const c = @import("x11.zig").c;

const Actions = @import("actions.zig");
const Keys = @import("keys.zig");

// Fix the design of the window manager by having each window have its own x,y w,h fullscreen, and focused attribute
// Begin working on workspaces with window+daa
const Window = struct {
    window: c.Window,
    fullscreen: bool,
    modified: bool,

    f_x: i32,
    f_y: i32,

    f_w: u32,
    f_h: u32,

    w_x: i32,
    w_y: i32,

    w_w: u32,
    w_h: u32,
};

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

        screen_w: c_int,
        screen_h: c_int,
    },

    fn windowToNode(self: *const Layout, window: c.Window) ?*std.DoublyLinkedList(Window).Node {
        var ptr: ?*std.DoublyLinkedList(Window).Node = self.workspace.windows.first;

        while (ptr) |node| : (ptr = node.next) {
            if (node.data.window == window) {
                return node;
            } else continue;
        }

        _ = Logger.Log.err("ZWM_RUN_WINTONODE", "Unable to find window in window list: {d}", .{window}) catch {};
        return null;
    }

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

        if (event.keycode == 23 and self.workspace.windows.len >= 1 and (event.state & c.Mod4Mask) != 0) {
            const direction: i2 = if ((event.state & c.ShiftMask) != 0) -1 else 1;

            if (direction == 1) {
                if (self.workspace.windows.last.?.data.window == self.workspace.current_focused_window.data.window) {
                    self.workspace.current_focused_window = @ptrCast(self.workspace.windows.first);
                } else if (self.workspace.current_focused_window.next == null) {
                    self.workspace.current_focused_window = @ptrCast(self.workspace.windows.first);
                } else {
                    self.workspace.current_focused_window = @ptrCast(self.workspace.current_focused_window.next);
                }
            } else {
                if (self.workspace.windows.first.?.data.window == self.workspace.current_focused_window.data.window) {
                    self.workspace.current_focused_window = @ptrCast(self.workspace.windows.last);
                } else if (self.workspace.current_focused_window.prev == null) {
                    self.workspace.current_focused_window = @ptrCast(self.workspace.windows.last);
                } else {
                    self.workspace.current_focused_window = @ptrCast(self.workspace.current_focused_window.prev);
                }
            }

            _ = c.XRaiseWindow(@constCast(self.x_display), self.workspace.current_focused_window.data.window);
            _ = c.XSetInputFocus(@constCast(self.x_display), self.workspace.current_focused_window.data.window, c.RevertToParent, c.CurrentTime);
            _ = c.XSetWindowBorder(@constCast(self.x_display), self.workspace.current_focused_window.data.window, 0xFFFFFF);

            var ptr: ?*std.DoublyLinkedList(Window).Node = self.workspace.windows.first;
            while (ptr) |node| : (ptr = node.next) {
                if (node.data.window != self.workspace.current_focused_window.data.window) {
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
        _ = c.XSelectInput(@constCast(self.x_display), event.window, c.StructureNotifyMask | c.EnterWindowMask | c.LeaveWindowMask);

        // TODO: update this so that the doubly linked list type isnot a window but a struct containing the windows x and y and w and h vals and staccking order
        const window: Window = Window{
            .window = event.window,
            .modified = false,
        };

        var node: *std.DoublyLinkedList(Window).Node = try self.allocator.*.create(std.DoublyLinkedList(Window).Node);
        node.data = window;
        self.workspace.windows.append(node);

        if (self.workspace.windows.len >= 2) {
            _ = c.XMapWindow(@constCast(self.x_display), event.window);
            _ = c.XSetWindowBorderWidth(@constCast(self.x_display), event.window, 5);
            _ = c.XSetWindowBorder(@constCast(self.x_display), event.window, 0x333333);

            _ = c.XResizeWindow(@constCast(self.x_display), self.workspace.windows.first.?.data.window, @divFloor(@abs(self.workspace.screen_w - 10), 2), @abs(self.workspace.screen_h - 10));

            _ = c.XMoveWindow(@constCast(self.x_display), self.workspace.windows.first.?.next.?.data.window, @intCast(@divFloor(@abs(self.workspace.screen_w - 10), 2)), 0);

            var start: ?*std.DoublyLinkedList(Window).Node = self.workspace.windows.first.?.next.?;

            // Todo: fix some small details in the width and height
            // Todo: add mod4 + spacebar to auto till again
            // Auto tile just makes the currently focused window take up the entire sceren without fullscreening
            var index: u64 = 0;
            while (start) |win| : (start = win.next) {
                _ = c.XResizeWindow(@constCast(self.x_display), win.data.window, @intCast(@divFloor(@abs(self.workspace.screen_w - 10), 2)), @intCast((@divFloor(@abs(self.workspace.screen_h - 10), (self.workspace.windows.len - 1)) - 1 * self.workspace.windows.len)));

                // so much casting :(
                const height_of_each_window: c_int = @intCast(@divFloor(self.workspace.screen_h, @as(c_int, @intCast((self.workspace.windows.len - 1)))));

                // This could be done by updating the `Window` type to store all of its parameters
                _ = c.XMoveWindow(@constCast(self.x_display), win.data.window, @intCast(@divFloor(self.workspace.screen_w, 2) + 10), @intCast(((height_of_each_window) * @as(c_int, @intCast(index)))));
                index += 1;
            }

            // TODO: set border width and colour in a config
        } else {
            _ = c.XResizeWindow(@constCast(self.x_display), event.window, @abs(self.workspace.screen_w - 10), @abs(self.workspace.screen_h - 10));

            // TODO: set border width and colour in a config
            _ = c.XMapWindow(@constCast(self.x_display), event.window);
            _ = c.XSetWindowBorderWidth(@constCast(self.x_display), event.window, 5);
            _ = c.XSetWindowBorder(@constCast(self.x_display), event.window, 0x333333);
        }
    }

    pub fn handleDestroyNotify(self: *Layout, event: *const c.XDestroyWindowEvent) !void {
        const window = self.windowToNode(event.window);

        if (window) |w| {
            self.workspace.windows.remove(w);
            self.allocator.destroy(w);

            if (self.workspace.windows.len >= 1) {
                self.workspace.current_focused_window = @ptrCast(self.workspace.windows.last);
            }
        }

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

        _ = c.XRaiseWindow(@constCast(self.x_display), event.subwindow);
    }

    // TODO: raise the window when clicked
    pub fn handleMotionNotify(self: *Layout, event: *const c.XMotionEvent) !void {
        const diff_mag_x: c_int = event.x - self.workspace.mouse.x;
        const diff_mag_y: c_int = event.y - self.workspace.mouse.y;

        const new_x: c_int = self.workspace.win_x + diff_mag_x;
        const new_y: c_int = self.workspace.win_y + diff_mag_y;

        const w_x: c_uint = @abs(self.workspace.win_w + (event.x - self.workspace.mouse.x));
        const w_y: c_uint = @abs(self.workspace.win_h + (event.y - self.workspace.mouse.y));

        const button: c_uint = self.workspace.mouse.button;

        const window = self.windowToNode(event.window);
        if (window) |w| {
            w.data.modified = true;
        }

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
        } else {}
    }

    // TODO: on hover, raise window
    pub fn handleEnterNotify(self: *Layout, event: *const c.XCrossingEvent) !void {
        // TODO: set border width and colour in a config
        _ = c.XSetInputFocus(@constCast(self.x_display), event.window, c.RevertToParent, c.CurrentTime);
        _ = c.XSetWindowBorder(@constCast(self.x_display), event.window, 0xFFFFFF);

        // Traverse the window list and make the node with the data equal to the event.window the current focused
        const window = self.windowToNode(event.window);

        self.workspace.current_focused_window = @ptrCast(window);
    }

    pub fn handleLeaveNotify(self: *Layout, event: *const c.XCrossingEvent) !void {
        // TODO: set border width and colour in a config
        _ = c.XSetWindowBorder(@constCast(self.x_display), event.window, 0x333333);

        // unfocus window
        _ = c.XSetInputFocus(@constCast(self.x_display), c.DefaultRootWindow(@constCast(self.x_display)), c.RevertToParent, c.CurrentTime);
    }
};
