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

// Yes i acknowledge the code here is pretty bad, dpy, display, 10^3 variables with the same use

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

        const screen_width: c_uint = @intCast(c.XDisplayWidth(@constCast(display), scr));
        const screen_height: c_uint = @intCast(c.XDisplayHeight(@constCast(display), scr));

        const window_attributes = c.XSetWindowAttributes{ .override_redirect = 1, .background_pixel = 0xFFFFFFFF };

        const window = c.XCreateSimpleWindow(@constCast(background.x_display), background.x_rootwindow, 0, 0, screen_width, screen_height, 0, blackpixel, whitepixel);
        _ = c.XMapWindow(@constCast(background.x_display), window);

        _ = c.XConfigureWindow(@constCast(background.x_display), window, c.CWOverrideRedirect, @ptrCast(@constCast(&window_attributes)));

        const opacity_atom: c.Atom = c.XInternAtom(@constCast(background.x_display), "_NET_WM_WINDOW_OPACITY", c.False);

        const opacity: c_uint = 0xFFFFFFFF;

        _ = c.XChangeProperty(@constCast(background.x_display), window, opacity_atom, c.XA_CARDINAL, 32, c.PropModeReplace, @ptrCast(&opacity), 1);

        const dp: ?*c.Display = @constCast(background.x_display);

        Imlib.imlib_context_set_display(@ptrCast(dp));
        Imlib.imlib_context_set_visual(@ptrCast(c.DefaultVisual(dp, scr)));
        Imlib.imlib_context_set_colormap(c.DefaultColormap(dp, scr));

        // Insert list of images and switch between them
        const image: Imlib.Imlib_Image = Imlib.imlib_load_image(@ptrCast(Config.background_path));
        Imlib.imlib_context_set_image(image);

        // TODO: make the background setting dynamically sized to the monitor
        const src_width: c_int = Imlib.imlib_image_get_width();
        const src_height: c_int = Imlib.imlib_image_get_height();
        const dst_width: c_int = @intCast(screen_width);
        const dst_height: c_int = @intCast(screen_height);

        const scaled_image: Imlib.Imlib_Image = Imlib.imlib_create_cropped_scaled_image(0, 0, src_width, src_height, dst_width, dst_height);
        Imlib.imlib_context_set_image(scaled_image);

        const pixmap = c.XCreatePixmap(@constCast(background.x_display), window, screen_width, screen_height, @as(c_uint, @intCast(c.DefaultDepth(@constCast(background.x_display), scr))));

        Imlib.imlib_context_set_drawable(pixmap);
        Imlib.imlib_render_image_on_drawable(0, 0);

        _ = c.XSetWindowBackgroundPixmap(@constCast(background.x_display), window, pixmap);
        _ = c.XClearWindow(@constCast(background.x_display), window);
        _ = c.XFlush(@constCast(background.x_display));

        background.background = window;

        return background;
    } // init

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

        const screen_width: c_uint = @intCast(c.XDisplayWidth(@constCast(display), scr));
        const screen_height: c_uint = @intCast(c.XDisplayHeight(@constCast(display), scr));

        const window = c.XCreateSimpleWindow(@constCast(display), rootwindow, 0, 0, screen_width, screen_height, 0, blackpixel, whitepixel);

        const opacity_atom: c.Atom = c.XInternAtom(@constCast(background.x_display), "_NET_WM_WINDOW_OPACITY", c.False);

        const opacity: c_uint = 0xFFFFFFFF;

        _ = c.XChangeProperty(@constCast(background.x_display), window, opacity_atom, c.XA_CARDINAL, 32, c.PropModeReplace, @ptrCast(&opacity), 1);

        background.background = window;

        return background;
    } // animateWindow

    pub fn animateBackground(allocator: *std.mem.Allocator, display: *const c.Display, window: c.Window, rootwindow: c.Window) void {
        _ = rootwindow;
        const scr = c.DefaultScreen(@constCast(display));

        const dp: ?*c.Display = @constCast(display);

        Imlib.imlib_context_set_display(@ptrCast(dp));
        Imlib.imlib_context_set_visual(@ptrCast(c.DefaultVisual(dp, scr)));
        Imlib.imlib_context_set_colormap(c.DefaultColormap(dp, scr));

        const screen = c.DefaultScreen(@constCast(display));

        const screen_width: c_uint = @intCast(c.XDisplayWidth(@constCast(display), screen));
        const screen_height: c_uint = @intCast(c.XDisplayHeight(@constCast(display), screen));

        const pixmap = c.XCreatePixmap(@constCast(display), window, screen_width, screen_height, @as(c_uint, @intCast(c.DefaultDepth(@constCast(display), scr))));
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
        const dst_width: c_int = @intCast(screen_width);
        const dst_height: c_int = @intCast(screen_height);

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
    } //animateBackground
};
