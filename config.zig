///
/// Once you are done editing this file, run `make all` to rebuild the project
///
const c = @cImport({
    @cInclude("X11/Xlib.h");
    @cInclude("X11/XF86keysym.h");
    @cInclude("X11/keysym.h");
    @cInclude("X11/XKBlib.h");
    @cInclude("X11/Xatom.h");
    @cInclude("X11/Xutil.h");
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
pub const image_directory: []const u8 = "/home/isaacwestaway/Documents/zig/zwm/image/orange/";
pub const image_file_name: []const u8 = "out";
pub const image_file_extension: []const u8 = "bmp";
/// Excluding zero, so for 0-22 images would be 22
pub const number_of_images: comptime_int = 249;

/// The absolute path to the background, leave blank if you do NOT want a background
/// Begins at "/"
pub const background_path: []const u8 = "/home/isaacwestaway/Documents/zig/zwm/image/spacex1.jpg";

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
pub const inital_number_of_workspaces: comptime_int = 5;

/// Set this to true if you would like to see a statusbar
/// Currently the statusbar is a work in progress, so it is best to keep this as false and only true for development purposes
pub const enable_statusbar: bool = false;

/// The border gap width to separate all windows, will be ignored on a fullscreen window
/// It is best to just trial and error what you like, also in future, there will be a way to dynamically change this value, increasing or decreasing
/// At the most extreme of cases, this integer should be less thaan 500, though you should never really use more than 20 pixels
pub const window_gap_width: comptime_int = 10;

///
/// Keybinds
///
/// You can list out the available super keys on your keyboard by running `xmodmap` in your terminal
/// A super key is a key that is run alongside another key, like ctrl + enter, in this example, ctrl is the super key, the super key for control is c.Control mask
/// The `mask` is just X11's way of saying "this must be fulfilled"
/// You should have intellisense for zig installed if you would like a list of keys, or you can read the source code
/// Open the terminal
pub const terminal_super: c.Mask = c.Mod4Mask;
pub const terminal_key: c.KeySym = c.XK_Return;

/// Close the window manager
pub const close_super: c.Mask = c.Mod4Mask;
pub const close_key: c.Mask = c.XK_Escape;

/// Cycle focus in the forward direction
pub const cycle_forward_super: c.Mask = c.Mod4Mask;
pub const cycle_forward_key: c.Mask = c.XK_Tab;

/// Cycle focus in the reverse direction
/// This is intentional, though might be changed later if people really want it changed
/// Essentially the exact same keybinds as with cycling forward, just with an extra super key
pub const cycle_backward_super_second: c.Mask = c.ShiftMask;

/// This is just for taking images of the window manager, using scrot
pub const scrot_super: c.Mask = c.Mod4Mask;
pub const scrot_key: c.Mask = c.XK_l;

/// Set the currently focused window to fullscreen
pub const fullscreen_super: c.Mask = c.Mod4Mask;
pub const fullscreen_key: c.Mask = c.XK_f;

/// Close the currently focused window, NOT the window manager
pub const close_window_super: c.Mask = c.Mod4Mask;
pub const close_window_key: c.Mask = c.XK_q;

/// Push the currently focused window forward a workspace
pub const push_forward_super: c.Mask = c.Mod4Mask;
pub const push_forward_key: c.Mask = c.XK_p;

/// Push the currently focused window back one workspace
pub const push_backward_super: c.Mask = c.Mod4Mask;
pub const push_backward_key: c.Mask = c.XK_o;

/// Cycle to the nnext workspace
pub const workspace_cycle_forward_super: c.Mask = c.Mod4Mask;
pub const workspace_cycle_forward_key: c.Mask = c.XK_d;

/// Cycle to the previous workspace
pub const workspace_cycle_backward_super: c.Mask = c.Mod4Mask;
pub const workspace_cycle_backward_key: c.Mask = c.XK_a;

/// Unfocus the current window by making the window slightly transparent
/// Kinda useless, for aesthetic purposes
pub const unfocus_super: c.Mask = c.Mod4Mask;
pub const unfocus_key: c.Mask = c.XK_grave;

/// Append a new workspace at the end of the workspace list
pub const worskpace_append_super: c.Mask = c.Mod4Mask;
pub const workspace_append_key: c.Mask = c.XK_equal;

/// Pop the last workspace in the list of workspaces, 1,2,3,4,5 -> 1,2,3,4
pub const workspace_pop_super: c.Mask = c.Mod4Mask;
pub const workspace_pop_key: c.Mask = c.XK_minus;

/// Swap the left (master) window with the top right
pub const swap_left_right_master_super: c.Mask = c.Mod4Mask;
pub const swap_left_right_mastker_key: c.Mask = c.XK_1;

/// Add the currently focused window as the master window in the unmodified layouot
pub const add_focused_master_super: c.Mask = c.Mod4Mask;
pub const add_focused_master_key: c.Mask = c.XK_2;

/// Add the currently focused window as a "slave" window in the unmodified layout
pub const add_focused_slave_super: c.Mask = c.Mod4Mask;
pub const add_focused_slave_key: c.Mask = c.XK_3;

/// Add the current
/// Move the window by pressing and dragging the left mouse button
/// The compile time integer must correspond to the integer in mouse_motion_left
/// Only change this if you know that X11 supports your key, I cannot add support on my own, it is up to Xorg (or wayland once Zenith supports it)
/// To handle the necessary mouse drivers
pub const mouse_button_left: comptime_int = 1;
pub const mouse_motion_left: c.Mask = c.Button1MotionMask;

/// Resize by clicking and dragging
pub const mouse_button_right: comptime_int = 3;
pub const mouse_motion_right: c.Mask = c.Button3MotionMask;
