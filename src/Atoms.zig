const std = @import("std");

const Config = @import("config");

const c = @import("x11.zig").c;

const WMAtoms = enum(u8) { wm_protocols = 0, wm_delete, wm_state, wm_take_focus, wm_count };
const EWMHAtoms = enum(u8) { ewmh_supported = 0, ewmh_name, ewmh_state, ewmh_state_hidden, ewmh_check, ewmh_fullscreen, ewmh_active_window, ewmh_window_type, ewmh_window_type_dialog, ewmh_client_list, ewmh_current_desktop, ewmh_number_of_desktops, ewmh_desktop_names, ewmh_count };

const Atoms = struct {
    wm_atoms: [@intFromEnum(WMAtoms.wm_count)]c.xcb_atom_t,
    ewmh_atoms: [@intFromEnum(EWMHAtoms.ewmh_count)]c.xcb_atom_t,
};

pub var atoms: Atoms = undefined;

/// A lot of this code is copied from ragnar since I don't really understand some of the atom concepts
pub fn setupAtoms(xcb_connection: *c.xcb_connection_t, xcb_root_window: c.xcb_window_t) void {
    atoms = Atoms{
        .wm_atoms = undefined,
        .ewmh_atoms = undefined,
    };

    atoms.wm_atoms[@intFromEnum(WMAtoms.wm_protocols)] = getAtom("WM_PROTOCOLS", xcb_connection);
    atoms.wm_atoms[@intFromEnum(WMAtoms.wm_delete)] = getAtom("WM_DELETE_WINDOW", xcb_connection);
    atoms.wm_atoms[@intFromEnum(WMAtoms.wm_state)] = getAtom("WM_STATE", xcb_connection);
    atoms.wm_atoms[@intFromEnum(WMAtoms.wm_take_focus)] = getAtom("WM_TAKE_FOCUS", xcb_connection);

    atoms.ewmh_atoms[@intFromEnum(EWMHAtoms.ewmh_supported)] = getAtom("_NET_SUPPORTED", xcb_connection);
    atoms.ewmh_atoms[@intFromEnum(EWMHAtoms.ewmh_name)] = getAtom("_NET_WM_NAME", xcb_connection);
    atoms.ewmh_atoms[@intFromEnum(EWMHAtoms.ewmh_state)] = getAtom("_NET_WM_STATE", xcb_connection);
    atoms.ewmh_atoms[@intFromEnum(EWMHAtoms.ewmh_state_hidden)] = getAtom("_NET_STATE_HIDDEN", xcb_connection);
    atoms.ewmh_atoms[@intFromEnum(EWMHAtoms.ewmh_check)] = getAtom("_NET_SUPPORTING_WM_CHECK", xcb_connection);
    atoms.ewmh_atoms[@intFromEnum(EWMHAtoms.ewmh_fullscreen)] = getAtom("_NET_WM_STATE_FULLSCREEN", xcb_connection);
    atoms.ewmh_atoms[@intFromEnum(EWMHAtoms.ewmh_active_window)] = getAtom("_NET_ACTIVE_WINDOW", xcb_connection);
    atoms.ewmh_atoms[@intFromEnum(EWMHAtoms.ewmh_window_type)] = getAtom("_NET_WM_WINDOW_TYPE", xcb_connection);
    atoms.ewmh_atoms[@intFromEnum(EWMHAtoms.ewmh_window_type_dialog)] = getAtom("_NET_WM_WINDOW_TYPE_DIALOG", xcb_connection);
    atoms.ewmh_atoms[@intFromEnum(EWMHAtoms.ewmh_client_list)] = getAtom("_NET_CLIENT_LIST", xcb_connection);
    atoms.ewmh_atoms[@intFromEnum(EWMHAtoms.ewmh_current_desktop)] = getAtom("_NET_CURRENT_DESKTOP", xcb_connection);
    atoms.ewmh_atoms[@intFromEnum(EWMHAtoms.ewmh_number_of_desktops)] = getAtom("_NET_NUMBER_OF_DESKTOPS", xcb_connection);
    atoms.ewmh_atoms[@intFromEnum(EWMHAtoms.ewmh_desktop_names)] = getAtom("_NET_DESKTOP_NAMES", xcb_connection);

    const utf_8_str: c.xcb_atom_t = getAtom("UTF8_STRING", xcb_connection);

    const wm_check_win: c.xcb_atom_t = c.xcb_generate_id(xcb_connection);

    _ = c.xcb_create_window(xcb_connection, c.XCB_COPY_FROM_PARENT, wm_check_win, xcb_root_window, 0, 0, 1, 1, 0, c.XCB_WINDOW_CLASS_INPUT_OUTPUT, c.XCB_COPY_FROM_PARENT, 0, null);

    // set _NET_WM_CHECK on the dummy window
    _ = c.xcb_change_property(xcb_connection, c.XCB_PROP_MODE_REPLACE, wm_check_win, atoms.ewmh_atoms[@intFromEnum(EWMHAtoms.ewmh_check)], c.XCB_ATOM_WINDOW, 32, 1, &wm_check_win);

    // set the name of the window manager, _NET_WM_NAME
    _ = c.xcb_change_property(xcb_connection, c.XCB_PROP_MODE_REPLACE, wm_check_win, atoms.ewmh_atoms[@intFromEnum(EWMHAtoms.ewmh_name)], utf_8_str, 8, 7, "Zenith");

    // set the _NET_WM_CHECK on root window
    _ = c.xcb_change_property(xcb_connection, c.XCB_PROP_MODE_REPLACE, xcb_root_window, atoms.ewmh_atoms[@intFromEnum(EWMHAtoms.ewmh_check)], c.XCB_ATOM_WINDOW, 32, 1, &wm_check_win);

    // set _NET_CURRENT_DESKTOP on root window
    const initial_current_desktop: c_int = 0;
    _ = c.xcb_change_property(xcb_connection, c.XCB_PROP_MODE_REPLACE, xcb_root_window, atoms.ewmh_atoms[@intFromEnum(EWMHAtoms.ewmh_current_desktop)], c.XCB_ATOM_CARDINAL, 32, 1, &initial_current_desktop);

    // set _NET_SUPPORTED
    _ = c.xcb_change_property(xcb_connection, c.XCB_PROP_MODE_REPLACE, xcb_root_window, atoms.ewmh_atoms[@intFromEnum(EWMHAtoms.ewmh_supported)], c.XCB_ATOM_ATOM, 32, @intFromEnum(EWMHAtoms.ewmh_count), @as(*const anyopaque, @ptrCast(&atoms.ewmh_atoms)));

    // delete the current list of windows
    _ = c.xcb_delete_property(xcb_connection, xcb_root_window, atoms.ewmh_atoms[@intFromEnum(EWMHAtoms.ewmh_client_list)]);

    // TODO: multi monitor atoms

    const initial_number_of_workspaces: c_int = Config.initial_number_of_workspaces;
    _ = c.xcb_change_property(xcb_connection, c.XCB_PROP_MODE_REPLACE, xcb_root_window, atoms.ewmh_atoms[@intFromEnum(EWMHAtoms.ewmh_number_of_desktops)], c.XCB_ATOM_CARDINAL, 32, 1, &initial_number_of_workspaces);

    _ = c.xcb_flush(xcb_connection);
} // setupAtoms

fn getAtom(atom_string: []const u8, xcb_connection: *c.xcb_connection_t) c.xcb_atom_t {
    const cookie: c.xcb_intern_atom_cookie_t = c.xcb_intern_atom(xcb_connection, 0, @intCast(atom_string.len), @ptrCast(&atom_string));
    const reply: ?*c.xcb_intern_atom_reply_t = c.xcb_intern_atom_reply(xcb_connection, cookie, null);
    defer if (reply) |r| c.free(r);

    if (reply) |r| return r.atom;

    return c.XCB_ATOM_NONE;
} // getAtom
