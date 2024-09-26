const std = @import("std");

const x11 = @import("x11.zig");
const c = @import("x11.zig").c;

const Window = @import("Window.zig").Window;

const Atoms = @import("Atoms.zig");

const Actions = @import("actions.zig");

const Config = @import("config");

// Could probably simplify this file by having two doubly linked lists: one modified and one unmodified

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

    pub fn moveToEnd(self: *Workspace, node: *std.DoublyLinkedList(Window).Node) void {
        self.windows.remove(node);
        self.windows.append(node);
    }

    pub fn numberOfWindowsModified(self: *const Workspace) struct { number: u64, last_unmodified: *std.DoublyLinkedList(Window).Node } {
        var start: ?*std.DoublyLinkedList(Window).Node = self.windows.last;

        var number_of_windows_modified: usize = 0;
        var last_unmodified: *std.DoublyLinkedList(Window).Node = undefined;
        while (start) |win| : (start = win.prev) {
            if (win.data.modified) {
                number_of_windows_modified += 1;
            } else {
                last_unmodified = win;
            }
        }

        return .{
            .number = number_of_windows_modified,
            .last_unmodified = last_unmodified,
        };
    }

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

                _ = c.XSetInputFocus(@constCast(self.x_display), win.data.window, c.RevertToPointerRoot, c.CurrentTime);

                self.fs_window = @ptrCast(window);
            }

            self.fullscreen = true;

            return;
        }

        if (self.fullscreen == true) {
            _ = c.XSetWindowBorderWidth(@constCast(self.x_display), self.fs_window.data.window, Config.border_width);

            _ = c.XMoveWindow(@constCast(self.x_display), self.fs_window.data.window, self.fs_window.data.f_x, self.fs_window.data.f_y);
            _ = c.XResizeWindow(@constCast(self.x_display), self.fs_window.data.window, @as(c_uint, @intCast(self.fs_window.data.f_w)), @as(c_uint, @intCast(self.fs_window.data.f_h)));

            _ = c.XSetInputFocus(@constCast(self.x_display), self.fs_window.data.window, c.RevertToPointerRoot, c.CurrentTime);

            self.fullscreen = false;

            return;
        }
    }

    pub fn focusOneUnfocusAll(self: *Workspace) !void {
        if (self.windows.len > 0) {
            _ = c.XRaiseWindow(@constCast(self.x_display), self.current_focused_window.data.window);
            _ = c.XSetInputFocus(@constCast(self.x_display), self.current_focused_window.data.window, c.RevertToPointerRoot, c.CurrentTime);
            _ = c.XSetWindowBorder(@constCast(self.x_display), self.current_focused_window.data.window, Config.hard_focused);

            _ = c.XSetInputFocus(@constCast(self.x_display), self.current_focused_window.data.window, c.RevertToPointerRoot, c.CurrentTime);

            x11.setWindowPropertyScalar(@constCast(self.x_display), self.x_rootwindow, Atoms.net_active_window, c.XA_WINDOW, self.current_focused_window.data.window);

            var ptr: ?*std.DoublyLinkedList(Window).Node = self.windows.first;
            while (ptr) |node| : (ptr = node.next) {
                if (node.data.window != self.current_focused_window.data.window) {
                    _ = c.XSetWindowBorder(@constCast(self.x_display), node.data.window, Config.unfocused);
                }
            }
        } else return;
    }

    pub fn closeFocusedWindow(self: *Workspace) !void {
        if (self.windows.len == 0) return;

        _ = c.XDestroyWindow(@constCast(self.x_display), self.current_focused_window.data.window);
    }

    // Do NOT raise any windows here
    // The sizing here is mathematically sound, refer to the screenshot in the images
    // It could probably benefit from optically centering
    pub fn retileAllWindows(self: *Workspace) void {
        if (self.windows.len == 1) return;

        const left_width: u32 = @abs(@divFloor(self.screen_w, 2) - (Config.window_gap_width + @divFloor(Config.window_gap_width, 2)));

        if (!self.windows.last.?.data.modified) {
            _ = c.XResizeWindow(@constCast(self.x_display), self.windows.last.?.data.window, left_width, @abs(self.screen_h - (2 * Config.window_gap_width)));
            _ = c.XMoveWindow(@constCast(self.x_display), self.windows.last.?.data.window, Config.window_gap_width, Config.window_gap_width);
        }

        const number_of_windows_modified = self.numberOfWindowsModified();
        const total_windows_to_be_modified = self.windows.len - number_of_windows_modified.number;

        const right_width = left_width;
        const remaining_height: u32 = @abs(self.screen_h - (Config.window_gap_width));

        var right_window_height: u64 = 0;

        if (total_windows_to_be_modified <= 1) {
            right_window_height = @abs(self.screen_h) - (2 * Config.window_gap_width);
        } else {
            right_window_height = @divFloor(remaining_height - (total_windows_to_be_modified - 1) * Config.window_gap_width, (total_windows_to_be_modified - 1));
        }

        const last = self.windows.first;

        if (last) |win| {
            if (total_windows_to_be_modified == 1) {
                // cache the window
                const window = win;
                self.windows.remove(win);

                self.windows.append(window);
            }
        }

        var start: ?*std.DoublyLinkedList(Window).Node = self.windows.last.?.prev.?;
        var index: u64 = 0;
        while (start) |win| : (start = win.prev) {
            if (win.data.modified == false) {
                _ = c.XResizeWindow(@constCast(self.x_display), win.data.window, right_width, @intCast(right_window_height));

                _ = c.XMoveWindow(@constCast(self.x_display), win.data.window, @intCast(left_width + 2 * Config.window_gap_width), @intCast(Config.window_gap_width + (index * (right_window_height + Config.window_gap_width))));
                index += 1;
            }
        }
    }

    pub fn handleWindowMappingTiling(self: *Workspace, window: c.Window) !void {
        const number_of_windows_modified = self.numberOfWindowsModified();
        const total_windows_to_be_modified = self.windows.len - number_of_windows_modified.number;
        if (total_windows_to_be_modified >= 2) {
            self.retileAllWindows();
        } else {
            // THE RIGHT SIDE WIDTH DOES NOT LOOK EQUAL BUT MATHEMATICALLY IT IS!!!
            _ = c.XResizeWindow(@constCast(self.x_display), window, @abs(self.screen_w - (2 * Config.window_gap_width)), @abs(self.screen_h - (2 * Config.window_gap_width)));
            _ = c.XMoveWindow(@constCast(self.x_display), window, Config.window_gap_width, Config.window_gap_width);
        }
    }

    pub fn handleWindowDestroyTiling(self: *Workspace) !void {
        if (self.windows.len == 0) return;

        const window = self.windows.last;
        if (window) |win| {
            if (self.windows.len == 1 and win.data.modified == false) {
                _ = c.XMoveWindow(@constCast(self.x_display), win.data.window, Config.window_gap_width, Config.window_gap_width);
                _ = c.XResizeWindow(@constCast(self.x_display), win.data.window, @intCast(self.screen_w - (2 * Config.window_gap_width)), @abs(self.screen_h - (2 * Config.window_gap_width)));
            }
        }

        if (self.windows.len >= 2) {
            self.retileAllWindows();
        }
    }
};

// TODO: auto tile function using Mod4 + Space, this could work by checking the last window, which should take up the first half of the screen
// If this window has a modified attribute, and is focused, and is the last window, then it should be moved to the 0,0 width half and height full
