const std = @import("std");
const os = std.os;
const print = std.debug.print;
const net = std.net;
const fmt = std.fmt;
const mem = std.mem;
const io = std.io;

pub fn main() !void {
    var allocator = std.heap.page_allocator;
    var args = os.argv;
    if (args.len < 3) {
        print("usage: tcp_client hostname port\n", .{});
        os.exit(1);
    }

    print("Configuring remote address...\n", .{});
    var url = mem.span(args[1]);
    var port = mem.span(args[2]);

    var port_no = try fmt.parseInt(u16, port, 0);
    const addrs_list = try std.net.getAddressList(allocator, url, port_no);
    defer addrs_list.deinit();

    var peer_address: net.Address = undefined;

    // take the IPv4 address by checking its size
    outer: for (addrs_list.addrs) |addr| {
        const bytes = @ptrCast(*const [4]u8, &addr.in.sa.addr);
        if (bytes.len > 0) {
            peer_address = addr;
            break :outer;
        }
    }
    print("Remote address is {}\n", .{peer_address.in});

    print("Creating socket...\n", .{});
    const socket_peer = try os.socket(os.AF_INET, os.SOCK_STREAM, os.IPPROTO_TCP);
    defer {
        print("Closing socket...\n", .{});
        os.close(socket_peer);
    }

    print("Connecting...\n", .{});
    try os.connect(socket_peer, &peer_address.any, peer_address.getOsSockLen());

    print("Connected...\n", .{});
    print("To send data, enter text followed by an enter.\n", .{});

    var pfd = [2]os.pollfd{
        os.pollfd{
            .fd = 0, // stdin
            .events = os.POLLIN,
            .revents = undefined,
        },
        os.pollfd{
            .fd = socket_peer,
            .events = os.POLLIN,
            .revents = undefined,
        },
    };

    while (true) {
        const nevents = os.poll(&pfd, 100) catch 0;
        if (nevents == 0) continue;

        if ((pfd[0].revents & os.POLLIN) == os.POLLIN) {
            var read: [4096]u8 = undefined;
            const stdin = io.getStdIn();

            const raw_input = stdin.reader().readUntilDelimiterOrEof(read[0..], '\n') catch |err| {
                print("error: cannot read from STDIN: {}\n", .{err});
                return;
            } orelse return;
            const input = try fmt.bufPrint(read[0..], "{s}\n", .{raw_input});
            print("Sending: {s}\n", .{raw_input});
            var bytes_sent = os.send(socket_peer, input, 0);
            print("Sent {} bytes.\n", .{bytes_sent});
        }

        if ((pfd[1].revents & os.POLLIN) == os.POLLIN) {
            var read: [4096]u8 = undefined;
            const bytes_received = try os.recv(socket_peer, read[0..], 0);
            if (bytes_received < 1) {
                print("Connection closed by peer.\n", .{});
                break;
            }
            print("Received ({} bytes): {s}", .{ bytes_received, read[0..bytes_received] });
        }
    }

    print("Finished.\n", .{});
    return;
}
