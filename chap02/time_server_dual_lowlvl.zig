const std = @import("std");
const mem = std.mem;
const print = std.debug.print;
const net = std.net;
const os = std.os;
const datetime = @import("./zig-datetime/datetime.zig");
const timezones = @import("./zig-datetime/timezones.zig");

const IPV6_V6ONLY = 27;

pub fn main() !void {
    print("Configuring local address...\n", .{});
    const localhost = try net.Address.parseIp6("::1", 8080);

    print("Creating socket...\n", .{});
    const sock_listen = try os.socket(os.AF_INET6, os.SOCK_STREAM, os.IPPROTO_TCP);
    errdefer os.close(sock_listen);

    // TODO: for now this fails. Sill not available in zig?
    try os.setsockopt(sock_listen, os.IPPROTO_IPV6, IPV6_V6ONLY, &mem.toBytes(@as(c_int, 0)));

    print("Binding socket to local address...\n", .{});
    var sock_len = localhost.getOsSockLen();
    try os.bind(sock_listen, &localhost.any, sock_len);

    print("Listening...\n", .{});
    try os.listen(sock_listen, 10);

    print("Waiting for connection...\n", .{});
    var accepted_addr: net.Address = undefined;
    var addr_len: os.socklen_t = @sizeOf(net.Address);
    var sock_client = try os.accept(sock_listen, &accepted_addr.any, &addr_len, os.SOCK_CLOEXEC);

    print("Client is connected...\n", .{});

    print("Reading request...\n", .{});
    var request: [1024]u8 = undefined;
    const bytes_recv = os.recvfrom(sock_client, request[0..], 0, &accepted_addr.any, &addr_len);
    print("Received {} bytes.\n", .{bytes_recv});

    print("Sending response...\n", .{});
    const response = "HTTP/1.1 200 OK\r\nConnection: close\r\nContent-Type: text/plain\r\n\r\nLocal time is: ";
    var bytes_sent = os.send(sock_client, response, 0);
    print("Sent {} of {} bytes.\n", .{ bytes_sent, response.len });

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    var now = datetime.Datetime.now().shiftTimezone(&timezones.Europe.Rome);
    var now_str = try now.formatHttp(&gpa.allocator);
    defer gpa.allocator.free(now_str);
    bytes_sent = os.send(sock_client, now_str, 0);
    print("Sent {} of {} bytes.\n", .{ bytes_sent, now_str.len });

    print("Closing connection...\n", .{});
    os.close(sock_client);

    print("Closing listening socket...\n", .{});
    os.close(sock_listen);

    print("Finished...\n", .{});
}
