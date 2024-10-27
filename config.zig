///
/// Once you are done editing this file, run `make all` to rebuild the project
///
pub const c = @cImport({
    @cInclude("xcb/xcb.h");
    @cInclude("xcb/xproto.h");
    @cInclude("xcb/xcb_cursor.h");

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

/// The command to be executed when running picom, if you would like to run picom, if not leave it as: ""
/// A comma separated slice of picom command line arguments, add more as you please
pub const picom_command = &[_][]const u8{ "picom", "--config", "/home/isaacwestaway/picom.conf" };

/// Animated Background
/// List of images to use for the animated background
/// To automatically generate these images, use imagemagick and run `magick`
/// the images must be in the naming format
/// This example has the images using the filename out-{n}.bmp
pub const animated_background: bool = true;
/// Example: /home/isaacwestaway/Documents/zig/zwm/image/orange/
pub const image_directory: []const u8 = "";
/// Example: out
pub const image_file_name: []const u8 = "";
/// Example: bmp
pub const image_file_extension: []const u8 = "";
/// Excluding zero, so for 0-22 images would be 22
/// Example: 249
pub const number_of_images: comptime_int = 0;

/// The absolute path to the background, leave blank if you do NOT want a background
/// Begins at "/"
/// Example: /home/isaacwestaway/Documents/zig/zwm/image/spacex1.jpg
pub const background_path: []const u8 = "";

/// The window that is currently focused
pub const hard_focused: comptime_int = 0xef9f1c;

/// The window that is being hovered over
/// Set this to zero, or the unfocused or the hard focused if you do not want three-color behaviour
pub const soft_focused: comptime_int = 0xf5c577;

/// The window that is unfocused
pub const unfocused: comptime_int = 0x483008;

/// The width of the border
/// Set this to zero if you do not want a border at all
/// Setting a window to fullscreen will set the border width to zero, and this is intended because why do you want a border in fullscreen?
pub const border_width: comptime_int = 2;

/// The terminal command, for example "kitty" or "alacritty" or "xterm"
pub const terminal_cmd: []const u8 = "kitty";

/// The number of workspaces you want to start out with, must be at least one
/// You are also able to dynamically create more workspaces using a keybind
pub const initial_number_of_workspaces: comptime_int = 5;

/// Set this to true if you would like to see a statusbar
/// Currently the statusbar is a work in progress, so it is best to keep this as false and only true for development purposes
pub const enable_statusbar: bool = false;

/// The border gap width to separate all windows, will be ignored on a fullscreen window
/// It is best to just trial and error what you like, also in future, there will be a way to dynamically change this value, increasing or decreasing
/// At the most extreme of cases, this integer should be less thaan 500, though you should never really use more than 20 pixels
pub const window_gap_width: comptime_int = 10;

pub const mouse_button_left: comptime_int = 1;
pub const mouse_motion_left: c.Mask = c.Button1MotionMask;

/// Resize by clicking and dragging
pub const mouse_button_right: comptime_int = 3;
pub const mouse_motion_right: c.Mask = c.Button3MotionMask;

///
/// Keybinds
///
pub const Key = struct { key_mask: c.xcb_mod_mask_t, key_sym: c.xcb_keysym_t };
pub const key_binds: []const Key = &.{
    // Modify these keys
    // Exit out of the window manager
    Key{
        .key_mask = c.Mod4Mask,
        .key_sym = c.XK_Return,
    },

    // Close the window wmanager
    Key{
        .key_mask = c.Mod4Mask,
        .key_sym = c.XK_Escape,
    },

    // Cycle focus in the forward direction
    Key{ .key_mask = c.Mod4Mask, .key_sym = c.XK_Tab },

    // Cycle focus in the reverse direction
    // This is intentional, though might be changed later if people really want it changed
    // Essentially the exact same keybinds as with cycling forward, just with an extra super key
    Key{ .key_mask = c.ShiftMask, .key_sym = c.XK_Tab },

    // This is just for taking images of the window manager, using scrot
    Key{
        .key_mask = c.Mod4Mask,
        .key_sym = c.XK_1,
    },

    // Make the currently focused window fullscreen
    Key{
        .key_mask = c.Mod4Mask,
        .key_sym = c.XK_f,
    },

    // Close the currently focused window
    Key{
        .key_mask = c.Mod4Mask,
        .key_sym = c.XK_q,
    },

    // Push the focused window forward a workspace
    Key{
        .key_mask = c.Mod4Mask,
        .key_sym = c.XK_p,
    },

    // Push the focused window back one workspace
    Key{
        .key_mask = c.Mod4Mask,
        .key_sym = c.XK_o,
    },

    // Cycle to the next workspace
    Key{
        .key_mask = c.Mod4Mask,
        .key_sym = c.XK_d,
    },

    // Cycle to the previous workspace
    Key{
        .key_mask = c.Mod4Mask,
        .key_sym = c.XK_a,
    },

    // Unfocus the current window
    Key{
        .key_mask = c.Mod4Mask,
        .key_sym = c.XK_grave,
    },

    // Append a new workspace
    Key{
        .key_mask = c.Mod4Mask,
        .key_sym = c.XK_equal,
    },

    // Pop the last workspace
    Key{
        .key_mask = c.Mod4Mask,
        .key_sym = c.XK_minus,
    },

    // Swap the master window with the top right
    Key{
        .key_mask = c.Mod4Mask,
        .key_sym = c.XK_1,
    },

    // Add the currently focused window as the master
    Key{
        .key_mask = c.Mod4Mask,
        .key_sym = c.XK_2,
    },

    // Add the currently focused window as a slave window
    Key{
        .key_mask = c.Mod4Mask,
        .key_sym = c.XK_3,
    },
};
