const std = @import("std");
const Allocator = std.mem.Allocator;

const Entry = @import("entry.zig").Entry;

const PathsQueue = std.atomic.Queue(*PathDepthPair);

const PathDepthPair = struct {
    path: []const u8,
    depth: u32,
};

pub const BreadthFirstWalker = struct {
    start_path: []const u8,
    paths_to_scan: PathsQueue,
    allocator: *Allocator,
    max_depth: ?u32,
    hidden: bool,

    current_dir: std.fs.Dir,
    current_iter: std.fs.Dir.Iterator,
    current_path: []const u8,
    current_depth: u32,

    pub const Self = @This();

    pub fn init(alloc: *Allocator, path: []const u8, max_depth: ?u32, include_hidden: bool) !Self {
        var topDir = try std.fs.Dir.open(path);

        return Self{
            .start_path = path,
            .paths_to_scan = PathsQueue.init(),
            .allocator = alloc,
            .max_depth = max_depth,
            .hidden = include_hidden,

            .current_dir = topDir,
            .current_iter = topDir.iterate(),
            .current_path = path,
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

                // Remember this directory, we are going to traverse it later
                blk: {
                    if (entry.kind == std.fs.Dir.Entry.Kind.Directory) {
                        if (self.max_depth) |max_depth| {
                            if (self.current_depth >= max_depth) {
                                break :blk;
                            }
                        }

                        const pair = try self.allocator.create(PathDepthPair);
                        pair.* = PathDepthPair{
                            .path = full_entry_path,
                            .depth = self.current_depth + 1,
                        };

                        const new_dir = try self.allocator.create(PathsQueue.Node);
                        new_dir.* = PathsQueue.Node{
                            .next = undefined,
                            .prev = undefined,
                            .data = pair,
                        };

                        self.paths_to_scan.put(new_dir);
                    }
                }

                return Entry{
                    .allocator = self.allocator,
                    .name = entry.name,
                    .absolute_path = full_entry_path,
                    .relative_path = full_entry_path[self.start_path.len + 1 ..],
                    .kind = entry.kind,
                };
            } else {
                // No entries left in the current dir
                self.current_dir.close();
                if (self.paths_to_scan.get()) |node| {
                    const pair = node.data.*;

                    self.current_path = pair.path;
                    self.current_depth = pair.depth;
                    self.current_dir = try std.fs.Dir.open(self.current_path);
                    self.current_iter = self.current_dir.iterate();

                    self.allocator.destroy(&pair);
                    self.allocator.destroy(node);

                    continue :outer;
                }
                return null;
            }
        }
    }
};
