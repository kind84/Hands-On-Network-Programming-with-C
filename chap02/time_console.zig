const std = @import("std");
const datetime = @import("./zig-datetime/datetime.zig");
const timezones = @import("./zig-datetime/timezones.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    var now = datetime.Datetime.now().shiftTimezone(&timezones.Europe.Rome);
    var now_str = try now.formatHttp(&gpa.allocator);
    defer gpa.allocator.free(now_str);

    std.debug.print("Local time is: {}\n", .{now_str});
}
