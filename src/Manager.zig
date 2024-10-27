const std = @import("std");
const builtin = @import("builtin");

// Should it be a custom linked list type

const c = @import("x11.zig").c;

// the manager struct should be in control of the background and statusbar

const Atoms = @import("Atoms.zig");

const Workspace = @import("Workspace.zig");

const KeyActions = @import("KeyActions.zig");

pub const ErrorManagerInit = error{ XorgDisplayFail, XCBConnectionFail };

const Config = @import("config");

// What if the current desktop is a pointer to a doubly linked list
// Pointer to the previously focused

pub const ManagerType = struct {
    allocator: *std.mem.Allocator,

    x_display: *c.Display,
    x_rootwindow: c.Window,

    xcb_connection: *c.xcb_connection_t,
    xcb_ewmh_connection: *c.xcb_ewmh_connection_t,
    xcb_screen: *c.xcb_screen_t,

    // The current desktop should be replaced with the current monitor and then
    // the current desktop move into current monitor
    workspaces: std.DoublyLinkedList(Workspace.TypeWorkspace),
    current_workspace: std.DoublyLinkedList(Workspace.TypeWorkspace).Node,
};

pub var manager: ManagerType = undefined;

pub fn setupManager(allocator: *std.mem.Allocator) ErrorManagerInit!void {
    manager.allocator = allocator;

    {
        manager.x_display = c.XOpenDisplay(null) orelse return ErrorManagerInit.XorgDisplayFail;
        manager.x_rootwindow = c.XRootWindow(manager.x_display, 0);
        manager.xcb_connection = c.XGetXCBConnection(manager.x_display) orelse return ErrorManagerInit.XCBConnectionFail;

        manager.workspaces = std.DoublyLinkedList(Workspace.TypeWorkspace){};
    }

    _ = c.XSetErrorHandler(handleManagerErrors);
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
        KeyActions.setupKeyboardPointerActions(manager.xcb_connection, manager.xcb_screen.root);

        // TODO: check if there is only one workspace
        for (0..Config.initial_number_of_workspaces) |_| {
            // pass a pointer to the last element
            // the setup workspace should appe

            const node = Workspace.addWorkspace(manager.allocator, &std.DoublyLinkedList(Workspace.TypeWorkspace)) catch unreachable;

            manager.workspaces.append(node);
        }

        Atoms.setupAtoms(manager.xcb_connection, manager.xcb_screen.root);
    }
} // setupManager

// A run error should kill the window manager, therefore this should not error
pub fn runManager() void {
    var e: *c.xcb_generic_event_t = undefined;

    while (true) {
        e = c.xcb_wait_for_event(manager.xcb_connection);

        switch (e.response_type & ~@as(u8, 0x80)) {
            c.XCB_KEY_PRESS => {
                KeyActions.handleKeyPress(manager.allocator, e);
            },

            c.XCB_MAP_REQUEST => {
                Workspace.handleMapRequest(manager.allocator, manager.xcb_connection, e);
                // Monitor.handleMapRequest(e);
            },
            else => {
                // Handle other event types if necessary
            },
        }
    }
} // run

pub fn handleManagerErrors(_: ?*c.Display, event: [*c]c.XErrorEvent) callconv(.C) c_int {
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

pub fn closeManager() void {
    _ = c.XCloseDisplay(manager.x_display);
} // closeManager
