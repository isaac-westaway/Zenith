const std = @import("std");

const c = @import("x11.zig").c;

const Config = @import("config");

/// Is this struct even necessary?
pub const Input = struct {
    allocator: *std.mem.Allocator,

    // Do I really need all this?
    x_display: *const c.Display,
    x_rootwindow: c.Window,

    /// Grabs input
    pub fn init(allocator: *std.mem.Allocator, display: *const c.Display, rootwindow: c.Window) !Input {
        var input: Input = undefined;

        input.allocator = allocator;

        input.x_display = display;
        input.x_rootwindow = rootwindow;

        _ = c.XUngrabKey(@constCast(input.x_display), c.AnyKey, c.AnyModifier, input.x_rootwindow);

        _ = c.XGrabKey(@constCast(input.x_display), c.XKeysymToKeycode(@constCast(input.x_display), Config.terminal_key), Config.terminal_super, input.x_rootwindow, 0, c.GrabModeAsync, c.GrabModeAsync);

        _ = c.XGrabKey(@constCast(input.x_display), c.XKeysymToKeycode(@constCast(input.x_display), Config.close_key), Config.close_super, input.x_rootwindow, 0, c.GrabModeAsync, c.GrabModeAsync);

        _ = c.XGrabKey(@constCast(input.x_display), c.XKeysymToKeycode(@constCast(input.x_display), Config.cycle_forward_key), Config.cycle_forward_super, input.x_rootwindow, 0, c.GrabModeAsync, c.GrabModeAsync);
        _ = c.XGrabKey(@constCast(input.x_display), c.XKeysymToKeycode(@constCast(input.x_display), Config.cycle_forward_key), Config.cycle_forward_super | Config.cycle_backward_super_second, input.x_rootwindow, 0, c.GrabModeAsync, c.GrabModeAsync);

        _ = c.XGrabKey(@constCast(input.x_display), c.XKeysymToKeycode(@constCast(input.x_display), Config.scrot_key), Config.scrot_super, input.x_rootwindow, 0, c.GrabModeAsync, c.GrabModeAsync);

        _ = c.XGrabKey(@constCast(input.x_display), c.XKeysymToKeycode(@constCast(input.x_display), Config.fullscreen_key), Config.fullscreen_super, input.x_rootwindow, 0, c.GrabModeAsync, c.GrabModeAsync);
        _ = c.XGrabKey(@constCast(input.x_display), c.XKeysymToKeycode(@constCast(input.x_display), Config.close_window_key), Config.close_window_super, input.x_rootwindow, 0, c.GrabModeAsync, c.GrabModeAsync);
        _ = c.XGrabKey(@constCast(input.x_display), c.XKeysymToKeycode(@constCast(input.x_display), Config.push_forward_key), Config.push_forward_super, input.x_rootwindow, 0, c.GrabModeAsync, c.GrabModeAsync);
        _ = c.XGrabKey(@constCast(input.x_display), c.XKeysymToKeycode(@constCast(input.x_display), Config.push_backward_key), Config.push_backward_super, input.x_rootwindow, 0, c.GrabModeAsync, c.GrabModeAsync);

        _ = c.XGrabKey(@constCast(input.x_display), c.XKeysymToKeycode(@constCast(input.x_display), Config.workspace_cycle_forward_key), Config.workspace_cycle_forward_super, input.x_rootwindow, 0, c.GrabModeAsync, c.GrabModeAsync);
        _ = c.XGrabKey(@constCast(input.x_display), c.XKeysymToKeycode(@constCast(input.x_display), Config.workspace_cycle_backward_key), Config.workspace_cycle_backward_super, input.x_rootwindow, 0, c.GrabModeAsync, c.GrabModeAsync);

        _ = c.XGrabKey(@constCast(input.x_display), c.XKeysymToKeycode(@constCast(input.x_display), Config.swap_left_right_mastker_key), Config.swap_left_right_master_super, input.x_rootwindow, 0, c.GrabModeAsync, c.GrabModeAsync);

        // " ` " aka tilde aka grave aka backtick
        _ = c.XGrabKey(@constCast(input.x_display), c.XKeysymToKeycode(@constCast(input.x_display), Config.unfocus_key), Config.unfocus_super, input.x_rootwindow, 0, c.GrabModeAsync, c.GrabModeAsync);

        _ = c.XGrabKey(@constCast(input.x_display), c.XKeysymToKeycode(@constCast(input.x_display), Config.workspace_append_key), Config.worskpace_append_super, input.x_rootwindow, 0, c.GrabModeAsync, c.GrabModeAsync);
        _ = c.XGrabKey(@constCast(input.x_display), c.XKeysymToKeycode(@constCast(input.x_display), Config.workspace_pop_key), Config.workspace_pop_super, input.x_rootwindow, 0, c.GrabModeAsync, c.GrabModeAsync);

        _ = c.XGrabButton(@constCast(input.x_display), Config.mouse_button_left, c.Mod4Mask, input.x_rootwindow, 0, c.ButtonPress | Config.mouse_motion_left | @as(c_uint, @intCast(c.PointerMotionMask)), c.GrabModeAsync, c.GrabModeAsync, 0, 0);

        _ = c.XGrabButton(@constCast(input.x_display), Config.mouse_button_right, c.Mod4Mask, input.x_rootwindow, 0, c.ButtonPress | Config.mouse_motion_right | @as(c_uint, @intCast(c.PointerMotionMask)), c.GrabModeAsync, c.GrabModeAsync, 0, 0);

        return input;
    } // init
};
