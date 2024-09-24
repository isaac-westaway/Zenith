const std = @import("std");

const Logger = @import("zlog");

// Should fix this up
const x11 = @import("x11.zig");
const c = @import("x11.zig").c;

const Window = @import("Window.zig").Window;
const Workspace = @import("Workspace.zig").Workspace;
const Statusbar = @import("Statusbar.zig").Statusbar;
const Background = @import("Background.zig").Background;

const A = @import("Atoms.zig");
const Atoms = @import("Atoms.zig").Atoms;

const Actions = @import("actions.zig");
const Keys = @import("keys.zig");

const Config = @import("config");

const currently_focused = Config.hard_focused;
const currently_hovered = Config.soft_focused;
const unfocused = Config.unfocused;

// TODO: Adjust resizing for border width

// TODO: investigate the "unable to find window" errors in windowToNode, especially regarding windows and subwindows

// TODO: fix layout fullscreen mod4+f when there are no windows

// Ideas: add the ability to control window x and y position using mod4+Arrow Keys
// Ideas: add the ability to swap to windows (X|Y) -> (Y|X)
// Ideas: add some custom keybind commands such as opening tock and centering it to the screen with a specific width and height
// Ideas: add the ability to create a terminal pad without any particular resizing or modification, just a small scratchpad near the cursor
// -- then you could press mod4+Spsace to tile the workspace
// Also add the ability to hide the cursor
// Iideas: command to hide the border

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

    atoms: Atoms,

    fn windowToNode(self: *const Layout, window: c.Window) ?*std.DoublyLinkedList(Window).Node {
        var ptr: ?*std.DoublyLinkedList(Window).Node = self.workspaces.items[self.current_ws].windows.first;

        while (ptr) |node| : (ptr = node.next) {
            if (node.data.window == window) {
                return node;
            } else continue;
        }

        return null;
    }

    pub fn init(allocator: *std.mem.Allocator, display: *const c.Display, window: c.Window) !Layout {
        var layout: Layout = undefined;

        layout.allocator = allocator;

        layout.x_display = display;
        layout.x_rootwindow = window;

        const screen = c.DefaultScreen(@constCast(layout.x_display));

        layout.workspaces = std.ArrayList(Workspace).init(layout.allocator.*);

        for (0..Config.inital_number_of_workspaces) |index| {
            _ = index;

            const workspace: Workspace = undefined;

            try layout.workspaces.append(workspace);
        }

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

        if (Config.enable_statusbar) {
            layout.statusbar = try Statusbar.init(layout.allocator, layout.x_display, &layout.x_rootwindow, layout.x_screen);
        }

        layout.atoms = try Atoms.init(layout.allocator, layout.x_display, &layout.x_rootwindow);
        layout.atoms.updateNormalHints();

        x11.setWindowPropertyScalar(@constCast(layout.x_display), layout.x_rootwindow, A.net_number_of_desktops, c.XA_CARDINAL, layout.workspaces.items.len);
        x11.setWindowPropertyScalar(@constCast(layout.x_display), layout.x_rootwindow, A.net_current_desktop, c.XA_CARDINAL, layout.current_ws);

        layout.background = try Background.init(allocator, layout.x_display, layout.x_rootwindow, layout.x_screen);

        // Begin picom process, if applicable
        var process = std.process.Child.init(Config.picom_command, allocator.*);

        process.spawn() catch {};

        return layout;
    }

    pub fn resolveKeyInput(self: *Layout, event: *c.XKeyPressedEvent) !void {
        if (event.keycode == 36) {
            Actions.openTerminal(self.allocator);

            return;
        }

        if (event.keycode == 9) {
            try Logger.Log.fatal("ZWM_RUN_KEYPRESSED_RESOLVEKEYINPUT", "Closing Window Manager", .{});
        }

        if (event.keycode == 41) {
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

                    // Border width is zero as it is fullscreen
                    _ = c.XSetWindowBorderWidth(@constCast(self.x_display), win.data.window, 0);

                    _ = c.XRaiseWindow(@constCast(self.x_display), win.data.window);
                    _ = c.XMoveWindow(@constCast(self.x_display), win.data.window, 0, 0);
                    _ = c.XResizeWindow(@constCast(self.x_display), win.data.window, @as(c_uint, @intCast(self.screen_w)), @as(c_uint, @intCast(self.screen_h)));

                    self.workspaces.items[self.current_ws].fs_window = @ptrCast(window);
                }

                self.workspaces.items[self.current_ws].fullscreen = true;

                return;
            }

            if (self.workspaces.items[self.current_ws].fullscreen == true) {
                _ = c.XSetWindowBorderWidth(@constCast(self.x_display), self.workspaces.items[self.current_ws].fs_window.data.window, Config.border_width);

                _ = c.XMoveWindow(@constCast(self.x_display), self.workspaces.items[self.current_ws].fs_window.data.window, self.workspaces.items[self.current_ws].fs_window.data.f_x, self.workspaces.items[self.current_ws].fs_window.data.f_y);
                _ = c.XResizeWindow(@constCast(self.x_display), self.workspaces.items[self.current_ws].fs_window.data.window, @as(c_uint, @intCast(self.workspaces.items[self.current_ws].fs_window.data.f_w)), @as(c_uint, @intCast(self.workspaces.items[self.current_ws].fs_window.data.f_h)));
                self.workspaces.items[self.current_ws].fullscreen = false;

                return;
            }
        }

        if (event.keycode == 23 and self.workspaces.items[self.current_ws].windows.len >= 1 and (event.state & c.Mod4Mask) != 0) {
            const direction: i2 = if ((event.state & c.ShiftMask) != 0) -1 else 1;

            if (direction == 1) {
                if (self.workspaces.items[self.current_ws].windows.last.?.data.window == self.workspaces.items[self.current_ws].current_focused_window.data.window) {
                    self.workspaces.items[self.current_ws].current_focused_window = @ptrCast(self.workspaces.items[self.current_ws].windows.first);
                } else if (self.workspaces.items[self.current_ws].current_focused_window.next == null) {
                    self.workspaces.items[self.current_ws].current_focused_window = @ptrCast(self.workspaces.items[self.current_ws].windows.first);
                } else {
                    self.workspaces.items[self.current_ws].current_focused_window = @ptrCast(self.workspaces.items[self.current_ws].current_focused_window.next);
                }
            }

            if (direction == -1) {
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
            _ = c.XSetWindowBorder(@constCast(self.x_display), self.workspaces.items[self.current_ws].current_focused_window.data.window, currently_focused);

            var ptr: ?*std.DoublyLinkedList(Window).Node = self.workspaces.items[self.current_ws].windows.first;
            while (ptr) |node| : (ptr = node.next) {
                if (node.data.window != self.workspaces.items[self.current_ws].current_focused_window.data.window) {
                    _ = c.XSetWindowBorder(@constCast(self.x_display), node.data.window, unfocused);
                }
            }

            return;
        }

        if (event.keycode == 40) {
            var ptr: ?*std.DoublyLinkedList(Window).Node = self.workspaces.items[self.current_ws].windows.first;

            while (ptr) |node| : (ptr = node.next) {
                _ = c.XUnmapWindow(@constCast(self.x_display), node.data.window);
            }

            if (self.current_ws == self.workspaces.items.len - 1) {
                self.current_ws = 0;

                var windows: ?*std.DoublyLinkedList(Window).Node = self.workspaces.items[self.current_ws].windows.last;

                while (windows) |node| : (windows = node.prev) {
                    _ = c.XMapWindow(@constCast(self.x_display), node.data.window);
                }
            } else {
                self.current_ws += 1;
                if (self.workspaces.items[self.current_ws].windows.len > 0) {
                    var windows: ?*std.DoublyLinkedList(Window).Node = self.workspaces.items[self.current_ws].windows.last;

                    while (windows) |node| : (windows = node.prev) {
                        _ = c.XMapWindow(@constCast(self.x_display), node.data.window);
                    }
                }
            }

            x11.setWindowPropertyScalar(@constCast(self.x_display), self.x_rootwindow, A.net_current_desktop, c.XA_CARDINAL, self.current_ws);
        }

        if (event.keycode == 38) {
            var ptr: ?*std.DoublyLinkedList(Window).Node = self.workspaces.items[self.current_ws].windows.first;

            while (ptr) |node| : (ptr = node.next) {
                _ = c.XUnmapWindow(@constCast(self.x_display), node.data.window);
            }

            if (self.current_ws == 0) {
                self.current_ws = @intCast(self.workspaces.items.len - 1);
            } else {
                self.current_ws -= 1;
            }

            var windows: ?*std.DoublyLinkedList(Window).Node = self.workspaces.items[self.current_ws].windows.last;

            while (windows) |node| : (windows = node.prev) {
                _ = c.XMapWindow(@constCast(self.x_display), node.data.window);
            }

            x11.setWindowPropertyScalar(@constCast(self.x_display), self.x_rootwindow, A.net_current_desktop, c.XA_CARDINAL, self.current_ws);
        }

        if (event.keycode == 24) {
            if (self.workspaces.items[self.current_ws].windows.len == 0) return;

            _ = c.XDestroyWindow(@constCast(self.x_display), self.workspaces.items[self.current_ws].current_focused_window.data.window);
        }

        if (event.keycode == 33) {
            if (self.workspaces.items[self.current_ws].windows.len == 0) return;

            const win = self.windowToNode(self.workspaces.items[self.current_ws].current_focused_window.data.window);

            var ws: u32 = self.current_ws;

            if (ws == self.workspaces.items.len - 1) {
                ws = 0;
            } else {
                ws += 1;
            }

            if (win) |w| {
                self.workspaces.items[self.current_ws].windows.remove(w);
                _ = c.XUnmapWindow(@constCast(self.x_display), w.data.window);
                self.workspaces.items[ws].windows.prepend(w);

                self.workspaces.items[ws].current_focused_window = w;

                var window = self.workspaces.items[ws].windows.first;

                // Should come up with a better name
                while (window) |_window| : (window = _window.next) {
                    if (_window.data.window != self.workspaces.items[ws].current_focused_window.data.window) {
                        _ = c.XSetWindowBorder(@constCast(self.x_display), _window.data.window, unfocused);
                    }
                }
            }
        }

        if (event.keycode == 32) {
            if (self.workspaces.items[self.current_ws].windows.len == 0) return;

            const win = self.windowToNode(self.workspaces.items[self.current_ws].current_focused_window.data.window);

            var ws: u32 = self.current_ws;

            if (ws == 0) {
                ws = @intCast(self.workspaces.items.len - 1);
            } else {
                ws -= 1;
            }

            if (win) |w| {
                self.workspaces.items[self.current_ws].windows.remove(w);

                _ = c.XUnmapWindow(@constCast(self.x_display), w.data.window);
                self.workspaces.items[ws].windows.prepend(w);

                self.workspaces.items[ws].current_focused_window = w;

                var window = self.workspaces.items[ws].windows.first;

                while (window) |_window| : (window = _window.next) {
                    if (_window.data.window != self.workspaces.items[ws].current_focused_window.data.window) {
                        _ = c.XSetWindowBorder(@constCast(self.x_display), _window.data.window, unfocused);
                    }
                }
            }
        }
    }

    pub fn handleCreateNotify(self: *const Layout, event: *const c.XCreateWindowEvent) !void {
        _ = self;

        try Logger.Log.info("ZWM_RUN_CREATENOTIFY_HANDLECREATENOTIFY", "Handling Create Notification: {d}", .{event.window});
    }

    // TODO: Fix the mapping logic, kind of flawed and unmaintainable and gross
    pub fn handleMapRequest(self: *Layout, event: *const c.XMapRequestEvent) !void {
        _ = c.XSelectInput(@constCast(self.x_display), event.window, c.StructureNotifyMask | c.EnterWindowMask | c.LeaveWindowMask);

        const window: Window = Window{ .window = event.window, .modified = false, .fullscreen = false, .w_x = 0, .w_y = 0, .w_w = 0, .w_h = 0, .f_x = 0, .f_y = 0, .f_w = 0, .f_h = 0 };

        var node: *std.DoublyLinkedList(Window).Node = try self.allocator.*.create(std.DoublyLinkedList(Window).Node);
        node.data = window;
        self.workspaces.items[self.current_ws].windows.prepend(node);

        // TODO: Fix this atom param
        // _ = c.XChangeProperty(
        //     @constCast(self.x_display),
        //     @constCast(self.x_rootwindow).*,
        //     A.net_client_list,
        //     c.XA_WINDOW,
        //     32,
        //     c.PropModeAppend,
        //     @ptrCast(&node.data.window),
        //     1,
        // );

        // TODO: rework the mapping logic
        // if the window has been modified, in the boolean state, then do not automatically tile when a new window is mapped
        // fix some small details in the width and height
        // add mod4 + spacebar to auto till again
        // Auto tile just makes the currently focused window take up the entire sceren without fullscreenin

        if (self.workspaces.items[self.current_ws].windows.len >= 2) {
            _ = c.XMapWindow(@constCast(self.x_display), event.window);
            _ = c.XSetWindowBorderWidth(@constCast(self.x_display), event.window, Config.border_width);

            _ = c.XResizeWindow(@constCast(self.x_display), self.workspaces.items[self.current_ws].windows.first.?.data.window, @divFloor(@abs(self.screen_w - 10), 2), @abs(self.screen_h - 10));
            _ = c.XMoveWindow(@constCast(self.x_display), self.workspaces.items[self.current_ws].windows.first.?.data.window, 0, 0);

            var start: ?*std.DoublyLinkedList(Window).Node = self.workspaces.items[self.current_ws].windows.first.?.next.?;

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
        } else {
            _ = c.XResizeWindow(@constCast(self.x_display), event.window, @abs(self.screen_w - 10), @abs(self.screen_h - 10));

            _ = c.XMapWindow(@constCast(self.x_display), event.window);
            _ = c.XSetWindowBorderWidth(@constCast(self.x_display), event.window, Config.border_width);
        }

        var attributes: c.XWindowAttributes = undefined;
        _ = c.XGetWindowAttributes(@constCast(self.x_display), event.window, &attributes);

        self.workspaces.items[self.current_ws].windows.last.?.data.w_x = attributes.x;
        self.workspaces.items[self.current_ws].windows.last.?.data.w_y = attributes.y;

        // Again, why can the width and height of the window be negative?
        self.workspaces.items[self.current_ws].windows.last.?.data.w_w = @abs(attributes.width);
        self.workspaces.items[self.current_ws].windows.last.?.data.w_h = @abs(attributes.height);

        self.workspaces.items[self.current_ws].current_focused_window = @ptrCast(self.workspaces.items[self.current_ws].windows.first);

        var s: ?*std.DoublyLinkedList(Window).Node = self.workspaces.items[self.current_ws].windows.first;
        while (s) |win| : (s = win.next) {
            if (win.data.window == self.workspaces.items[self.current_ws].current_focused_window.data.window) {
                _ = c.XSetWindowBorder(@constCast(self.x_display), event.window, currently_focused);
            } else {
                _ = c.XSetWindowBorder(@constCast(self.x_display), win.data.window, unfocused);
            }
        }

        _ = c.XRaiseWindow(@constCast(self.x_display), self.statusbar.x_drawable);
    }

    // TODO: retile unmodified windows here too
    pub fn handleDestroyNotify(self: *Layout, event: *const c.XDestroyWindowEvent) !void {
        if (event.window == self.background.background) return;

        if (self.workspaces.items[self.current_ws].windows.len == 0) return;
        try Logger.Log.info("ZWM_RUN_DESTROY", "Recieved destruction event", .{});
        const window: ?*std.DoublyLinkedList(Window).Node = self.windowToNode(event.window);

        if (window) |w| {
            self.workspaces.items[self.current_ws].windows.remove(w);
            self.allocator.destroy(w);

            if (self.workspaces.items[self.current_ws].windows.len >= 1) {
                self.workspaces.items[self.current_ws].current_focused_window = @ptrCast(self.workspaces.items[self.current_ws].windows.last);
                _ = c.XSetWindowBorder(@constCast(self.x_display), self.workspaces.items[self.current_ws].current_focused_window.data.window, currently_focused);
                _ = c.XSetInputFocus(@constCast(self.x_display), self.workspaces.items[self.current_ws].current_focused_window.data.window, c.RevertToParent, c.CurrentTime);
            } else {
                _ = c.XSetInputFocus(@constCast(self.x_display), c.DefaultRootWindow(@constCast(self.x_display)), c.RevertToParent, c.CurrentTime);
            }
        }
    }

    pub fn handleButtonPress(self: *Layout, event: *const c.XButtonPressedEvent) !void {
        if (event.window == self.statusbar.x_drawable or event.subwindow == self.statusbar.x_drawable) return;
        if (event.subwindow == self.background.background) return;

        if (event.subwindow == 0) return;
        var attributes: c.XWindowAttributes = undefined;
        _ = c.XGetWindowAttributes(@constCast(self.x_display), event.subwindow, &attributes);

        self.workspaces.items[self.current_ws].win_w = attributes.width;
        self.workspaces.items[self.current_ws].win_h = attributes.height;
        self.workspaces.items[self.current_ws].win_x = attributes.x;
        self.workspaces.items[self.current_ws].win_y = attributes.y;

        self.workspaces.items[self.current_ws].mouse = @constCast(event).*;

        _ = c.XRaiseWindow(@constCast(self.x_display), event.subwindow);
        _ = c.XSetWindowBorder(@constCast(self.x_display), event.subwindow, currently_focused);

        const window = self.windowToNode(event.subwindow);

        if (window) |w| {
            self.workspaces.items[self.current_ws].windows.remove(w);
            self.workspaces.items[self.current_ws].windows.prepend(w);

            self.workspaces.items[self.current_ws].current_focused_window = @ptrCast(w);
        }

        var start: ?*std.DoublyLinkedList(Window).Node = self.workspaces.items[self.current_ws].windows.first;

        while (start) |win| : (start = win.next) {
            if (win.data.window != self.workspaces.items[self.current_ws].current_focused_window.data.window) {
                _ = c.XSetWindowBorder(@constCast(self.x_display), win.data.window, unfocused);
            }
        }
    }

    pub fn handleMotionNotify(self: *Layout, event: *const c.XMotionEvent) !void {
        if (event.subwindow == self.statusbar.x_drawable) return;
        if (event.subwindow == self.background.background) return;

        const diff_mag_x: c_int = event.x - self.workspaces.items[self.current_ws].mouse.x;
        const diff_mag_y: c_int = event.y - self.workspaces.items[self.current_ws].mouse.y;

        const new_x: c_int = self.workspaces.items[self.current_ws].win_x + diff_mag_x;
        const new_y: c_int = self.workspaces.items[self.current_ws].win_y + diff_mag_y;

        const w_x: c_uint = @abs(self.workspaces.items[self.current_ws].win_w + (event.x - self.workspaces.items[self.current_ws].mouse.x));
        const w_y: c_uint = @abs(self.workspaces.items[self.current_ws].win_h + (event.y - self.workspaces.items[self.current_ws].mouse.y));

        _ = c.XSetWindowBorder(@constCast(self.x_display), event.subwindow, currently_focused);

        const button: c_uint = self.workspaces.items[self.current_ws].mouse.button;

        const window = self.windowToNode(event.window);
        if (window) |w| {
            w.data.modified = true;
            self.workspaces.items[self.current_ws].windows.remove(w);
            self.workspaces.items[self.current_ws].windows.prepend(w);

            self.workspaces.items[self.current_ws].current_focused_window = @ptrCast(w);
        }

        var start: ?*std.DoublyLinkedList(Window).Node = self.workspaces.items[self.current_ws].windows.first;

        while (start) |win| : (start = win.next) {
            if (win.data.window == self.workspaces.items[self.current_ws].current_focused_window.data.window) {
                continue;
            } else if (win.data.window != event.window) {
                _ = c.XSetWindowBorder(@constCast(self.x_display), win.data.window, unfocused);
            }
        }

        _ = c.XRaiseWindow(@constCast(self.x_display), event.window);

        if (button == 1 and self.workspaces.items[self.current_ws].fullscreen == false) {
            _ = c.XMoveWindow(@constCast(self.x_display), event.subwindow, new_x, new_y);
        }

        if (button == 3 and self.workspaces.items[self.current_ws].fullscreen == false) {
            self.workspaces.items[self.current_ws].fullscreen = false;

            _ = c.XResizeWindow(@constCast(self.x_display), event.subwindow, w_x, w_y);
        }
    }

    // TODO: all add clicking into the window sets the input focus
    pub fn handleEnterNotify(self: *Layout, event: *const c.XCrossingEvent) !void {
        if (event.window == self.statusbar.x_drawable) return;

        _ = c.XSetInputFocus(@constCast(self.x_display), event.window, c.RevertToParent, c.CurrentTime);

        const win = self.windowToNode(event.window);

        if (self.workspaces.items.len == 1) return;

        var attributes: c.XWindowAttributes = undefined;
        _ = c.XGetWindowAttributes(@constCast(self.x_display), event.window, &attributes);

        self.workspaces.items[self.current_ws].win_x = attributes.x;
        self.workspaces.items[self.current_ws].win_y = attributes.y;
        self.workspaces.items[self.current_ws].win_w = attributes.width;
        self.workspaces.items[self.current_ws].win_h = attributes.height;

        if (win) |w| {
            if (w.data.window != self.workspaces.items[self.current_ws].current_focused_window.data.window) {
                _ = c.XSetWindowBorder(@constCast(self.x_display), event.window, currently_hovered);
            }
        }
    }

    pub fn handleLeaveNotify(self: *Layout, event: *const c.XCrossingEvent) !void {
        const win = self.windowToNode(event.window);

        if (self.workspaces.items[self.current_ws].windows.len == 0) return;

        if (win) |w| {
            _ = c.XSetInputFocus(@constCast(self.x_display), c.DefaultRootWindow(@constCast(self.x_display)), c.RevertToParent, c.CurrentTime);
            if (w.data.window != self.workspaces.items[self.current_ws].current_focused_window.data.window) {
                _ = c.XSetWindowBorder(@constCast(self.x_display), event.window, unfocused);
            }
        }
    }
};
