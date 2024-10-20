const c = @import("x11.zig").c;

pub const ClientTags = enum(u8) {
    fullscreen = 1 << 0, // 00000001
    modified = 1 << 1, // 00000010
    urgent = 1 << 2, // 00000100,
    never_take_focus = 1 << 3, // 00001000
    old_state = 1 << 4, // 00010000
};

pub const Client = struct {
    window: c.Window,

    // Any potential features of the manageed client
    tags: u8,

    /// The window configuration before fullscreen
    f_x: i32,
    f_y: i32,
    f_w: u32,
    f_h: u32,

    /// The current window configuration
    w_x: i32,
    w_y: i32,
    w_w: u32,
    w_h: u32,

    // monitor: Monitor // have not implemented multi monitor suport yet

    /// Add a tag from the enumeration
    pub fn addTag(self: *Client, tag: ClientTags) void {
        self.tags |= @as(u8, tag);
    }

    /// Remove a tag
    pub fn removeTag(self: *Client, tag: ClientTags) void {
        self.tags &= ~@as(u8, tag);
    }

    /// Check if the client has the tag
    pub fn checkTag(self: *Client, tag: ClientTags) bool {
        return (self.tags & @as(u8, tag)) != 0;
    }
};
