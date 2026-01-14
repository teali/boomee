const std = @import("std");
const DelayLine = @import("delay_line.zig").DelayLine;
const OnePoleLP = @import("one_pole_lp.zig").OnePoleLP;

pub const Comb = struct {
    delay: DelayLine,
    delay_samples: usize,
    feedback: f32,
    damp: OnePoleLP,

    pub fn init(self: *Comb, alloc: std.mem.Allocator, max_delay: usize, delay_samples: usize, feedback: f32, damp_a: f32) !void {
        try self.delay.init(alloc, max_delay);
        self.delay_samples = delay_samples;
        self.feedback = feedback;
        self.damp = OnePoleLP.init(damp_a);
    }

    pub fn deinit(self: *Comb) void {
        self.delay.deinit();
    }

    pub inline fn process(self: *Comb, x: f32) f32 {
        const delayed = self.delay.readDelay(self.delay_samples);
        const damped = self.damp.process(delayed);
        const y = delayed; // output is delayed tap (common choice)
        self.delay.push(x + damped * self.feedback);
        return y;
    }
};
