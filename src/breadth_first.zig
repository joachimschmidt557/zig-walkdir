const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

const Entry = @import("entry.zig").Entry;
const Options = @import("options.zig").Options;

const PathDepthPair = struct {
    path: []const u8,
    depth: usize,
};

pub const BreadthFirstWalker = struct {
    start_path: []const u8,
    paths_to_scan: ArrayList(PathDepthPair),
    allocator: *Allocator,
    max_depth: ?usize,
    hidden: bool,

    current_dir: std.fs.Dir,
    current_iter: std.fs.Dir.Iterator,
    current_path: []const u8,
    current_depth: usize,

    pub const Self = @This();

    pub fn init(allocator: *Allocator, path: []const u8, options: Options) !Self {
        var top_dir = try std.fs.cwd().openDir(path, .{ .iterate = true });

        return Self{
            .start_path = path,
            .paths_to_scan = ArrayList(PathDepthPair).init(allocator),
            .allocator = allocator,
            .max_depth = options.max_depth,
            .hidden = options.include_hidden,

            .current_dir = top_dir,
            .current_iter = top_dir.iterate(),
            .current_path = try allocator.dupe(u8, path),
            .current_depth = 0,
        };
    }

    pub fn next(self: *Self) !?Entry {
        outer: while (true) {
            if (try self.current_iter.next()) |entry| {
                // Check if the entry is hidden
                if (!self.hidden and entry.name[0] == '.') {
                    continue :outer;
                }

                const full_entry_path = try self.allocator.alloc(u8, self.current_path.len + entry.name.len + 1);
                std.mem.copy(u8, full_entry_path, self.current_path);
                full_entry_path[self.current_path.len] = std.fs.path.sep;
                std.mem.copy(u8, full_entry_path[self.current_path.len + 1 ..], entry.name);
                const relative_path = full_entry_path[self.start_path.len + 1 ..];
                const name = full_entry_path[self.current_path.len + 1 ..];

                // Remember this directory, we are going to traverse it later
                blk: {
                    if (entry.kind == std.fs.Dir.Entry.Kind.Directory) {
                        if (self.max_depth) |max_depth| {
                            if (self.current_depth >= max_depth) {
                                break :blk;
                            }
                        }

                        try self.paths_to_scan.append(PathDepthPair{
                            .path = try self.allocator.dupe(u8, full_entry_path),
                            .depth = self.current_depth + 1,
                        });
                    }
                }

                return Entry{
                    .allocator = self.allocator,
                    .name = name,
                    .absolute_path = full_entry_path,
                    .relative_path = relative_path,
                    .kind = entry.kind,
                };
            } else {
                // No entries left in the current dir
                self.current_dir.close();
                self.allocator.free(self.current_path);

                if (self.paths_to_scan.items.len > 0) {
                    const pair = self.paths_to_scan.orderedRemove(0);

                    self.current_path = pair.path;
                    self.current_depth = pair.depth;
                    self.current_dir = try std.fs.cwd().openDir(self.current_path, .{ .iterate = true });
                    self.current_iter = self.current_dir.iterate();

                    continue :outer;
                }
                return null;
            }
        }
    }

    pub fn deinit(self: *Self) void {
        while (self.paths_to_scan.popOrNull()) |node| {}
        self.paths_to_scan.deinit();
    }
};
