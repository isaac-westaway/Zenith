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

const currently_focused = Config.hard_focused;
const currently_hovered = Config.soft_focused;
const unfocused = Config.unfocused;

// TODO: add master window (large left) cycling

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
    } // windowToNode

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

        layout.screen_w = @intCast(c.XDisplayWidth(@constCast(display), screen));
        layout.screen_h = @intCast(c.XDisplayHeight(@constCast(display), screen));

        layout.current_ws = 0;
        for (layout.workspaces.items) |*workspace| {
            // Why is the auto formatter like this :(
            workspace.* = Workspace{ .x_display = layout.x_display, .x_rootwindow = layout.x_rootwindow, .windows = std.DoublyLinkedList(Window){}, .fullscreen = false, .fs_window = undefined, .current_focused_window = undefined, .mouse = undefined, .win_x = 0, .win_y = 0, .win_w = 0, .win_h = 0, .screen_w = layout.screen_w, .screen_h = layout.screen_h };
        }

        if (Config.enable_statusbar) {
            layout.statusbar = try Statusbar.init(layout.allocator, layout.x_display, &layout.x_rootwindow, layout.x_screen);
        }

        layout.atoms = try Atoms.init(layout.allocator, layout.x_display, &layout.x_rootwindow);
        layout.atoms.updateNormalHints();

        _ = c.XDeleteProperty(@constCast(layout.x_display), layout.x_rootwindow, A.net_client_list);

        x11.setWindowPropertyScalar(@constCast(layout.x_display), layout.x_rootwindow, A.net_number_of_desktops, c.XA_CARDINAL, layout.workspaces.items.len);
        x11.setWindowPropertyScalar(@constCast(layout.x_display), layout.x_rootwindow, A.net_current_desktop, c.XA_CARDINAL, layout.current_ws);
        x11.setWindowPropertyScalar(@constCast(layout.x_display), layout.x_rootwindow, A.net_active_window, c.XA_WINDOW, layout.x_rootwindow);

        if (Config.animated_background == false) {
            layout.background = try Background.init(allocator, layout.x_display, layout.x_rootwindow, layout.x_screen);
        } else {
            layout.background = try Background.animateWindow(allocator, layout.x_display, layout.x_rootwindow, layout.x_screen);

            const thread = try std.Thread.spawn(.{ .allocator = allocator.* }, Background.animateBackground, .{ allocator, layout.x_display, layout.background.background, layout.x_rootwindow });

            thread.detach();
        }

        // Begin picom process, if applicable
        var process = std.process.Child.init(Config.picom_command, allocator.*);

        process.spawn() catch {};

        return layout;
    } // init

    pub fn resolveKeyInput(self: *Layout, event: *c.XKeyPressedEvent) !void {

        // Open the Kitty (or what is defined in config.zig) terminal
        if (c.XkbKeycodeToKeysym(@constCast(self.x_display), @intCast(event.keycode), 0, 0) == Config.terminal_key) {
            Actions.openTerminal(self.allocator);

            return;
        }

        // Mod4 + lowercase(l)
        // Scrot is a package to take screenshots
        if (c.XkbKeycodeToKeysym(@constCast(self.x_display), @intCast(event.keycode), 0, 0) == Config.scrot_key) {
            Actions.scrot(self.allocator);
        }

        // Tilde, Grave, Backtick
        // Unfocus window, if you want to have a window open but stare at the wallpaper with a blank expression on your face
        if (c.XkbKeycodeToKeysym(@constCast(self.x_display), @intCast(event.keycode), 0, 0) == Config.unfocus_key) {
            x11.setWindowPropertyScalar(
                @constCast(self.x_display),
                self.x_rootwindow,
                A.net_active_window,
                c.XA_WINDOW,
                @abs(c.None),
            );
        }

        // Kill the Window Manager
        if (c.XkbKeycodeToKeysym(@constCast(self.x_display), @intCast(event.keycode), 0, 0) == Config.close_key) {
            std.posix.exit(1);
        }

        // Handle the fullscreening
        // TODO: EWMH _NET_WM_FULLSCREEN atom
        // TODO: this needs some small fixes, especially when a user opens another window (ctrl+enter to open a terminal) whilst in the fullscreen state
        if (c.XkbKeycodeToKeysym(@constCast(self.x_display), @intCast(event.keycode), 0, 0) == Config.fullscreen_key) {
            if (self.workspaces.items[self.current_ws].windows.len == 0) return;
            try self.workspaces.items[self.current_ws].handleFullscreen();
        }

        // Tab list focusing
        const cycle_keysym = c.XkbKeycodeToKeysym(@constCast(self.x_display), @intCast(event.keycode), 0, 0);

        // Check if the keycode matches the cycle keysym key and other conditions are met
        if (cycle_keysym == Config.cycle_forward_key and self.workspaces.items[self.current_ws].windows.len >= 1 and (event.state & Config.cycle_forward_super) != 0) {
            const direction: i2 = if ((event.state & Config.cycle_backward_super_second) != 0) 1 else -1;

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

            try self.workspaces.items[self.current_ws].focusOneUnfocusAll();

            x11.setWindowPropertyScalar(
                @constCast(self.x_display),
                self.x_rootwindow,
                A.net_active_window,
                c.XA_WINDOW,
                self.workspaces.items[self.current_ws].current_focused_window.data.window,
            );

            return;
        }

        // Move right a workspace
        if (c.XkbKeycodeToKeysym(@constCast(self.x_display), @intCast(event.keycode), 0, 0) == Config.workspace_cycle_forward_key) {
            if (self.workspaces.items.len == 1) return;

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

            try self.workspaces.items[self.current_ws].focusOneUnfocusAll();

            x11.setWindowPropertyScalar(@constCast(self.x_display), self.x_rootwindow, A.net_current_desktop, c.XA_CARDINAL, self.current_ws);
        }

        // Move left a workspace
        if (c.XkbKeycodeToKeysym(@constCast(self.x_display), @intCast(event.keycode), 0, 0) == Config.workspace_cycle_backward_key) {
            if (self.workspaces.items.len == 1) return;

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

            try self.workspaces.items[self.current_ws].focusOneUnfocusAll();

            x11.setWindowPropertyScalar(@constCast(self.x_display), self.x_rootwindow, A.net_current_desktop, c.XA_CARDINAL, self.current_ws);
        }

        // Close the currently focused window
        if (c.XkbKeycodeToKeysym(@constCast(self.x_display), @intCast(event.keycode), 0, 0) == Config.close_window_key) {
            try self.workspaces.items[self.current_ws].closeFocusedWindow();
        }

        // Push a window right in a workspace
        if (c.XkbKeycodeToKeysym(@constCast(self.x_display), @intCast(event.keycode), 0, 0) == Config.push_forward_key) {
            if (self.workspaces.items[self.current_ws].windows.len == 0) return;
            if (self.workspaces.items.len == 1) return;

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

                if (w.data.modified == false) {
                    if (self.workspaces.items[ws].windows.len - self.workspaces.items[ws].numberOfWindowsModified().number > 1) {
                        self.workspaces.items[ws].retileAllWindows();
                    } else if (self.workspaces.items[ws].windows.len - self.workspaces.items[ws].numberOfWindowsModified().number == 1) {
                        const unmodified_window = self.workspaces.items[ws].numberOfWindowsModified().last_unmodified;

                        _ = c.XResizeWindow(@constCast(self.x_display), unmodified_window.data.window, @abs(self.screen_w) - (2 * Config.window_gap_width), @abs(self.screen_h) - (2 * Config.window_gap_width));

                        _ = c.XMoveWindow(@constCast(self.x_display), unmodified_window.data.window, Config.window_gap_width, Config.window_gap_width);
                    } else {}
                }
            }

            if (self.workspaces.items[self.current_ws].windows.len - self.workspaces.items[self.current_ws].numberOfWindowsModified().number > 1) {
                self.workspaces.items[self.current_ws].retileAllWindows();
            } else if (self.workspaces.items[self.current_ws].windows.len - self.workspaces.items[self.current_ws].numberOfWindowsModified().number == 1) {
                const unmodified_window = self.workspaces.items[self.current_ws].numberOfWindowsModified().last_unmodified;

                _ = c.XResizeWindow(@constCast(self.x_display), unmodified_window.data.window, @abs(self.screen_w) - (2 * Config.window_gap_width), @abs(self.screen_h) - (2 * Config.window_gap_width));

                _ = c.XMoveWindow(@constCast(self.x_display), unmodified_window.data.window, Config.window_gap_width, Config.window_gap_width);
            } else {}
        }

        // Push a window left in a workspace
        if (c.XkbKeycodeToKeysym(@constCast(self.x_display), @intCast(event.keycode), 0, 0) == Config.push_backward_key) {
            if (self.workspaces.items[self.current_ws].windows.len == 0) return;
            if (self.workspaces.items.len == 1) return;

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

                if (w.data.modified == false) {
                    if (self.workspaces.items[ws].windows.len - self.workspaces.items[ws].numberOfWindowsModified().number > 1) {
                        self.workspaces.items[ws].retileAllWindows();
                    } else if (self.workspaces.items[ws].windows.len - self.workspaces.items[ws].numberOfWindowsModified().number == 1) {
                        const unmodified_window = self.workspaces.items[ws].numberOfWindowsModified().last_unmodified;

                        _ = c.XResizeWindow(@constCast(self.x_display), unmodified_window.data.window, @abs(self.screen_w) - (2 * Config.window_gap_width), @abs(self.screen_h) - (2 * Config.window_gap_width));

                        _ = c.XMoveWindow(@constCast(self.x_display), unmodified_window.data.window, Config.window_gap_width, Config.window_gap_width);
                    } else {}
                }
            }

            if (self.workspaces.items[self.current_ws].windows.len - self.workspaces.items[self.current_ws].numberOfWindowsModified().number > 1) {
                self.workspaces.items[self.current_ws].retileAllWindows();
            } else if (self.workspaces.items[self.current_ws].windows.len - self.workspaces.items[self.current_ws].numberOfWindowsModified().number == 1) {
                const unmodified_window = self.workspaces.items[self.current_ws].numberOfWindowsModified().last_unmodified;

                _ = c.XResizeWindow(@constCast(self.x_display), unmodified_window.data.window, @abs(self.screen_w) - (2 * Config.window_gap_width), @abs(self.screen_h) - (2 * Config.window_gap_width));

                _ = c.XMoveWindow(@constCast(self.x_display), unmodified_window.data.window, Config.window_gap_width, Config.window_gap_width);
            } else {}
        }

        // Dynamically append another workspace to the list of workspaces
        if (c.XkbKeycodeToKeysym(@constCast(self.x_display), @intCast(event.keycode), 0, 0) == Config.workspace_append_key) {
            const workspace: Workspace = Workspace{ .x_display = self.x_display, .x_rootwindow = self.x_rootwindow, .windows = std.DoublyLinkedList(Window){}, .fullscreen = false, .fs_window = undefined, .current_focused_window = undefined, .mouse = undefined, .win_x = 0, .win_y = 0, .win_w = 0, .win_h = 0, .screen_w = self.screen_w, .screen_h = self.screen_h };

            try self.workspaces.append(workspace);

            _ = c.XDeleteProperty(@constCast(self.x_display), self.x_rootwindow, A.net_number_of_desktops);

            x11.setWindowPropertyScalar(@constCast(self.x_display), self.x_rootwindow, A.net_number_of_desktops, c.XA_CARDINAL, self.workspaces.items.len);

            x11.setWindowPropertyScalar(@constCast(self.x_display), self.x_rootwindow, A.net_current_desktop, c.XA_CARDINAL, self.current_ws);
        }

        // Dynamically pop all workspaces down to 1, if there is only one, do nothing. Why would you want zero workspaces?
        if (c.XkbKeycodeToKeysym(@constCast(self.x_display), @intCast(event.keycode), 0, 0) == Config.workspace_pop_key) {
            // If popping the last workspace, whilst inside the last workspace
            // Move left a workspace
            if (self.workspaces.items.len == 1) return;

            if (self.current_ws == self.workspaces.items.len - 1) {
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

                try self.workspaces.items[self.current_ws].focusOneUnfocusAll();

                x11.setWindowPropertyScalar(@constCast(self.x_display), self.x_rootwindow, A.net_current_desktop, c.XA_CARDINAL, self.current_ws);
            }
            _ = self.workspaces.pop();

            _ = c.XDeleteProperty(@constCast(self.x_display), self.x_rootwindow, A.net_number_of_desktops);

            x11.setWindowPropertyScalar(@constCast(self.x_display), self.x_rootwindow, A.net_number_of_desktops, c.XA_CARDINAL, self.workspaces.items.len);

            x11.setWindowPropertyScalar(@constCast(self.x_display), self.x_rootwindow, A.net_current_desktop, c.XA_CARDINAL, self.current_ws);
        }

        // Swap left right master
        if (c.XkbKeycodeToKeysym(@constCast(self.x_display), @intCast(event.keycode), 0, 0) == Config.swap_left_right_mastker_key) {
            try self.workspaces.items[self.current_ws].swapLeftRightMaster();
        }
    } // resolveKeyInput

    pub fn handleCreateNotify(self: *const Layout, event: *const c.XCreateWindowEvent) !void {
        _ = self;
        _ = event;
    } // handleCreateNotify

    pub fn handleMapRequest(self: *Layout, event: *const c.XMapRequestEvent) !void {
        _ = c.XDeleteProperty(@constCast(self.x_display), self.x_rootwindow, A.net_active_window);
        _ = c.XSelectInput(@constCast(self.x_display), event.window, c.StructureNotifyMask | c.EnterWindowMask | c.LeaveWindowMask | c.FocusChangeMask);

        const window: Window = Window{ .window = event.window, .modified = false, .fullscreen = false, .w_x = 0, .w_y = 0, .w_w = 0, .w_h = 0, .f_x = 0, .f_y = 0, .f_w = 0, .f_h = 0 };
        var node: *std.DoublyLinkedList(Window).Node = try self.allocator.*.create(std.DoublyLinkedList(Window).Node);
        node.data = window;
        self.workspaces.items[self.current_ws].windows.prepend(node);

        _ = c.XSetInputFocus(@constCast(self.x_display), event.window, c.RevertToParent, c.CurrentTime);
        _ = c.XSetWindowBorderWidth(@constCast(self.x_display), event.window, Config.border_width);
        _ = c.XMapWindow(@constCast(self.x_display), event.window);

        try self.workspaces.items[self.current_ws].handleWindowMappingTiling(event.window);

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

        // _ = c.XRaiseWindow(@constCast(self.x_display), self.statusbar.x_drawable);
        _ = c.XChangeProperty(
            @constCast(self.x_display),
            self.x_rootwindow,
            A.net_client_list,
            c.XA_WINDOW,
            32,
            c.PropModeAppend,
            @ptrCast(&self.workspaces.items[self.current_ws].current_focused_window.data.window),
            1,
        );
        _ = c.XChangeProperty(@constCast(self.x_display), self.x_rootwindow, A.net_active_window, c.XA_WINDOW, 32, c.PropModeReplace, @ptrCast(&self.workspaces.items[self.current_ws].current_focused_window.data.window), 1);
    } // handleMapNotify

    // TODO: retile unmodified windows here too
    pub fn handleDestroyNotify(self: *Layout, event: *const c.XDestroyWindowEvent) !void {
        _ = c.XDeleteProperty(@constCast(self.x_display), self.x_rootwindow, A.net_active_window);

        if (event.window == self.background.background) return;

        if (self.workspaces.items[self.current_ws].windows.len == 0) return;
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

        // This is a specific order

        _ = c.XDeleteProperty(@constCast(self.x_display), self.x_rootwindow, A.net_client_list);

        if (self.workspaces.items[self.current_ws].windows.len == 0) return;

        _ = c.XChangeProperty(@constCast(self.x_display), self.x_rootwindow, A.net_active_window, c.XA_WINDOW, 32, c.PropModeReplace, @ptrCast(&self.workspaces.items[self.current_ws].current_focused_window.data.window), 1);

        var it = self.workspaces.items[self.current_ws].windows.first;
        while (it) |n| : (it = n.next) {
            _ = c.XChangeProperty(
                @constCast(self.x_display),
                self.x_rootwindow,
                A.net_client_list,
                c.XA_WINDOW,
                32,
                c.PropModeAppend,
                @ptrCast(&n.data.window),
                1,
            );
        }

        try self.workspaces.items[self.current_ws].handleWindowDestroyTiling();
    } // handleDestroyNotify

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

        _ = c.XRaiseWindow(@constCast(self.x_display), event.window);
        _ = c.XSetWindowBorder(@constCast(self.x_display), event.subwindow, currently_focused);
        _ = c.XSetInputFocus(@constCast(self.x_display), event.subwindow, c.RevertToParent, c.CurrentTime);

        const window = self.windowToNode(event.subwindow);

        if (window) |w| {
            w.data.modified = true;
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

        x11.setWindowPropertyScalar(@constCast(self.x_display), self.x_rootwindow, A.net_active_window, c.XA_WINDOW, event.subwindow);
    } // handleButtonPress

    pub fn handleMotionNotify(self: *Layout, event: *const c.XMotionEvent) !void {
        if (event.subwindow == self.statusbar.x_drawable) return;
        if (event.subwindow == self.background.background) return;

        const diff_mag_x: c_int = event.x - self.workspaces.items[self.current_ws].mouse.x;
        const diff_mag_y: c_int = event.y - self.workspaces.items[self.current_ws].mouse.y;

        const new_x: c_int = self.workspaces.items[self.current_ws].win_x + diff_mag_x;
        const new_y: c_int = self.workspaces.items[self.current_ws].win_y + diff_mag_y;

        const w_x: c_uint = @abs(self.workspaces.items[self.current_ws].win_w + (event.x - self.workspaces.items[self.current_ws].mouse.x));
        const w_y: c_uint = @abs(self.workspaces.items[self.current_ws].win_h + (event.y - self.workspaces.items[self.current_ws].mouse.y));

        // TODO: set minimum window size

        _ = c.XSetWindowBorder(@constCast(self.x_display), event.subwindow, currently_focused);

        const button: c_uint = self.workspaces.items[self.current_ws].mouse.button;

        const window = self.windowToNode(event.subwindow);
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

        if (event.window != self.workspaces.items[self.current_ws].current_focused_window.data.window) {
            if (button == 1 and self.workspaces.items[self.current_ws].fullscreen == false) {
                _ = c.XMoveWindow(@constCast(self.x_display), event.subwindow, new_x, new_y);
            }

            if (button == 3 and self.workspaces.items[self.current_ws].fullscreen == false) {
                self.workspaces.items[self.current_ws].fullscreen = false;

                _ = c.XResizeWindow(@constCast(self.x_display), event.subwindow, w_x, w_y);
            }
        }

        if (self.workspaces.items[self.current_ws].windows.len - self.workspaces.items[self.current_ws].numberOfWindowsModified().number > 1) {
            self.workspaces.items[self.current_ws].retileAllWindows();
        } else if (self.workspaces.items[self.current_ws].windows.len - self.workspaces.items[self.current_ws].numberOfWindowsModified().number == 1) {
            const unmodified_window = self.workspaces.items[self.current_ws].numberOfWindowsModified().last_unmodified;

            _ = c.XResizeWindow(@constCast(self.x_display), unmodified_window.data.window, @abs(self.screen_w) - (2 * Config.window_gap_width), @abs(self.screen_h) - (2 * Config.window_gap_width));

            _ = c.XMoveWindow(@constCast(self.x_display), unmodified_window.data.window, Config.window_gap_width, Config.window_gap_width);
        } else {}
        x11.setWindowPropertyScalar(@constCast(self.x_display), self.x_rootwindow, A.net_active_window, c.XA_WINDOW, event.subwindow);
        _ = c.XRaiseWindow(@constCast(self.x_display), event.subwindow);
    } // handleMotionNotify

    pub fn handleEnterNotify(self: *Layout, event: *const c.XCrossingEvent) !void {
        if (event.window == self.statusbar.x_drawable) return;

        // Do NOT make it the focused window
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
    } // handleEnterNotify

    pub fn handleLeaveNotify(self: *Layout, event: *const c.XCrossingEvent) !void {
        const win = self.windowToNode(event.window);

        if (self.workspaces.items[self.current_ws].windows.len == 0) return;

        if (win) |w| {
            _ = c.XSetInputFocus(@constCast(self.x_display), c.DefaultRootWindow(@constCast(self.x_display)), c.RevertToParent, c.CurrentTime);
            if (w.data.window != self.workspaces.items[self.current_ws].current_focused_window.data.window) {
                _ = c.XSetWindowBorder(@constCast(self.x_display), event.window, unfocused);
            }
        }
    } // handleLeaveNotify
};
