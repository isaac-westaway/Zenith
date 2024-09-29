const std = @import("std");

const c = @import("x11.zig").c;

pub var zenith_main_factor: c.Atom = undefined;
pub var utf8_string: c.Atom = undefined;
pub var wm_protocols: c.Atom = undefined;
pub var wm_delete: c.Atom = undefined;
pub var wm_take_focus: c.Atom = undefined;
pub var wm_state: c.Atom = undefined;
pub var wm_change_state: c.Atom = undefined;
pub var net_supported: c.Atom = undefined;
pub var net_wm_strut: c.Atom = undefined;
pub var net_wm_strut_partial: c.Atom = undefined;
pub var net_wm_window_type: c.Atom = undefined;
pub var net_wm_window_type_dock: c.Atom = undefined;
pub var net_wm_window_type_dialog: c.Atom = undefined;
pub var net_wm_state: c.Atom = undefined;
pub var net_wm_state_fullscreen: c.Atom = undefined;
pub var net_wm_desktop: c.Atom = undefined;
pub var net_number_of_desktops: c.Atom = undefined;
pub var net_current_desktop: c.Atom = undefined;
pub var net_active_window: c.Atom = undefined;
pub var net_client_list: c.Atom = undefined;
pub var net_supporting_wm_check: c.Atom = undefined;
pub var net_wm_window_opacity: c.Atom = undefined;

pub const Atoms = struct {
    allocator: *std.mem.Allocator,

    x_display: *const c.Display,
    x_rootwindow: *const c.Window,

    pub fn init(allocator: *std.mem.Allocator, display: *const c.Display, window: *const c.Window) !Atoms {
        const atoms: Atoms = Atoms{
            .allocator = allocator,

            .x_display = display,
            .x_rootwindow = window,
        };

        zenith_main_factor = c.XInternAtom(@constCast(display), "ZWM_MAIN_FACTOR", 0);
        utf8_string = c.XInternAtom(@constCast(display), "UTF8_STRING", 0);
        wm_protocols = c.XInternAtom(@constCast(display), "WM_PROTOCOLS", 0);
        wm_delete = c.XInternAtom(@constCast(display), "WM_DELETE_WINDOW", 0);
        wm_take_focus = c.XInternAtom(@constCast(display), "WM_TAKE_FOCUS", 0);
        wm_state = c.XInternAtom(@constCast(display), "WM_STATE", 0);
        wm_change_state = c.XInternAtom(@constCast(display), "WM_CHANGE_STATE", 0);
        net_supported = c.XInternAtom(@constCast(display), "_NET_SUPPORTED", 0);
        net_wm_strut = c.XInternAtom(@constCast(display), "_NET_WM_STRUT", 0);
        net_wm_strut_partial = c.XInternAtom(@constCast(display), "_NET_WM_STRUT_PARTIAL", 0);
        net_wm_window_type = c.XInternAtom(@constCast(display), "_NET_WM_WINDOW_TYPE", 0);
        net_wm_window_type_dock = c.XInternAtom(@constCast(display), "_NET_WM_WINDOW_TYPE_DOCK", 0);
        net_wm_window_type_dialog = c.XInternAtom(@constCast(display), "_NET_WM_WINDOW_TYPE_DIALOG", 0);
        net_wm_state = c.XInternAtom(@constCast(display), "_NET_WM_STATE", 0);
        net_wm_state_fullscreen = c.XInternAtom(@constCast(display), "_NET_WM_STATE_FULLSCREEN", 0);
        net_wm_desktop = c.XInternAtom(@constCast(display), "_NET_WM_DESKTOP", 0);
        net_number_of_desktops = c.XInternAtom(@constCast(display), "_NET_NUMBER_OF_DESKTOPS", 0);
        net_current_desktop = c.XInternAtom(@constCast(display), "_NET_CURRENT_DESKTOP", 0);
        net_active_window = c.XInternAtom(@constCast(display), "_NET_ACTIVE_WINDOW", 0);
        net_client_list = c.XInternAtom(@constCast(display), "_NET_CLIENT_LIST", 0);
        net_supporting_wm_check = c.XInternAtom(@constCast(display), "_NET_SUPPORTING_WM_CHECK", 0);
        net_wm_window_opacity = c.XInternAtom(@constCast(display), "_NET_WM_WINDOW_OPACITY", 0);

        const supported_net_atoms = [_]c.Atom{ net_supported, net_wm_strut, net_wm_strut_partial, net_wm_window_type, net_wm_window_type_dock, net_wm_window_type_dialog, net_wm_state, net_wm_state_fullscreen, net_wm_desktop, net_number_of_desktops, net_current_desktop, net_active_window, net_client_list, net_supporting_wm_check, net_wm_window_opacity };
        _ = c.XChangeProperty(
            @constCast(atoms.x_display),
            c.XDefaultRootWindow(@constCast(atoms.x_display)),
            net_supported,
            c.XA_ATOM,
            32,
            c.PropModeReplace,
            @ptrCast(&supported_net_atoms),
            supported_net_atoms.len,
        );

        return atoms;
    } // init
};
