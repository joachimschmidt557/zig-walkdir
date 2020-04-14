pub const Options = struct {
    include_hidden: bool,
    max_depth: ?usize,

    const Self = @This();

    pub const default = Self{
        .include_hidden = false,
        .max_depth = null,
    };
};
