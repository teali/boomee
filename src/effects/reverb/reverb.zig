const std = @import("std");
const DelayLine = @import("delay_line.zig").DelayLine;
const Comb = @import("comb.zig").Comb;
const Allpass = @import("allpass.zig").Allpass;

pub const Reverb = struct {
    sample_rate: f32,

    // parameters
    wet: f32,
    dry: f32,
    room: f32, // maps to comb feedback
    damp: f32, // maps to lowpass coefficient
    predelay_samples: usize,

    predelayL: DelayLine,
    predelayR: DelayLine,

    combL: [4]Comb,
    combR: [4]Comb,
    apL: [4]Allpass,
    apR: [4]Allpass,

    pub fn init(self: *Reverb, alloc: std.mem.Allocator, sample_rate: f32) !void {
        // Delay lengths chosen to be mutually prime-ish and not too small.
        // These are in samples at 44.1k-ish scale; we will scale by sample_rate.
        const base_sr: f32 = 44100.0;
        const scale: f32 = sample_rate / base_sr;

        // Helper to scale sample counts
        const s = struct {
            inline fn sc(x: usize, scale_: f32) usize {
                return @max(1, @as(usize, @intFromFloat(@as(f32, @floatFromInt(x)) * scale_)));
            }
        };

        const pre_max = s.sc(2000, scale); // ~45ms max buffer, used for predelay capacity
        self.* = .{
            .sample_rate = sample_rate,
            .wet = 0.48,
            .dry = 0.8,
            .room = 0.92,
            .damp = 0.55,
            .predelay_samples = s.sc(1000, scale), // ~4.5ms default predelay

            .predelayL = undefined,
            .predelayR = undefined,

            .combL = undefined,
            .combR = undefined,
            .apL = undefined,
            .apR = undefined,
        };

        try self.predelayL.init(alloc, pre_max);
        try self.predelayR.init(alloc, pre_max);
        // Map room -> feedback. Keep < 1 for stability.
        const fb = @min(0.985, 0.7 + self.room * 0.285); // 0.7..0.985

        // Comb delay lengths (classic-ish numbers, slightly offset between L/R)
        const combDelaysL = [_]usize{
            //s.sc(1557, scale),
            s.sc(1900, scale),
            s.sc(1617, scale),
            s.sc(1491, scale),
            s.sc(1422, scale),
        };
        const combDelaysR = [_]usize{
            // s.sc(1557 + 23, scale),
            s.sc(1900 + 23, scale),
            s.sc(1617 + 37, scale),
            s.sc(1491 + 17, scale),
            s.sc(1422 + 31, scale),
        };

        // Allpass delays
        const apDelaysL = [_]usize{
            s.sc(225, scale),
            s.sc(556, scale),
            s.sc(441, scale),
            s.sc(341, scale),
        };
        const apDelaysR = [_]usize{
            s.sc(225 + 11, scale),
            s.sc(556 + 19, scale),
            s.sc(441 + 23, scale),
            s.sc(341 + 31, scale),
        };

        // Allocate combs: max_delay buffer can be just (delay_samples + 1) but keep some slack
        for (0..4) |i| {
            try self.combL[i].init(alloc, combDelaysL[i] + 1, combDelaysL[i], fb, self.damp);
            try self.combR[i].init(alloc, combDelaysR[i] + 1, combDelaysR[i], fb, self.damp);
        }
        for (0..4) |i| {
            try self.apL[i].init(alloc, apDelaysL[i] + 1, apDelaysL[i], 0.5);
            try self.apR[i].init(alloc, apDelaysR[i] + 1, apDelaysR[i], 0.5);
        }
    }

    pub fn deinit(self: *Reverb) void {
        self.predelayL.deinit();
        self.predelayR.deinit();
        for (0..4) |i| {
            self.combL[i].deinit();
            self.combR[i].deinit();
        }
        for (0..4) |i| {
            self.apL[i].deinit();
            self.apR[i].deinit();
        }
    }

    pub inline fn setWetDry(self: *Reverb, wet: f32, dry: f32) void {
        self.wet = wet;
        self.dry = dry;
    }

    pub inline fn setPredelayMs(self: *Reverb, ms: f32) void {
        const s = ms * self.sample_rate / 1000.0;
        self.predelay_samples = @intCast(@max(0.0, s));
    }

    // Mono in -> stereo out
    pub inline fn process(self: *Reverb, x: f32) [2]f32 {
        // Pre-delay
        const pdL = self.predelayL.readDelay(self.predelay_samples);
        const pdR = self.predelayR.readDelay(self.predelay_samples);
        self.predelayL.push(x);
        self.predelayR.push(x);

        // Parallel combs
        var sumL: f32 = 0;
        var sumR: f32 = 0;
        for (0..4) |i| {
            sumL += self.combL[i].process(pdL);
            sumR += self.combR[i].process(pdR);
        }

        // Series allpass
        var yL = sumL;
        var yR = sumR;
        for (0..4) |i| {
            yL = self.apL[i].process(yL);
            yR = self.apR[i].process(yR);
        }

        // Normalize a bit (depends on comb count)
        yL *= 0.25;
        yR *= 0.25;

        // Mix
        return .{
            x * self.dry + yL * self.wet,
            x * self.dry + yR * self.wet,
        };
    }
};
