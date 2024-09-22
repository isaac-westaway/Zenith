const c = @import("x11.zig").c;

pub const Window = struct {
    window: c.Window,
    fullscreen: bool,
    modified: bool,

    // We need fullscreen window data because what if the user chooses to move around the fullscreen window
    f_x: i32,
    f_y: i32,

    f_w: u32,
    f_h: u32,

    w_x: i32,
    w_y: i32,

    w_w: u32,
    w_h: u32,
};
