// Really bad performance, this is unused

const std = @import("std");

const c = @import("x11.zig").c;

const Imlib2 = @cImport({
    @cInclude("time.h");
    @cInclude("Imlib2.h");
});

// A lot of this was copied from this github gist:
// https://gist.github.com/AlecsFerra/ef1cc008990319f3b676eb2d8aa89903

const Monitor = struct {
    x_rootwindow: c.Window,
    x_pixelmap: c.Pixmap,
    imlib_context: *Imlib2.Imlib_Context,
    width: u32,
    height: u32,
};

pub fn setRootAtoms(display: *const c.Display, monitor: *Monitor) !void {
    var atom_root: c.Atom = undefined;
    var atom_eroot: c.Atom = undefined;
    var atom_type: c.Atom = undefined;

    var data_root: *u8 = undefined;
    var data_eroot: *u8 = undefined;

    var format: usize = undefined;
    var length: usize = undefined;
    var after: usize = undefined;

    atom_root = c.XInternAtom(@constCast(display), "_XROOTMAP_ID", 1);

    atom_eroot = c.XInternAtom(@constCast(display), "ESETROOT_PMAP_ID", 1);

    const zero: c_long = 0;
    const one: c_long = 1;

    if (atom_root != c.None and atom_eroot != c.None) {
        c.XGetWindowProperty(@constCast(display), monitor.x_rootwindow, atom_root, zero, one, c.False, c.AnyPropertyType, &atom_type, &format, &length, &after, &data_root);

        if (atom_type == c.XA_PIXMAP) {
            c.XGetWindowProperty(@constCast(display), monitor.x_rootwindow, atom_eroot, zero, one, c.False, c.AnyPropertyType, &atom_type, &format, &length, &after, &data_eroot);

            // Could do a pointer cast
            if (data_root and data_eroot and atom_type == c.XA_PIXMAP and (@as(*c.Pixmap, data_root)).* == (@as(*c.Pixmap, data_eroot)).*) {
                c.XKillClient(@constCast(display), @as(*c.Pixmap, data_root).*);
            }
        }
    }

    atom_root = c.XInternAtom(display, "_XROOTPMAP_ID", c.False);
    atom_eroot = c.XInternAtom(display, "ESETROOT_PMAP_ID", c.False);

    c.XChangeProperty(@constCast(display), monitor.x_rootwindow, atom_root, c.XA_PIXMAP, 32, c.PropModeReplace, @ptrCast(monitor.x_pixelmap), 1);

    c.XChangeProperty(@constCast(display), monitor.x_rootwindow, atom_eroot, c.XA_PIXMAP, 32, c.PropModeReplace, @ptrCast(monitor.x_pixelmap), 1);
}

pub fn loadImages(display: *const c.Display, rootwindow: c.Window, screen: *const c.Screen) !*[]Imlib2.Imlib_Image {
    const imlib_images = {
        Imlib2.imlib_load_image("");
        Imlib2.imlib_load_image("");
        Imlib2.imlib_load_image("");
        Imlib2.imlib_load_image("");
        Imlib2.imlib_load_image("");
        Imlib2.imlib_load_image("");
        Imlib2.imlib_load_image("");
    };
    const image_count = 8;

    var monitor: Monitor = undefined;

    // TODO: add support for numerous monitors later
    const width = c.DisplayWidth(@constCast(display), @constCast(screen).*);
    const height = c.DisplayHeight(@constCast(display), @constCast(screen).*);

    const depth = c.DefaultDepth(@constCast(display), @constCast(screen).*);

    const visual: c.Visual = c.DefaultVisual(@constCast(display), @constCast(screen).*);
    const cm = c.DefaultColormap(@constCast(display), @constCast(screen).*);

    monitor.x_rootwindow = rootwindow;
    monitor.x_pixelmap = c.XCreatePixmap(@constCast(display), rootwindow, width, height, depth);

    const ctx = Imlib2.imlib_context_new();
    monitor.imlib_context = &ctx;

    Imlib2.imlib_context_set_display(@constCast(display));
    Imlib2.imlib_context_set_visual(visual);
    Imlib2.imlib_context_set_colormap(cm);
    Imlib2.imlib_context_set_drawable(monitor.x_pixelmap);
    Imlib2.imlib_context_set_color_range(Imlib2.imlib_create_color_range());
    Imlib2.imlib_context_pop();

    var timeout: c.timespec = undefined;

    timeout.tv_sec = 0;
    timeout.tv_nsec = 33000000;

    for (0..10) |cycle| {
        const current: Imlib2.Imlib_Image = imlib_images[cycle & image_count];

        Imlib2.imlib_context_push(monitor.imlib_context);
        Imlib2.imlib_context_set_dither(1);
        Imlib2.imlib_context_set_blend(1);

        Imlib2.imlib_context_set_image(current);

        Imlib2.imlib_render_image_on_drawable(0, 0);

        setRootAtoms(display, monitor);

        c.XKillClient(@constCast(display), c.AllTemporary);

        c.XSetCloseDownMode(@constCast(display), c.RetainTemporary);

        c.XSetWindowBackgroundPixmap(@constCast(display), monitor.x_rootwindow, monitor.x_pixelmap);

        c.XClearWindow(@constCast(display), monitor.x_rootwindow);

        c.XFlush(@constCast(display));

        c.XSync(@constCast(display), c.False);

        Imlib2.imlib_context_pop();

        Imlib2.nanosleep(&timeout, Imlib2.NULL);
    }

    return imlib_images;
}
