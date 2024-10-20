const c = @import("x11.zig").c;

const Config = @import("config");

pub fn setupKeybinds(display: *c.Display, rootwindow: c.Window) void {
    _ = c.XUngrabKey(display, c.AnyKey, c.AnyModifier, rootwindow);

    _ = c.XGrabKey(display, c.XKeysymToKeycode(display, Config.terminal_key), Config.terminal_super, rootwindow, 0, c.GrabModeAsync, c.GrabModeAsync);

    _ = c.XGrabKey(display, c.XKeysymToKeycode(display, Config.close_key), Config.close_super, rootwindow, 0, c.GrabModeAsync, c.GrabModeAsync);

    _ = c.XGrabKey(display, c.XKeysymToKeycode(display, Config.cycle_forward_key), Config.cycle_forward_super, rootwindow, 0, c.GrabModeAsync, c.GrabModeAsync);
    _ = c.XGrabKey(display, c.XKeysymToKeycode(display, Config.cycle_forward_key), Config.cycle_forward_super | Config.cycle_backward_super_second, rootwindow, 0, c.GrabModeAsync, c.GrabModeAsync);

    _ = c.XGrabKey(display, c.XKeysymToKeycode(display, Config.scrot_key), Config.scrot_super, rootwindow, 0, c.GrabModeAsync, c.GrabModeAsync);

    _ = c.XGrabKey(display, c.XKeysymToKeycode(display, Config.fullscreen_key), Config.fullscreen_super, rootwindow, 0, c.GrabModeAsync, c.GrabModeAsync);
    _ = c.XGrabKey(display, c.XKeysymToKeycode(display, Config.close_window_key), Config.close_window_super, rootwindow, 0, c.GrabModeAsync, c.GrabModeAsync);
    _ = c.XGrabKey(display, c.XKeysymToKeycode(display, Config.push_forward_key), Config.push_forward_super, rootwindow, 0, c.GrabModeAsync, c.GrabModeAsync);
    _ = c.XGrabKey(display, c.XKeysymToKeycode(display, Config.push_backward_key), Config.push_backward_super, rootwindow, 0, c.GrabModeAsync, c.GrabModeAsync);

    _ = c.XGrabKey(display, c.XKeysymToKeycode(display, Config.workspace_cycle_forward_key), Config.workspace_cycle_forward_super, rootwindow, 0, c.GrabModeAsync, c.GrabModeAsync);
    _ = c.XGrabKey(display, c.XKeysymToKeycode(display, Config.workspace_cycle_backward_key), Config.workspace_cycle_backward_super, rootwindow, 0, c.GrabModeAsync, c.GrabModeAsync);

    _ = c.XGrabKey(display, c.XKeysymToKeycode(display, Config.swap_left_right_mastker_key), Config.swap_left_right_master_super, rootwindow, 0, c.GrabModeAsync, c.GrabModeAsync);

    // " ` " aka tilde aka grave aka backtick
    _ = c.XGrabKey(display, c.XKeysymToKeycode(display, Config.unfocus_key), Config.unfocus_super, rootwindow, 0, c.GrabModeAsync, c.GrabModeAsync);

    _ = c.XGrabKey(display, c.XKeysymToKeycode(display, Config.workspace_append_key), Config.worskpace_append_super, rootwindow, 0, c.GrabModeAsync, c.GrabModeAsync);
    _ = c.XGrabKey(display, c.XKeysymToKeycode(display, Config.workspace_pop_key), Config.workspace_pop_super, rootwindow, 0, c.GrabModeAsync, c.GrabModeAsync);

    _ = c.XGrabKey(display, c.XKeysymToKeycode(display, Config.add_focused_master_key), Config.add_focused_master_super, rootwindow, 0, c.GrabModeAsync, c.GrabModeAsync);
    _ = c.XGrabKey(display, c.XKeysymToKeycode(display, Config.add_focused_slave_key), Config.add_focused_slave_super, rootwindow, 0, c.GrabModeAsync, c.GrabModeAsync);

    _ = c.XGrabButton(display, Config.mouse_button_left, c.Mod4Mask, rootwindow, 0, c.ButtonPress | Config.mouse_motion_left | @as(c_uint, @intCast(c.PointerMotionMask)), c.GrabModeAsync, c.GrabModeAsync, 0, 0);

    _ = c.XGrabButton(display, Config.mouse_button_right, c.Mod4Mask, rootwindow, 0, c.ButtonPress | Config.mouse_motion_right | @as(c_uint, @intCast(c.PointerMotionMask)), c.GrabModeAsync, c.GrabModeAsync, 0, 0);
}
