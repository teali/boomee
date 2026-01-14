const std = @import("std");
const Synth = @import("synth/synth.zig").Synth;
const Reverb = @import("effects/reverb/reverb.zig").Reverb;

pub const Boomee = struct {
    synth: Synth,
    reverb: Reverb,
    alloc: std.mem.Allocator,

    pub fn init(self: *Boomee, alloc: std.mem.Allocator) !void {
        try self.synth.init();
        self.reverb = undefined;
        try self.reverb.init(alloc, 44100);

        self.alloc = alloc;
    }

    pub fn deinit(self: *Boomee) void {
        self.reverb.deinit();
    }

    pub fn noteOn(self: *Boomee, freq: f32) void {
        self.synth.noteOn(freq);
    }

    pub fn next(self: *Boomee) [2]f32 {
        const curSynth = self.synth.next() * 0.1;
        return self.reverb.process(curSynth);
    }
};
