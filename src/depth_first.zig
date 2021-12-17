const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

const Entry = @import("entry.zig").Entry;
const Options = @import("Options.zig");

const PathDirTuple = struct {
    iter: std.fs.Dir.Iterator,
    path: []const u8,
};

pub const DepthFirstWalker = struct {
    start_path: []const u8,
    recurse_stack: ArrayList(PathDirTuple),
    allocator: Allocator,
    max_depth: ?usize,
    hidden: bool,

    current_dir: std.fs.Dir,
    current_iter: std.fs.Dir.Iterator,
    current_path: []const u8,
    current_depth: usize,

    pub const Self = @This();

    pub fn init(alloc: Allocator, path: []const u8, options: Options) !Self {
        var top_dir = try std.fs.cwd().openDir(path, .{ .iterate = true });

        return Self{
            .start_path = path,
            .recurse_stack = ArrayList(PathDirTuple).init(alloc),
            .allocator = alloc,
            .max_depth = options.max_depth,
            .hidden = options.include_hidden,

            .current_dir = top_dir,
            .current_iter = top_dir.iterate(),
            .current_path = try std.mem.dupe(alloc, u8, path),
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

                blk: {
                    if (entry.kind == std.fs.Dir.Entry.Kind.Directory) {
                        if (self.max_depth) |max_depth| {
                            if (self.current_depth >= max_depth) {
                                break :blk;
                            }
                        }

                        // Save the current opened directory to the stack
                        // so we continue traversing it later on
                        try self.recurse_stack.append(PathDirTuple{
                            .iter = self.current_iter,
                            .path = self.current_path,
                        });

                        // Go one level deeper
                        var opened_dir = try std.fs.cwd().openDir(full_entry_path, .{ .iterate = true });
                        self.current_path = try std.mem.dupe(self.allocator, u8, full_entry_path);
                        self.current_dir = opened_dir;
                        self.current_iter = opened_dir.iterate();
                        self.current_depth += 1;
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

                if (self.recurse_stack.popOrNull()) |node| {
                    // Go back up one level again
                    self.current_dir = node.iter.dir;
                    self.current_iter = node.iter;
                    self.current_path = node.path;
                    self.current_depth -= 1;

                    continue :outer;
                }
                return null;
            }
        }
    }

    pub fn deinit(self: *Self) void {
        self.recurse_stack.deinit();
    }
};
