const std = @import("std");

const Logger = @import("zlog");

const Actions = @import("actions.zig");
const Keys = @import("keys.zig");

const c = @import("x11.zig").c;

pub const Input = struct {
    allocator: *std.mem.Allocator,

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

        _ = c.XGrabButton(@constCast(input.x_display), 1, c.Mod4Mask, @constCast(input.x_rootwindow).*, 0, c.ButtonPress | c.Button1MotionMask | @as(c_uint, @intCast(c.PointerMotionMask)), c.GrabModeAsync, c.GrabModeAsync, 0, 0);

        _ = c.XGrabButton(@constCast(input.x_display), 3, c.Mod4Mask, @constCast(input.x_rootwindow).*, 0, c.ButtonPress | c.Button3Mask | @as(c_uint, @intCast(c.PointerMotionMask)), c.GrabModeAsync, c.GrabModeAsync, 0, 0);

        return input;
    }

    /// Resoluves input
    pub fn resolveKeyInput(self: *const Input, event: *c.XKeyPressedEvent) !void {
        try Logger.Log.info("ZWM_RUN_RESOLVEKEYINPUT", "Attempting to resolve key pressed with the keycode: {any}", .{event.keycode});

        // TODO: make this more dynamic, to see keycodes run `xev` in a terminal
        if (event.keycode == 36) {
            try Logger.Log.info("ZWM_RUN_RESOLVEKEYINPUT", "XK_Return pressed", .{});
            Actions.openTerminal(self.allocator);
        }

        if (event.keycode == 9) {
            try Logger.Log.fatal("ZWM_RUN_RESOLVEKEYINPUT", "Closing Window Manager", .{});
        }
    }

    pub fn resolveButtonInput(self: *const Input, event: c.XButtonPressedEvent) !void {
        _ = self;
        _ = event;
    }
};
