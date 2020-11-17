const std = @import("std");
const net = std.net;
const print = std.debug.print;
const datetime = @import("./zig-datetime/datetime.zig");
const timezones = @import("./zig-datetime/timezones.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};

    print("Configuring local address...\n", .{});
    const req_listen_addr = net.Address.parseIp6("::1", 8080) catch unreachable;

    var server = net.StreamServer.init(net.StreamServer.Options{});
    defer {
        print("Closing connection...\n", .{});
        print("Closing listening socket...\n", .{});
        server.deinit();
        print("Finished...\n", .{});
    }

    print("Listening...\n", .{});
    try server.listen(req_listen_addr);

    print("Waiting for connection...\n", .{});
    var client = try server.accept();

    print("Client is connected...\n", .{});
    print("{}\n", .{client.address});

    print("Reading request...\n", .{});
    var request: [1024]u8 = undefined;
    const bytes_recv = try client.file.read(&request);
    print("Received {} bytes.\n", .{bytes_recv});

    print("Sending response...\n", .{});
    const response = "HTTP/1.1 200 OK\r\nConnection: close\r\nContent-Type: text/plain\r\n\r\nLocal time is: ";
    var bytes_sent = try client.file.write(response);
    print("Sent {} of {} bytes.\n", .{ bytes_sent, response.len });

    var now = datetime.Datetime.now().shiftTimezone(&timezones.Europe.Rome);
    var now_str = try now.formatHttp(&gpa.allocator);
    defer gpa.allocator.free(now_str);
    bytes_sent = try client.file.write(now_str);
    print("Sent {} of {} bytes.\n", .{ bytes_sent, now_str.len });
}
