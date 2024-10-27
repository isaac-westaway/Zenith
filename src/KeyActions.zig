const std = @import("std");

const c = @import("x11.zig").c;

const Actions = @import("Actions.zig");

// const Desktop = @import("Desktop.zig"); // just for the time being
const Workspace = @import("Workspace.zig");
const Client = @import("Client.zig"); // for the client type

const Config = @import("config");

fn keysymToKeycode(xcb_connection: *c.xcb_connection_t, xcb_keysym: c.xcb_keysym_t) c.xcb_keycode_t {
    const key_symbols: ?*c.xcb_key_symbols_t = c.xcb_key_symbols_alloc(xcb_connection);

    if (key_symbols) |key_syms| {
        const keycode: *c.xcb_keycode_t = c.xcb_key_symbols_get_keycode(key_syms, xcb_keysym);
        c.xcb_key_symbols_free(key_syms);
        return keycode.*;
    }

    return 0;
} // keysymToKeycode

pub fn setupKeyboardPointerActions(xcb_connection: *c.xcb_connection_t, xcb_rootwindow: c.xcb_window_t) void {
    _ = c.xcb_ungrab_key(xcb_connection, c.XCB_GRAB_ANY, xcb_rootwindow, c.XCB_MOD_MASK_ANY);

    for (Config.key_binds) |keybind| {
        _ = c.xcb_grab_key(xcb_connection, 1, xcb_rootwindow, @intCast(keybind.key_mask), keysymToKeycode(xcb_connection, keybind.key_sym), c.XCB_GRAB_MODE_ASYNC, c.XCB_GRAB_MODE_ASYNC);
    }

    _ = c.xcb_flush(xcb_connection);
} // grabKeyboardPointerActions

// The handle key press SHOULD be in charge of retiling windows
pub fn handleKeyPress(allocator: *std.mem.Allocator, event: *c.xcb_generic_event_t) void {
    const key_press_event: *c.xcb_key_press_event_t = @ptrCast(event);

    // Workspace.workspace.current_desktop;

    // Escape
    // Just kill the window manager
    // Could implement logic to check if the user really meant to close the wm
    if (key_press_event.detail == 9) {
        std.posix.exit(1);
    }

    // Terminal
    if (key_press_event.detail == 36) {
        Actions.openTerminal(allocator);
    }
} // handleKeyPress
