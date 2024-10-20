const std = @import("std");
const builtin = @import("builtin");

const c = @import("x11.zig").c;

// the manager struct should be in control of the background and statusbar

const Input = @import("Input.zig");
const Atoms = @import("Atoms.zig");
const Layout = @import("Layout.zig");

pub const ManagerInitErrors = error{ XorgDisplayFail, XCBConnectionFail };

pub const Manager = struct {
    allocator: *const std.mem.Allocator,

    x_display: *c.Display,
    x_rootwindow: c.Window,

    xcb_connection: *c.xcb_connection_t,
    xcb_ewmh_connection: *c.xcb_ewmh_connection_t,
    xcb_screen: *c.xcb_screen_t,

    /// Initializer method for the entire window manager
    pub fn init(allocator: *const std.mem.Allocator) ManagerInitErrors!Manager {
        var manager: Manager = undefined;

        manager.allocator = allocator;

        {
            manager.x_display = c.XOpenDisplay(null) orelse return ManagerInitErrors.XorgDisplayFail;
            manager.x_rootwindow = c.XRootWindow(manager.x_display, 0);
            manager.xcb_connection = c.XGetXCBConnection(manager.x_display) orelse return ManagerInitErrors.XCBConnectionFail;
        }

        _ = c.XSetErrorHandler(handleError);
        _ = c.XSetEventQueueOwner(manager.x_display, c.XCBOwnsEventQueue);

        {
            // contiguous mode and non contiguous mode
            const screen: c.xcb_screen_iterator_t = c.xcb_setup_roots_iterator(c.xcb_get_setup(manager.xcb_connection));
            manager.xcb_screen = screen.data;
        }

        const event_mask_list = [_]u32{c.XCB_EVENT_MASK_SUBSTRUCTURE_REDIRECT |
            c.XCB_EVENT_MASK_STRUCTURE_NOTIFY |
            c.XCB_EVENT_MASK_SUBSTRUCTURE_NOTIFY |
            c.XCB_EVENT_MASK_ENTER_WINDOW |
            c.XCB_EVENT_MASK_FOCUS_CHANGE |
            c.XCB_EVENT_MASK_POINTER_MOTION};

        _ = c.xcb_change_window_attributes(manager.xcb_connection, manager.xcb_screen.root, c.XCB_CW_EVENT_MASK, &event_mask_list);

        {
            Input.setupKeybinds(manager.x_display, manager.x_rootwindow);
            Atoms.setupAtoms(manager.xcb_connection, manager.xcb_screen.root);
            Layout.setupLayout();
        }

        // setup cursor
        return manager;
    } // init

    pub fn run(self: *Manager) !void {
        var e: *c.xcb_generic_event_t = undefined;

        while (true) {
            e = c.xcb_wait_for_event(self.xcb_connection);

            switch (e.response_type & ~@as(u8, 0x80)) {
                c.XCB_KEY_PRESS => {
                    std.posix.exit(1);
                },

                c.XCB_MAP_REQUEST => {
                    Layout.handleMapRequest(e);
                },
                else => {
                    // Handle other event types if necessary
                },
            }

            // Free the event when done
        }
    } // run

    pub fn handleError(_: ?*c.Display, event: [*c]c.XErrorEvent) callconv(.C) c_int {
        const evt: *c.XErrorEvent = @ptrCast(event);
        switch (evt.error_code) {
            c.BadMatch => {
                // _ = Logger.Log.err("ZWM_RUN", "BadMatch", .{}) catch {
                //     return undefined;
                // };
                return 0;
            },
            c.BadWindow => {
                // _ = Logger.Log.err("ZWM_RUN", "BadWindow: {any}", .{event.*}) catch {
                //     return undefined;
                // };
                return 0;
            },
            c.BadDrawable => {
                // _ = Logger.Log.err("ZWM_RUN", "BadDrawable", .{}) catch {
                //     return undefined;
                // };
                return 0;
            },
            else => {
                // _ = Logger.Log.err("ZWM_RUN", "Unhandled Error", .{}) catch {
                //     return undefined;
                // };
            },
        }

        return 0;
    } // handleError

    /// Invalidates the contents of the display
    pub fn deinit(self: *const Manager) void {
        _ = c.XCloseDisplay(@constCast(self.x_display));
    }
};
