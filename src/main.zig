const std = @import("std");
const testing = std.testing;

const Entry = @import("entry.zig").Entry;

const BreadthFirstWalker = @import("breadth_first.zig").BreadthFirstWalker;
const DepthFirstWalker = @import("depth_first.zig").DepthFirstWalker;

pub const TraversalMethod = enum {
    BreadthFirst,
    DepthFirst,
};

pub const WalkDirOptions = struct {
    method          : TraversalMethod,
    follow_symlinks : bool,
    include_hidden  : bool,

    const Self = @This();

    pub fn default() Self {
        return Self{
            .method          = TraversalMethod.BreadthFirst,
            .follow_symlinks = false,
            .include_hidden  = false,
        };
    }
};

pub const Walker = struct {
    internal_walker : *DepthFirstWalker,

    pub const Self = @This();

    pub fn init(alloc: *std.mem.Allocator, path: []u8, options: WalkDirOptions) !Self {
        return Self{
            .internal_walker = & try DepthFirstWalker.init(alloc, path),
        };
    }

    pub fn next(self: *Self) !?Entry {
        return self.internal_walker.next();
    }
};

pub const MultiWalker = struct {
};
