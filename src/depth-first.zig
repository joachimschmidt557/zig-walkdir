const std = @import("std");

const Entry = @import("entry.zig").Entry;

pub const DepthFirstWalker = struct {
    startPath    : []u8,
    recurseStack : std.atomic.Stack(*std.fs.Dir),
    allocator    : *std.mem.Allocator,
    maxDepth     : u32,

    currentDir   : std.fs.Dir,
    currentPath  : []u8,
    currentDepth : u32,

    pub const Self = @This();

    pub fn init(alloc: *std.mem.Allocator, path: []u8) !Self {
        return Self{
            .startPath    = path,
            .recurseStack = std.atomic.Stack(*std.fs.Dir).init(),
            .allocator    = alloc,
            .maxDepth     = 0,

            .currentDir   = try std.fs.Dir.open(alloc, path),
            .currentPath  = path,
            .currentDepth = 0,
        };
    }

    pub fn next(self: *Self) !?Entry {
        outer: while (true) {
            if (try self.currentDir.next()) |entry| {
                const full_entry_path = try self.allocator.alloc(u8, self.currentPath.len + entry.name.len + 1);
                std.mem.copy(u8, full_entry_path, self.currentPath);
                full_entry_path[self.currentPath.len] = std.fs.path.sep;
                std.mem.copy(u8, full_entry_path[self.currentPath.len + 1 ..], entry.name);
    
                if (entry.kind == std.fs.Dir.Entry.Kind.Directory) {
                    const new_dir = try self.allocator.create(std.atomic.Stack(*std.fs.Dir).Node);
                    new_dir.* = std.atomic.Stack(*std.fs.Dir).Node {
                        .next = undefined,
                        .data = &self.currentDir,
                    };

                    // Save the current opened directory to the stack
                    // so we continue traversing it later on
                    self.recurseStack.put(new_dir);

                    // Go one level deeper
                    const opened_dir = try std.fs.Dir.open(self.allocator, full_entry_path);
                    self.currentDir = opened_dir;
                }
    
                return Entry{
                    .name = entry.name,
                    .absolutePath = full_entry_path,
                    .relativePath = full_entry_path[self.startPath.len + 1..],
                    .kind = entry.kind,
                };
            } else {
                // No entries left in the current dir
                self.currentDir.close();
                if (self.recurseStack.pop()) |node| {

                    // Go back up one level again
                    self.currentDir = node.data;
                    self.allocator.destroy(node);

                    continue :outer;
                }
                return null;
            }
        }
    }
};
