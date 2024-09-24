const std = @import("std");

const Logger = @import("zlog");

const x11 = @import("x11.zig");
const c = @import("x11.zig").c;

const Window = @import("Window.zig").Window;

const Atoms = @import("Atoms.zig");

const Actions = @import("actions.zig");
const Keys = @import("keys.zig");

const Config = @import("config");

pub const Workspace = struct {
    x_display: *const c.Display,
    x_rootwindow: c.Window,

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

    screen_w: i32,
    screen_h: i32,

    fn windowToNode(self: *const Workspace, window: c.Window) ?*std.DoublyLinkedList(Window).Node {
        var ptr: ?*std.DoublyLinkedList(Window).Node = self.windows.first;

        while (ptr) |node| : (ptr = node.next) {
            if (node.data.window == window) {
                return node;
            } else continue;
        }

        return null;
    }

    pub fn handleFullscreen(self: *Workspace) !void {
        if (self.fullscreen == false) {
            var attributes: c.XWindowAttributes = undefined;

            _ = c.XGetWindowAttributes(@constCast(self.x_display), self.current_focused_window.data.window, &attributes);

            const window = self.windowToNode(self.current_focused_window.data.window);

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

                self.fs_window = @ptrCast(window);
            }

            self.fullscreen = true;

            return;
        }

        if (self.fullscreen == true) {
            _ = c.XSetWindowBorderWidth(@constCast(self.x_display), self.fs_window.data.window, Config.border_width);

            _ = c.XMoveWindow(@constCast(self.x_display), self.fs_window.data.window, self.fs_window.data.f_x, self.fs_window.data.f_y);
            _ = c.XResizeWindow(@constCast(self.x_display), self.fs_window.data.window, @as(c_uint, @intCast(self.fs_window.data.f_w)), @as(c_uint, @intCast(self.fs_window.data.f_h)));
            self.fullscreen = false;

            return;
        }
    }

    pub fn focusOneUnfocusAll(self: *Workspace) !void {
        _ = c.XRaiseWindow(@constCast(self.x_display), self.current_focused_window.data.window);
        _ = c.XSetInputFocus(@constCast(self.x_display), self.current_focused_window.data.window, c.RevertToParent, c.CurrentTime);
        _ = c.XSetWindowBorder(@constCast(self.x_display), self.current_focused_window.data.window, Config.hard_focused);

        _ = c.XSetInputFocus(@constCast(self.x_display), self.current_focused_window.data.window, c.RevertToNone, c.CurrentTime);

        x11.setWindowPropertyScalar(@constCast(self.x_display), self.x_rootwindow, Atoms.net_active_window, c.XA_WINDOW, self.current_focused_window.data.window);

        var ptr: ?*std.DoublyLinkedList(Window).Node = self.windows.first;
        while (ptr) |node| : (ptr = node.next) {
            if (node.data.window != self.current_focused_window.data.window) {
                _ = c.XSetWindowBorder(@constCast(self.x_display), node.data.window, Config.unfocused);
            }
        }
    }

    pub fn closeFocusedWindow(self: *Workspace) !void {
        if (self.windows.len == 0) return;

        _ = c.XDestroyWindow(@constCast(self.x_display), self.current_focused_window.data.window);
    }
};
