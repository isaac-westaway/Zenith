const std = @import("std");

pub const c = @cImport({
    @cInclude("xcb/xcb.h");
    @cInclude("xcb/xproto.h");
    @cInclude("xcb/xcb_cursor.h");
    @cInclude("xcb/xcb_keysyms.h");

    @cInclude("xcb/xcb_atom.h");
    @cInclude("xcb/xcb_ewmh.h");
    @cInclude("xcb/xcb_icccm.h");

    @cInclude("X11/Xlib.h");
    @cInclude("X11/XF86keysym.h");
    @cInclude("X11/keysym.h");
    @cInclude("X11/XKBlib.h");
    @cInclude("X11/Xatom.h");
    @cInclude("X11/Xutil.h");
    @cInclude("X11/Xlib-xcb.h");
});
