const std = @import("std");

pub const DelayLine = struct {
    allocator: std.mem.Allocator,
    buf: []f32,
    idx: usize,

    pub fn init(self: *DelayLine, alloc: std.mem.Allocator, len: usize) !void {
        self.allocator = alloc;
        self.buf = try alloc.alloc(f32, len);
        @memset(self.buf, 0);
        self.idx = 0;
    }

    pub fn deinit(self: *DelayLine) void {
        self.allocator.free(self.buf);
    }

    inline fn wrap(self: *DelayLine, i: isize) usize {
        const n: isize = @intCast(self.buf.len);
        const x = @mod(i, n);
        return @intCast(x);
    }

    pub inline fn push(self: *DelayLine, x: f32) void {
        self.buf[self.idx] = x;
        self.idx += 1;
        if (self.idx >= self.buf.len) self.idx = 0;
    }

    pub inline fn readDelay(self: *DelayLine, delay_samples: usize) f32 {
        const i: isize = @as(isize, @intCast(self.idx)) - 1 - @as(isize, @intCast(delay_samples));
        return self.buf[self.wrap(i)];
    }
};
