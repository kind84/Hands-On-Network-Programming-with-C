const std = @import("std");
const print = std.debug.print;
const net = std.net;
const os = std.os;
const heap = std.heap;

pub fn main() !void {
    print("Configuring local address...\n", .{});
    const localhost = try net.Address.parseIp4("127.0.0.1", 8080);

    print("Creating socket...\n", .{});
    const sock_listen = try os.socket(os.AF_INET, os.SOCK_STREAM, os.IPPROTO_TCP);

    print("Binding socket to local address...\n", .{});
    var sock_len = localhost.getOsSockLen();
    try os.bind(sock_listen, &localhost.any, sock_len);

    print("Listening...\n", .{});
    try os.listen(sock_listen, 10);

    var gpa = heap.GeneralPurposeAllocator(.{}){};
    defer {
        _ = gpa.deinit();
    }

    var pfds = try gpa.allocator.alloc(os.pollfd, 200);
    defer gpa.allocator.free(pfds);

    pfds[0].fd = sock_listen;
    pfds[0].events = os.POLLIN;

    var nfds: u8 = 1;
    const timeout = 3 * 60 * 1000;

    print("Waiting for connections...\n", .{});

    while (true) {
        _ = os.poll(pfds, timeout) catch 0;

        var current_size = nfds;
        var i: u8 = 0;
        while (i < current_size) : (i += 1) {
            if (pfds[i].revents == 0) continue;

            if ((pfds[i].revents & os.POLLIN) == os.POLLIN) {
                if (pfds[i].fd == sock_listen) {
                    // new incoming connection
                    var accepted_addr: net.Address = undefined;
                    var addr_len: os.socklen_t = @sizeOf(net.Address);
                    var sock_client = try os.accept(sock_listen, &accepted_addr.any, &addr_len, os.SOCK_CLOEXEC);

                    pfds[nfds].fd = sock_client;
                    pfds[nfds].events = os.POLLIN;
                    nfds += 1;

                    print("New connection from {}\n", .{accepted_addr});
                } else {
                    var read: [4096]u8 = undefined;
                    const bytes_received = try os.recv(pfds[i].fd, read[0..], 0);
                    if (bytes_received < 1) {
                        os.close(pfds[i].fd);
                        pfds[i].fd = -1;
                        continue;
                    }

                    var j: u8 = 0;
                    while (j < nfds) : (j += 1) {
                        if (j != i and j != 0) {
                            _ = try os.send(pfds[j].fd, read[0..bytes_received], 0);
                        }
                    }
                }
            }
        }
    }

    print("Closing sockets...\n", .{});
    var i: u8 = 0;
    while (i < nfds) : (i += 1) {
        if (pfds[i].fd >= 0)
            os.close(pfds[i].fd);
    }

    print("Finished.\n", .{});
    return 0;
}
