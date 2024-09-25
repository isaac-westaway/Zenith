const std = @import("std");
const builtin = @import("builtin");
const root = @import("root");

const c = @import("x11.zig").c;

const Layout = @import("Layout.zig").Layout;
const Input = @import("Input.zig").Input;

pub const Manager = struct {
    allocator: *std.mem.Allocator,

    x_display: *const c.Display,
    x_screen: *c.Screen,
    x_rootwindow: c.Window,

    layout: Layout,
    input: Input,

    pub fn init(allocator: *std.mem.Allocator) !Manager {
        var manager: Manager = undefined;

        manager.allocator = allocator;

        manager.x_display = c.XOpenDisplay(null) orelse std.posix.exit(1);
        manager.x_screen = c.XDefaultScreenOfDisplay(@constCast(manager.x_display));
        manager.x_rootwindow = c.XDefaultRootWindow(@constCast(manager.x_display));

        manager.layout = try Layout.init(manager.allocator, manager.x_display, manager.x_rootwindow);
        manager.input = try Input.init(manager.allocator, manager.x_display, manager.x_rootwindow);

        _ = c.XSetErrorHandler(Manager.handleError);

        var window_attributes: c.XSetWindowAttributes = undefined;
        window_attributes.event_mask = c.SubstructureRedirectMask | c.SubstructureNotifyMask;

        _ = c.XSelectInput(@constCast(manager.x_display), manager.x_rootwindow, window_attributes.event_mask);

        // try Logger.Log.info("ZWM_INIT", "Successfully Initialized the Window Manager", .{});

        _ = c.XSync(@constCast(manager.x_display), 0);

        return manager;
    }

    pub fn run(self: *Manager) !void {
        // try Logger.Log.info("ZWM_RUN", "Running the window manager", .{});
        while (true) {
            var event: c.XEvent = undefined;
            _ = c.XNextEvent(@constCast(self.x_display), &event);

            switch (event.type) {
                c.KeyPress => {
                    try self.layout.resolveKeyInput(&event.xkey);
                },

                c.ButtonPress => {
                    try self.layout.handleButtonPress(@constCast(&event.xbutton));
                },

                c.PointerMotionMask => {
                    // try Logger.Log.info("ZWM_RUN", "Pointer Motion Event: {any}", .{event.xmotion});
                },

                c.MotionNotify => {
                    try self.layout.handleMotionNotify(&event.xmotion);
                },

                c.CreateNotify => {
                    try self.layout.handleCreateNotify(&event.xcreatewindow);
                },

                c.DestroyNotify => {
                    try self.layout.handleDestroyNotify(&event.xdestroywindow);
                },

                c.MapRequest => {
                    try self.layout.handleMapRequest(&event.xmaprequest);
                },

                c.EnterNotify => {
                    try self.layout.handleEnterNotify(&event.xcrossing);
                },

                c.LeaveNotify => {
                    try self.layout.handleLeaveNotify(&event.xcrossing);
                },

                c.FocusIn => {
                    // try Logger.Log.info("ZWM_RUN", "Focus In Event", .{});
                },

                else => {},
            }
        }
    }

    fn handleError(_: ?*c.Display, event: [*c]c.XErrorEvent) callconv(.C) c_int {
        const evt: *c.XErrorEvent = @ptrCast(event);
        switch (evt.error_code) {
            c.BadMatch => {
                // _ = Logger.Log.err("ZWM_RUN", "BadMatch", .{}) catch {
                //     return undefined;
                // };
                return 0;
            },
            c.BadWindow => {
                // _ = Logger.Log.err("ZWM_RUN", "BadWindow: {any}", .{event.*}) catch {
                //     return undefined;
                // };
                return 0;
            },
            c.BadDrawable => {
                // _ = Logger.Log.err("ZWM_RUN", "BadDrawable", .{}) catch {
                //     return undefined;
                // };
                return 0;
            },
            else => {
                // _ = Logger.Log.err("ZWM_RUN", "Unhandled Error", .{}) catch {
                //     return undefined;
                // };
            },
        }

        return 0;
    }

    /// Invalidates the contents of the display
    pub fn deinit(self: *const Manager) void {
        _ = c.XCloseDisplay(@constCast(self.x_display));
    }
};
