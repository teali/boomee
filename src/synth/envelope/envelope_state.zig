const std = @import("std");
const Envelope = @import("envelope.zig");

const EnvelopeState = @This();
const Stage = enum(u3) {
    attack = 0,
    decay = 1,
    sustain = 2,
    release = 3,
    idle = 4,

    inline fn idx(s: Stage) usize {
        return @intFromEnum(s);
    }
};
envelope: *Envelope,
curVal: f32,
curStage: Stage, // 0 = attack, 1 = decay, 2 = sustain, 3 = release, 4 = idle
inc_count_cur: [4]i32,

pub fn init(envelope: *Envelope) EnvelopeState {
    return EnvelopeState{
        .envelope = envelope,
        .curVal = 0.0,
        .curStage = .idle,
        .inc_count_cur = envelope.adsr_inc_amount,
    };
}

pub fn noteOn(self: *EnvelopeState) void {
    self.inc_count_cur = self.envelope.adsr_inc_amount;
    self.curVal = 0;
    self.curStage = .attack;
}

pub fn isFree(self: *EnvelopeState) bool {
    return self.curStage == .idle;
}

pub fn next(self: *EnvelopeState) f32 {
    if (self.curStage == .idle) return 0.0;

    const si = Stage.idx(self.curStage);

    self.curVal += self.envelope.adsr_inc[si];
    self.inc_count_cur[si] -= 1;

    if (self.inc_count_cur[si] == 0) {
        // advance stage: attack->decay->sustain->release->idle
        self.curStage = @enumFromInt(@intFromEnum(self.curStage) + 1);
    }

    return self.curVal;
}

pub fn noteOff(self: *EnvelopeState) void {
    self.inc_count_cur[Stage.idx(.sustain)] = 1;
}
