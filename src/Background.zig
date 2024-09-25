const std = @import("std");

const x11 = @import("x11.zig");
const c = @import("x11.zig").c;

const A = @import("Atoms.zig");
const Atoms = @import("Atoms.zig").Atoms;

const Imlib2 = @cImport({
    @cInclude("Imlib2.h");
});
const Imlib = Imlib2;

const Config = @import("config");
const Logger = @import("zlog");

pub const Background = struct {
    allocator: *std.mem.Allocator,

    x_display: *const c.Display,
    x_rootwindow: c.Window,
    x_screen: *const c.Screen,

    background: c.Window,

    pub fn init(allocator: *std.mem.Allocator, display: *const c.Display, rootwindow: c.Window, screen: *const c.Screen) !Background {
        var background: Background = Background{
            .allocator = allocator,
            .x_display = display,
            .x_rootwindow = rootwindow,
            .x_screen = screen,
            .background = undefined,
        };

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

        // Insert list of images and switch between them
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

    pub fn animateWindow(allocator: *std.mem.Allocator, display: *const c.Display, rootwindow: c.Window, screen: *const c.Screen) !Background {
        var background = Background{
            .allocator = allocator,
            .x_display = display,
            .x_rootwindow = rootwindow,
            .x_screen = screen,
            .background = undefined,
        };

        const scr = c.DefaultScreen(@constCast(display));

        const dpy: *const c.Display = display;

        const blackpixel = c.XBlackPixel(@constCast(dpy), scr);
        const whitepixel = c.XWhitePixel(@constCast(dpy), scr);

        const window = c.XCreateSimpleWindow(@constCast(display), rootwindow, 0, 0, 1920, 1080, 0, blackpixel, whitepixel);

        background.background = window;

        return background;
    }

    /// To be executed on a separate thread
    /// Works well, good performance, though room for improvement by using an SDL2 texture
    pub fn animateBackground(allocator: *std.mem.Allocator, display: *const c.Display, window: c.Window, rootwindow: c.Window) void {
        _ = rootwindow;
        const scr = c.DefaultScreen(@constCast(display));

        const dp: ?*c.Display = @constCast(display);

        Imlib.imlib_context_set_display(@ptrCast(dp));
        Imlib.imlib_context_set_visual(@ptrCast(c.DefaultVisual(dp, scr)));
        Imlib.imlib_context_set_colormap(c.DefaultColormap(dp, scr));

        const pixmap = c.XCreatePixmap(@constCast(display), window, 1920, 1080, @as(c_uint, @intCast(c.DefaultDepth(@constCast(display), scr))));
        Imlib.imlib_context_set_drawable(pixmap);

        var timeout: c.timespec = undefined;
        timeout.tv_sec = 0;
        timeout.tv_nsec = 33000000;

        var images: [Config.number_of_images]Imlib.Imlib_Image = undefined;

        for (0..Config.number_of_images) |index| {
            const file_path = std.fmt.allocPrint(allocator.*, "{s}{s}-{d}.{s}", .{ Config.image_directory, Config.image_file_name, index, Config.image_file_extension }) catch unreachable;

            const null_term_slice = allocator.dupeZ(u8, file_path[0..file_path.len]) catch unreachable;

            images[index] = Imlib.imlib_load_image(null_term_slice);
        }

        var scaled_images: [Config.number_of_images]Imlib.Imlib_Image = undefined;
        const dst_width: c_int = 1920;
        const dst_height: c_int = 1080;

        for (0..Config.number_of_images) |index| {
            Imlib.imlib_context_set_image(images[index]);

            const src_width: c_int = Imlib.imlib_image_get_width();
            const src_height: c_int = Imlib.imlib_image_get_height();

            scaled_images[index] = Imlib.imlib_create_cropped_scaled_image(0, 0, src_width, src_height, dst_width, dst_height);
        }

        _ = c.XMapWindow(@constCast(display), window);

        while (true) {
            for (0..Config.number_of_images) |index| {
                Imlib.imlib_context_set_image(scaled_images[index]);

                Imlib.imlib_render_image_on_drawable(0, 0);

                _ = c.XKillClient(@constCast(display), c.AllTemporary);
                _ = c.XSetCloseDownMode(@constCast(display), c.RetainTemporary);
                _ = c.XSetWindowBackgroundPixmap(@constCast(display), window, pixmap);
                _ = c.XClearWindow(@constCast(display), window);
                _ = c.XFlush(@constCast(display));
                _ = c.XSync(@constCast(display), c.False);
                std.posix.nanosleep(@intCast(timeout.tv_sec), @intCast(timeout.tv_nsec));
            }
        }
    }
};
