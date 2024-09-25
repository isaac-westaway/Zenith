///
/// Once you are done editing this file, run `zig build` to rebuild the project
///
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
pub const number_of_images: comptime_int = 39;

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
// TODO: Some more configs such as keybindings
