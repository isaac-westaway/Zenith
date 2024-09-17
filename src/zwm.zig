const std = @import("std");
const builtin = @import("builtin");
const root = @import("root");

const Logger = @import("zlog");

const c = @cImport({
    @cInclude("X11/Xlib.h");
    @cInclude("X11/XF86keysym.h");
    @cInclude("X11/keysym.h");
    @cInclude("X11/XKBlib.h");
    @cInclude("X11/Xatom.h");
    @cInclude("X11/Xutil.h");
});
pub const Manager = struct {
    allocator: *std.mem.Allocator,

    x_display: *const c.Display,
    x_rootwindow: *const c.Window,
    x_screen: *c.Screen,

    pub fn init(allocator: *std.mem.Allocator) !Manager {
        var manager: Manager = undefined;

        manager.allocator = allocator;

        manager.x_display = c.XOpenDisplay(null) orelse std.posix.exit(1);
        manager.x_screen = c.XDefaultScreenOfDisplay(@constCast(manager.x_display));
        manager.x_rootwindow = &c.XDefaultRootWindow(@constCast(manager.x_display));

        _ = c.XSetErrorHandler(Manager.handleError);

        var window_attributes: c.XSetWindowAttributes = undefined;
        window_attributes.event_mask = c.SubstructureRedirectMask | c.SubstructureNotifyMask;

        _ = c.XSelectInput(@constCast(manager.x_display), @constCast(manager.x_rootwindow).*, window_attributes.event_mask);

        try Logger.Log.info("ZWM_INIT", "Successfully Initialized the Window Manager", .{});

        return manager;
    }

    pub fn run(self: Manager) !void {
        while (true) {
            var event: c.XEvent = undefined;
            _ = c.XNextEvent(@constCast(self.x_display), &event);

            switch (event.type) {
                c.ButtonPress => {
                    try Logger.Log.info("ZWM_RUN", "Button Pressed", .{});
                },

                else => {},
            }
        }
    }

    fn handleError(_: ?*c.Display, event: [*c]c.XErrorEvent) callconv(.C) c_int {
        const evt: *c.XErrorEvent = @ptrCast(event);
        switch (evt.error_code) {
            c.BadMatch => {
                _ = Logger.Log.err("ZWM_RUN", "BadMatch", .{}) catch {
                    return undefined;
                };
                return 0;
            },
            c.BadWindow => {
                _ = Logger.Log.err("ZWM_RUN", "BadWindow", .{}) catch {
                    return undefined;
                };
                return 0;
            },
            c.BadDrawable => {
                _ = Logger.Log.err("ZWM_RUN", "BadDrawable", .{}) catch {
                    return undefined;
                };
                return 0;
            },
            else => {},
        }

        return 0;
    }

    /// Invalidates the contents of the display
    pub fn deinit(self: *const Manager) void {
        _ = c.XCloseDisplay(@constCast(self.x_display));
    }
};
