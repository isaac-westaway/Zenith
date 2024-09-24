// Really bad performance, this is unused

const std = @import("std");

const c = @import("x11.zig").c;

const Imlib2 = @cImport({
    @cInclude("Imlib2.h");
});
const Imlib = Imlib2;

const Config = @import("config");

pub const Background = struct {
    allocator: *std.mem.Allocator,

    x_display: *const c.Display,
    x_rootwindow: c.Window,
    x_screen: *const c.Screen,

    background: c.Window,

    pub fn init(allocator: *std.mem.Allocator, display: *const c.Display, rootwindow: c.Window, screen: *const c.Screen) !Background {
        var background: Background = Background{ .allocator = allocator, .x_display = display, .x_rootwindow = rootwindow, .x_screen = screen, .background = undefined };

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

        const image: Imlib.Imlib_Image = Imlib.imlib_load_image(@ptrCast(Config.background_path));
        Imlib.imlib_context_set_image(image);

        const src_width: c_int = Imlib.imlib_image_get_width();
        const src_height: c_int = Imlib.imlib_image_get_height();
        const dst_width: c_int = 1920;
        const dst_height: c_int = 1080;

        const scaled_image: Imlib.Imlib_Image = Imlib.imlib_create_cropped_scaled_image(0, 0, src_width, src_height, dst_width, dst_height);
        Imlib.imlib_context_set_image(scaled_image);

        const pixmap = c.XCreatePixmap(@constCast(background.x_display), window, 1920, 1080, @as(c_uint, @intCast(c.DefaultDepth(@constCast(background.x_display), scr))));

        Imlib.imlib_context_set_drawable(pixmap);
        Imlib.imlib_render_image_on_drawable(0, 0);

        _ = c.XSetWindowBackgroundPixmap(@constCast(background.x_display), window, pixmap);
        _ = c.XClearWindow(@constCast(background.x_display), window);
        _ = c.XFlush(@constCast(background.x_display));

        background.background = window;

        return background;
    }
};
