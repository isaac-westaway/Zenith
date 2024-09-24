// Really bad performance, this is unused

const std = @import("std");

const c = @import("x11.zig").c;

const Imlib2 = @cImport({
    @cInclude("Imlib2.h");
});
const Imlib = Imlib2;

pub const Background = struct {
    allocator: *std.mem.Allocator,

    x_display: *const c.Display,
    x_rootwindow: c.Window,
    x_screen: *const c.Screen,

    pub fn init(allocator: *std.mem.Allocator, display: *const c.Display, rootwindow: c.Window, screen: *const c.Screen) !Background {
        const background: Background = Background{ .allocator = allocator, .x_display = display, .x_rootwindow = rootwindow, .x_screen = screen };

        const scr = c.DefaultScreen(@constCast(background.x_display));

        const dpy: *const c.Display = background.x_display;

        const blackpixel = c.XBlackPixel(@constCast(dpy), scr);
        const whitepixel = c.XWhitePixel(@constCast(dpy), scr);

        const window = c.XCreateSimpleWindow(@constCast(background.x_display), background.x_rootwindow, 0, 0, 1920, 1080, 0, blackpixel, whitepixel);

        _ = c.XMapWindow(@constCast(background.x_display), window);

        const dp: ?*c.Display = @constCast(background.x_display);

        Imlib.imlib_context_set_display(@ptrCast(dp));
        Imlib.imlib_context_set_visual(@ptrCast(c.DefaultVisual(dp, scr)));
        Imlib.imlib_context_set_colormap(c.DefaultColormap(dp, scr));

        const image: Imlib.Imlib_Image = Imlib.imlib_load_image("/home/isaacwestaway/Documents/zig/zwm/image/spacex.jpg");

        Imlib.imlib_context_set_image(image);

        const pixmap = c.XCreatePixmap(@constCast(background.x_display), window, 1920, 1080, @as(c_uint, @intCast(c.DefaultDepth(@constCast(background.x_display), scr))));

        Imlib2.imlib_context_set_drawable(pixmap);
        Imlib2.imlib_render_image_on_drawable(0, 0);

        _ = c.XSetWindowBackgroundPixmap(@constCast(background.x_display), window, pixmap);
        _ = c.XClearWindow(@constCast(background.x_display), window);
        _ = c.XFlush(@constCast(background.x_display));

        return background;
    }
};
