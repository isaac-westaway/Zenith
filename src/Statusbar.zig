const std = @import("std");

const c = @import("x11.zig").c;

pub const Statusbar = struct {
    allocator: *std.mem.Allocator,

    x_display: *const c.Display,
    x_rootwindow: *const c.Window,
    x_screen: *const c.Screen,

    x_drawable: c.Drawable,
    x_gc: c.GC,

    pub fn init(allocator: *std.mem.Allocator, display: *const c.Display, rootwindow: *const c.Window, screen: *const c.Screen) !Statusbar {
        var statusbar: Statusbar = Statusbar{
            .allocator = allocator,
            .x_display = display,
            .x_rootwindow = rootwindow,
            .x_screen = screen,

            .x_drawable = undefined,
            .x_gc = undefined,
        };

        const scr = c.DefaultScreen(@constCast(statusbar.x_display));

        const dpy: *const c.Display = statusbar.x_display;
        const rw = @constCast(statusbar.x_rootwindow).*;
        const x_start: c_int = @intCast(c.XDisplayWidth(@constCast(dpy), scr) - 50);
        const y_start = 0;

        // WHY CAN THE SCREEN WIDTH BE NEGATIVE???
        const x_end: c_uint = @intCast(c.XDisplayWidth(@constCast(dpy), scr));
        const y_end = 20;
        const border = 3;
        const blackpixel = c.XBlackPixel(@constCast(dpy), scr);
        const whitepixel = c.XWhitePixel(@constCast(dpy), scr);

        statusbar.x_drawable = c.XCreateSimpleWindow(@constCast(dpy), rw, x_start, y_start, x_end, y_end, border, blackpixel, whitepixel);

        _ = c.XMapWindow(@constCast(dpy), statusbar.x_drawable);

        var values: c.XGCValues = c.XGCValues{
            .foreground = 0xef9f1c,
            .background = 0xef9f1c,
            .line_width = 2,
            .line_style = c.LineSolid,
            .fill_style = c.FillSolid,
        };

        statusbar.x_gc = c.XCreateGC(@constCast(statusbar.x_display), statusbar.x_drawable, 0, &values);

        _ = c.XDrawRectangle(@constCast(statusbar.x_display), statusbar.x_drawable, statusbar.x_gc, 0, 0, x_end, 50);

        return statusbar;
    }
};
