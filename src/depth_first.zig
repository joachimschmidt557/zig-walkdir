const std = @import("std");

const Entry = @import("entry.zig").Entry;

const PathDirTuple = struct {
    dir: std.fs.Dir,
    iter: std.fs.Dir.Iterator,
    path: []const u8,
};

const RecurseStack = std.atomic.Stack(*PathDirTuple);

pub const DepthFirstWalker = struct {
    startPath: []const u8,
    recurseStack: RecurseStack,
    allocator: *std.mem.Allocator,
    maxDepth: ?u32,
    hidden: bool,

    currentDir: std.fs.Dir,
    currentIter: std.fs.Dir.Iterator,
    currentPath: []const u8,
    currentDepth: u32,

    pub const Self = @This();

    pub fn init(alloc: *std.mem.Allocator, path: []const u8, max_depth: ?u32, include_hidden: bool) !Self {
        var top_dir = try std.fs.Dir.open(path);

        return Self{
            .startPath = path,
            .recurseStack = RecurseStack.init(),
            .allocator = alloc,
            .maxDepth = max_depth,
            .hidden = include_hidden,

            .currentDir = top_dir,
            .currentIter = top_dir.iterate(),
            .currentPath = path,
            .currentDepth = 0,
        };
    }

    pub fn next(self: *Self) !?Entry {
        outer: while (true) {
            if (try self.currentIter.next()) |entry| {
                const full_entry_path = try self.allocator.alloc(u8, self.currentPath.len + entry.name.len + 1);
                std.mem.copy(u8, full_entry_path, self.currentPath);
                full_entry_path[self.currentPath.len] = std.fs.path.sep;
                std.mem.copy(u8, full_entry_path[self.currentPath.len + 1 ..], entry.name);

                blk: {
                    if (entry.kind == std.fs.Dir.Entry.Kind.Directory) {
                        if (self.maxDepth) |max_depth| {
                            if (self.currentDepth >= max_depth) {
                                break :blk;
                            }
                        }

                        const new = try self.allocator.create(PathDirTuple);
                        new.* = PathDirTuple{
                            .dir = self.currentDir,
                            .iter = self.currentIter,
                            .path = self.currentPath,
                        };

                        const new_dir = try self.allocator.create(RecurseStack.Node);
                        new_dir.* = RecurseStack.Node{
                            .next = undefined,
                            .data = new,
                        };

                        // Save the current opened directory to the stack
                        // so we continue traversing it later on
                        self.recurseStack.push(new_dir);

                        // Go one level deeper
                        var opened_dir = try std.fs.Dir.open(full_entry_path);
                        self.currentPath = full_entry_path;
                        self.currentDir = opened_dir;
                        self.currentIter = opened_dir.iterate();
                        self.currentDepth += 1;
                    }
                }

                return Entry{
                    .name = entry.name,
                    .absolute_path = full_entry_path,
                    .relative_path = full_entry_path[self.startPath.len + 1 ..],
                    .kind = entry.kind,
                };
            } else {
                // No entries left in the current dir
                self.currentDir.close();
                if (self.recurseStack.pop()) |node| {
                    // Go back up one level again
                    self.currentDir = node.data.dir;
                    self.currentIter = node.data.iter;
                    self.currentPath = node.data.path;
                    self.currentDepth -= 1;

                    self.allocator.destroy(node.data);
                    self.allocator.destroy(node);

                    continue :outer;
                }
                return null;
            }
        }
    }
};
