/// Per monitor object of available desktops
/// One workspace per monitor, 6 (or whatever the config has defined) desktops per workspace
const std = @import("std");

const c = @import("x11.zig").c;

const Config = @import("config");

const Client = @import("Client.zig");

pub const TypeWorkspace = struct {
    // desktops: std.ArrayList(Desktop),
    client_list: std.DoublyLinkedList(Client.TypeClient),
};
// mapEngine()
// config: map as breadth first
// or map as depth firsta

// The Client.zig should provide methods to modify the workspace, such as making the client floating, or fullscreening a client

// handle ewmh
// should the arguments of addWorkspace be the first in the list or the list itself
pub fn addWorkspace(allocator: *std.mem.Allocator, first: std.DoublyLinkedList(TypeWorkspace).Node) !*std.DoublyLinkedList(TypeWorkspace).Node {
    const workspace: TypeWorkspace = TypeWorkspace{ .client_list = std.DoublyLinkedList(Client.TypeClient){} };

    var start = first;
    while (start) : (start = start.next) {
        // iterate through for ewmh
    }

    // Might want to add error handling
    var workspace_node: *std.DoublyLinkedList(TypeWorkspace).Node = try allocator.create(std.DoublyLinkedList(TypeWorkspace).Node);
    workspace_node.data = workspace;

    return workspace_node;
} // setupWorkspace

// The map request should take in a std.DoublyLinkedList(TypeWorkspace).Node.data and perform what addWorkspace does on addClient
pub fn handleMapRequest(allocator: *std.mem.Allocator, connection: *c.xcb_connection_t, event: *c.xcb_generic_event_t) void {
    const e: *c.xcb_map_request_event_t = @ptrCast(event);

    const cookie: c.xcb_void_cookie_t = c.xcb_map_window(connection, e.window);

    _ = cookie;
    _ = allocator;
}
