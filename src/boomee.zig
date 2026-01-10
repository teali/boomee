const std = @import("std");
const Synth = @import("synth/synth.zig").Synth;

pub const Boomee = struct {
    synth: Synth,

    pub fn init(self: *Boomee) !void {
        try self.synth.init();
    }

    pub fn noteOn(self: *Boomee, freq: f32) void {
        self.synth.noteOn(freq);
    }

    pub fn next(self: *Boomee) f32 {
        return self.synth.next();
    }
};
