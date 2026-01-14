const std = @import("std");
const DelayLine = @import("delay_line.zig").DelayLine;

pub const Allpass = struct {
    delay: DelayLine,
    delay_samples: usize,
    feedback: f32,

    pub fn init(self: *Allpass, alloc: std.mem.Allocator, max_delay: usize, delay_samples: usize, feedback: f32) !void {
        try self.delay.init(alloc, max_delay);
        self.delay_samples = delay_samples;
        self.feedback = feedback;
    }

    pub fn deinit(self: *Allpass) void {
        self.delay.deinit();
    }

    pub inline fn process(self: *Allpass, x: f32) f32 {
        const bufout = self.delay.readDelay(self.delay_samples);
        const y = bufout - x * self.feedback;
        self.delay.push(x + y * self.feedback);
        return y;
    }
};
