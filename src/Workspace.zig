/// Per monitor object of available desktops
/// One workspace per monitor, 6 (or whatever the config has defined) desktops per workspace
/// therefore a linked lists of workspaces should be managed top level
/// once monitor support is added, Monitor.zig should manage the linked list of workspaces
const std = @import("std");

const c = @import("x11.zig").c;

const Config = @import("config");

const Client = @import("Client.zig");

pub const TypeWorkspace = struct {
    client_list: std.DoublyLinkedList(Client.TypeClient), // map the window, and append to the linked list of clients, but do NOT map windows here, call shouldTile(), create a list of clients that should be tiled

};

// The Client.zig should provide methods to modify the workspace, such as making the client floating, or fullscreening a client

pub fn createWorkspace(allocator: *std.mem.Allocator) !*std.DoublyLinkedList(TypeWorkspace).Node {
    const workspace: TypeWorkspace = TypeWorkspace{ .client_list = std.DoublyLinkedList(Client.TypeClient){} };

    var workspace_node: *std.DoublyLinkedList(TypeWorkspace).Node = try allocator.create(std.DoublyLinkedList(TypeWorkspace).Node);
    workspace_node.data = workspace; // map the window, and append to the linked list (or adjacency lsit) of clients, but do NOT map windows here, call shouldTile(), create a list of clients that should be tiled, and tile them

    return workspace_node;
} // createWorkspace

pub fn clientFromWindow(window: c.Window, client_list_head: ?*std.DoublyLinkedList(Client.TypeClient).Node) ?*std.DoublyLinkedList(Client.TypeClient).Node {
    var current_node: ?*std.DoublyLinkedList(Client.TypeClient).Node = client_list_head;

    while (current_node != null) : (current_node = current_node.next) {
        if (current_node.?.data.window == window) {
            return current_node;
        }
    }

    return null;
} // clientFromWindow

pub fn shouldClientTile(client: Client.TypeClient) bool {
    _ = client;
} // shouldClientTile

// The map request should take in a std.DoublyLinkedList(TypeWorkspace).Node.data and perform what addWorkspace does on addClient
// also pass in an the head of the currently focused workspace
pub fn handleMapRequest(allocator: *std.mem.Allocator, connection: *c.xcb_connection_t, event: *c.xcb_generic_event_t, client_list_head: *std.DoublyLinkedList(Client.TypeClient).Node) void {
    const e: *c.xcb_map_request_event_t = @ptrCast(event);

    const cookie: c.xcb_get_window_attributes_cookie_t = c.xcb_get_window_attributes(connection, e.window);
    const reply: ?*c.xcb_get_window_attributes_reply_t = c.xcb_get_window_attributes_reply(connection, cookie, null);

    if (reply == null) return;

    if (reply) |r| {
        if (r.override_redirect == 1) {
            allocator.destroy(reply);
        }
    }

    const current_client = clientFromWindow(e.window, client_list_head);

    if (current_client != null) {
        return;
    }

    const client: *std.DoublyLinkedList(Client.TypeClient).Node = allocator.create(std.DoublyLinkedList(Client.TypeClient).Node) catch {
        std.posix.exit(1);
    }; // memory allocation failure

    _ = client;

    // check if the client we are creating from the event is already amanaged, by calling clientfromwin
    // TODO: handle initial window mapping
    // could handle floating window creating by inverting logic?
    // step 1: do NOT tile windows when mapped, check the keybord press, ctrl + shift + enter (for floating windows), and call tileWindows() manually

    // manage clients/windows
    // map the window, and append to the linked list (or adjacency) of clients, but do NOT map windows here, call shouldTile(), create a list of clients that should be tiled, and tile them
} // handleMapRequest
