const AudioConfig = @import("../../types/audio_config.zig");

const Envelope = @This();

adsr: [4]f32,
adsr_inc: [4]f32,
adsr_inc_amount: [4]i32,

pub fn init() Envelope {
    return Envelope{
        .adsr = .{ 0, 0, 1.0, 0 },
        .adsr_inc = .{ 0, 0, 0, 0 },
        .adsr_inc_amount = .{ 0, 0, -1, 0 },
    };
}

pub fn setAttack(self: *Envelope, attack: f32) void {
    self.adsr[0] = attack;

    // If no attack don't divide by 0. Also checks for negative case
    self.adsr_inc_amount[0] = if (attack <= 0.0) 1 else @intFromFloat(AudioConfig.sample_rate * attack);
    self.adsr_inc[0] = 1.0 / @as(f32, @floatFromInt(self.adsr_inc_amount[0]));
}

pub fn setDecay(self: *Envelope, decay: f32) void {
    self.adsr[1] = decay;

    self.adsr_inc_amount[1] = if (decay <= 0.0) 1 else @intFromFloat(AudioConfig.sample_rate * decay);
    self.adsr_inc[1] = (self.adsr[2] - 1) / @as(f32, @floatFromInt(self.adsr_inc_amount[1]));
}

pub fn setRelease(self: *Envelope, release: f32) void {
    self.adsr[3] = release;

    self.adsr_inc_amount[3] = if (release <= 0.0) 1 else @intFromFloat(AudioConfig.sample_rate * release);
    self.adsr_inc[3] = -self.adsr[2] / @as(f32, @floatFromInt(self.adsr_inc_amount[3]));
}

pub fn setSustain(self: *Envelope, sustain: f32) void {
    self.adsr[2] = sustain;

    // Recalculate decay and release
    self.setDecay(self.adsr[1]);
    self.setRelease(self.adsr[3]);
}
