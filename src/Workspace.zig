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

    pub fn moveToStart(self: *Workspace, node: *std.DoublyLinkedList(Window).Node) void {
        self.windows.remove(node);
        self.windows.prepend(node);
    } // moveToStart

    pub fn moveToEnd(self: *Workspace, node: *std.DoublyLinkedList(Window).Node) void {
        self.windows.remove(node);
        self.windows.append(node);
    } // moveToEnd

    pub fn numberOfWindowsModified(self: *const Workspace) struct { number: u64, last_unmodified: *std.DoublyLinkedList(Window).Node } {
        if (self.windows.len == 0) return .{
            .number = 0,
            .last_unmodified = undefined,
        };

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
    } // numberOfWindowsModified

    fn windowToNode(self: *const Workspace, window: c.Window) ?*std.DoublyLinkedList(Window).Node {
        var ptr: ?*std.DoublyLinkedList(Window).Node = self.windows.first;

        while (ptr) |node| : (ptr = node.next) {
            if (node.data.window == window) {
                return node;
            } else continue;
        }

        return null;
    } // windowToNode

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
    } // handleFullscreen

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
                } else continue;
            }
        } else return;
    } // focuseOneUnfocusAll

    pub fn closeFocusedWindow(self: *Workspace) !void {
        if (self.windows.len == 0) return;

        _ = c.XDestroyWindow(@constCast(self.x_display), self.current_focused_window.data.window);
    } // closeFocusedWindow

    // Do NOT raise any windows here
    // The sizing here is mathematically sound, refer to the screenshot in the images
    // It could probably benefit from optically centering
    // If you would like to contribute, the general details is the master left window is the last node in the linked list, and the bottom right is the first
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
    } // retileAllWindows

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
    } // handleWindowMapTiling

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
    } // handleWindowDestroyTiling

    pub fn swapLeftRightMaster(self: *Workspace) !void {
        if (self.current_focused_window.data.modified) return;
        if (self.windows.len == 1 or self.windows.len == 0) return;

        const total_to_be_modified = self.windows.len - self.numberOfWindowsModified().number;
        if (total_to_be_modified == 1 or total_to_be_modified == 0) return;

        // TODO: update this so it is no longer the length, but the number of modifiable windows
        if (self.windows.len == 2) {
            if (self.current_focused_window.data.window == self.windows.first.?.data.window) {
                self.moveToEnd(@ptrCast(self.windows.first));

                self.retileAllWindows();

                return;
            } else if (self.current_focused_window.data.window == self.windows.last.?.data.window) {
                self.moveToStart(@ptrCast(self.windows.last));

                self.retileAllWindows();

                return;
            }
        }

        // If the master window, then swap the master with the topright
        // TODO: to update to the first window that is NOT modifiable
        // do it in a function of find first unmodified
        if (self.current_focused_window.data.window == self.windows.last.?.data.window) {
            const top_right_window = self.windows.last.?.prev;

            self.moveToEnd(@ptrCast(top_right_window));

            self.windows.remove(self.current_focused_window);
            self.windows.insertBefore(@ptrCast(self.windows.last), self.current_focused_window);

            self.retileAllWindows();
        } else if (self.current_focused_window.data.window == self.windows.last.?.prev.?.data.window) {
            self.moveToEnd(self.current_focused_window);

            self.retileAllWindows();
        } else {
            const current_focused_window = self.current_focused_window.data.window;

            var previous_window_node: *std.DoublyLinkedList(Window).Node = undefined;
            var start = self.windows.last;
            while (start) |win| : (start = win.prev) {
                if (win.data.window == current_focused_window) break else {
                    previous_window_node = win;
                }
            }

            self.moveToEnd(self.current_focused_window);

            const now_second_last = self.windows.last.?.prev;

            self.windows.remove(@ptrCast(now_second_last));
            self.windows.insertBefore(@constCast(previous_window_node), @ptrCast(now_second_last));

            self.retileAllWindows();
        }

        return;
    } // swapLeftRightMaster

    pub fn addWindowAsMaster(self: *Workspace) !void {
        if (self.windows.len == 0) return;

        if (self.windows.len == 1) {
            _ = c.XMoveWindow(@constCast(self.x_display), self.current_focused_window.data.window, Config.window_gap_width, Config.window_gap_width);
            _ = c.XResizeWindow(@constCast(self.x_display), self.current_focused_window.data.window, @abs(self.screen_w) - 2 * Config.window_gap_width, @abs(self.screen_h) - 2 * Config.window_gap_width);
            return;
        }

        if (self.current_focused_window.data.modified == false) {
            if (self.current_focused_window.data.window != self.windows.last.?.data.window) {
                try self.swapLeftRightMaster();
            } else return; // if the current focused window already is the unmodified master, do nothing
        } else {
            self.moveToEnd(self.current_focused_window);
            self.current_focused_window.data.modified = false;

            self.retileAllWindows();
        }
    } // addWindowAsMaster

    pub fn addWindowAsSlave(self: *Workspace) !void {
        if (self.windows.len == 0) return;

        if (self.windows.len == 1) {
            _ = c.XMoveWindow(@constCast(self.x_display), self.current_focused_window.data.window, Config.window_gap_width, Config.window_gap_width);
            _ = c.XResizeWindow(@constCast(self.x_display), self.current_focused_window.data.window, @abs(self.screen_w) - 2 * Config.window_gap_width, @abs(self.screen_h) - 2 * Config.window_gap_width);
            return;
        }
        if (self.current_focused_window.data.modified == false) {
            if (self.current_focused_window.data.window == self.windows.last.?.data.window) {
                try self.swapLeftRightMaster();
            } else return; // it is already a "slave" window
        } else {
            self.moveToEnd(self.current_focused_window);
            self.moveToEnd(@ptrCast(self.windows.last.?.prev));
            self.current_focused_window.data.modified = false;

            self.retileAllWindows();
        }
    } // addWindowAsSlave
};
