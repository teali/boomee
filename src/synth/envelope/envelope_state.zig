const std = @import("std");
const Envelope = @import("envelope.zig");

const EnvelopeState = @This();

envelope: *Envelope,
curVal: f32,
curStage: u3, // 0 = attack, 1 = decay, 2 = sustain, 3 = release, 4 = idle
inc_count_cur: [4]i32,

pub fn init(envelope: *Envelope) EnvelopeState {
    return EnvelopeState{
        .envelope = envelope,
        .curVal = 0.0,
        .curStage = 4,
        .inc_count_cur = envelope.adsr_inc_amount,
    };
}

pub fn noteOn(self: *EnvelopeState) void {
    self.inc_count_cur = self.envelope.adsr_inc_amount;
    self.curVal = 0;
    self.curStage = 0;
}

pub fn next(self: *EnvelopeState) f32 {
    if (self.curStage == 4) return 0;

    self.curVal += self.envelope.adsr_inc[self.curStage];
    self.inc_count_cur[self.curStage] -= 1;

    if (self.inc_count_cur[self.curStage] == 0) self.curStage += 1;
    return self.curVal;
}

pub fn noteOff(self: *EnvelopeState) void {
    self.inc_count_cur[2] = 1;
}
