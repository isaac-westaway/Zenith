const std = @import("std");

const Logger = @import("zlog");

const c = @import("x11.zig").c;

/// Is this struct even necessary?
pub const Input = struct {
    allocator: *std.mem.Allocator,

    // Do I really need all this?
    x_display: *const c.Display,
    x_rootwindow: *const c.Window,

    /// Grabs input
    pub fn init(allocator: *std.mem.Allocator, display: *const c.Display, rootwindow: *const c.Window) !Input {
        var input: Input = undefined;

        input.allocator = allocator;

        input.x_display = display;
        input.x_rootwindow = rootwindow;

        _ = c.XUngrabKey(@constCast(input.x_display), c.AnyKey, c.AnyModifier, @constCast(input.x_rootwindow).*);

        _ = c.XGrabKey(@constCast(input.x_display), c.XKeysymToKeycode(@constCast(input.x_display), c.XK_Return), c.Mod4Mask, @constCast(input.x_rootwindow).*, 0, c.GrabModeAsync, c.GrabModeAsync);

        _ = c.XGrabKey(@constCast(input.x_display), c.XKeysymToKeycode(@constCast(input.x_display), c.XK_Escape), c.Mod4Mask, @constCast(input.x_rootwindow).*, 0, c.GrabModeAsync, c.GrabModeAsync);

        _ = c.XGrabKey(@constCast(input.x_display), c.XKeysymToKeycode(@constCast(input.x_display), c.XK_Tab), c.Mod4Mask, @constCast(input.x_rootwindow).*, 0, c.GrabModeAsync, c.GrabModeAsync);
        _ = c.XGrabKey(@constCast(input.x_display), c.XKeysymToKeycode(@constCast(input.x_display), c.XK_Tab), c.Mod4Mask | c.ShiftMask, @constCast(input.x_rootwindow).*, 0, c.GrabModeAsync, c.GrabModeAsync);

        _ = c.XGrabKey(@constCast(input.x_display), c.XKeysymToKeycode(@constCast(input.x_display), c.XK_f), c.Mod4Mask, @constCast(input.x_rootwindow).*, 0, c.GrabModeAsync, c.GrabModeAsync);
        _ = c.XGrabKey(@constCast(input.x_display), c.XKeysymToKeycode(@constCast(input.x_display), c.XK_q), c.Mod4Mask, @constCast(input.x_rootwindow).*, 0, c.GrabModeAsync, c.GrabModeAsync);

        _ = c.XGrabKey(@constCast(input.x_display), c.XKeysymToKeycode(@constCast(input.x_display), c.XK_d), c.Mod4Mask, @constCast(input.x_rootwindow).*, 0, c.GrabModeAsync, c.GrabModeAsync);
        _ = c.XGrabKey(@constCast(input.x_display), c.XKeysymToKeycode(@constCast(input.x_display), c.XK_a), c.Mod4Mask, @constCast(input.x_rootwindow).*, 0, c.GrabModeAsync, c.GrabModeAsync);

        _ = c.XGrabButton(@constCast(input.x_display), 1, c.Mod4Mask, @constCast(input.x_rootwindow).*, 0, c.ButtonPress | c.Button1MotionMask | @as(c_uint, @intCast(c.PointerMotionMask)), c.GrabModeAsync, c.GrabModeAsync, 0, 0);

        _ = c.XGrabButton(@constCast(input.x_display), 3, c.Mod4Mask, @constCast(input.x_rootwindow).*, 0, c.ButtonPress | c.Button3Mask | @as(c_uint, @intCast(c.PointerMotionMask)), c.GrabModeAsync, c.GrabModeAsync, 0, 0);

        return input;
    }
};
