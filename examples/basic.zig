const std = @import("std");

const walkdir = @import("walkdir");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = &gpa.allocator;

    // var walker = try walkdir.DepthFirstWalker.init(allocator, ".", .{});
    var walker = try walkdir.BreadthFirstWalker.init(allocator, ".", .{});
    defer walker.deinit();

    const stdout = std.io.getStdOut();

    while (true) {
        if (walker.next()) |entry| {
            if (entry) |e| {
                try stdout.writer().print("{s}\n", .{e.name});
                e.deinit();
            } else {
                break;
            }
        } else |err| {
            std.log.err("Error encountered: {}", .{err});
        }
    }
}
