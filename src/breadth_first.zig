const std = @import("std");

const Entry = @import("entry.zig").Entry;

const PathDepthPair = struct {
    path         : []u8,
    depth        : u32,
};

pub const BreadthFirstWalker = struct {
    startPath    : []u8,
    pathsToScan  : std.atomic.Queue(PathDepthPair),
    allocator    : *std.mem.Allocator,
    maxDepth     : u32,
    hidden       : bool,

    currentDir   : std.fs.Dir,
    currentPath  : []u8,
    currentDepth : u32,

    pub const Self = @This();

    pub fn init(alloc: *std.mem.Allocator, path: []u8) !Self {
        return Self{
            .startPath    = path,
            .pathsToScan  = std.atomic.Queue(PathDepthPair).init(),
            .allocator    = alloc,
            .maxDepth     = 0,
            .hidden       = False,

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
    
                // Remember this directory, we are going to traverse it later
                if (entry.kind == std.fs.Dir.Entry.Kind.Directory) {
                    if (self.currentDepth < self.maxDepth) {
                        const pair = try self.allocator.create(PathDepthPair);
                        pair.* = PathDepthPair {
                            .path = full_entry_path,
                            .depth = self.currentDepth + 1,
                        };

                        const new_dir = try self.allocator.create(std.atomic.Queue(PathDepthPair).Node);
                        new_dir.* = std.atomic.Queue(PathDepthPair).Node {
                            .next = undefined,
                            .prev = undefined,
                            .data = pair,
                        };
        
                        self.pathsToScan.put(new_dir);
                    }
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
                if (self.pathsToScan.get()) |node| {
                    const pair = node.data;

                    self.currentPath = pair.path;
                    self.currentDepth = pair.depth;
                    self.currentDir = try std.fs.Dir.open(self.allocator, self.currentPath);

                    self.allocator.destroy(pair);
                    self.allocator.destroy(node);

                    continue :outer;
                }
                return null;
            }
        }
    }
};
