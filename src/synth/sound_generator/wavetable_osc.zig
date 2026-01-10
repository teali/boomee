const std = @import("std");
const WaveTable = @import("wavetable.zig").WaveTable;
const AudioConfig = @import("../../types/audio_config.zig");

pub const WaveTableOsc = struct {
    table: *WaveTable,

    phase: f32 = 0.0,
    phase_inc: f32 = 0.0,

    // Continuous Frame position in [0, frame_count]
    frame_pos: f32 = 0.0,

    pub fn init(table: *WaveTable) WaveTableOsc {
        return .{
            .table = table,
        };
    }

    pub fn setFreq(self: *WaveTableOsc, freq: f32) void {
        self.phase_inc = freq / AudioConfig.sample_rate;
    }

    pub fn next(self: *WaveTableOsc) f32 {
        const fc_f = @as(f32, @floatFromInt(self.table.frame_count));
        const tl_f = @as(f32, @floatFromInt(WaveTable.sample_size));

        // --- Frame selection (morph between two adjacent frames) ---
        // Wrap frame_pos into [0, frame_count)
        var fp = self.frame_pos;
        fp = fp - fc_f * @floor(fp / fc_f);

        const frame0_i: usize = @intFromFloat(@floor(fp));
        const frame1_i: usize = (frame0_i + 1) % self.table.frame_count;
        const frame_mix: f32 = fp - @floor(fp);

        const f0 = self.table.framePtr(frame0_i);
        const f1 = self.table.framePtr(frame1_i);

        // --- Phase lookup ---
        // Convert phase [0,1) to sample index [0, table_len)
        const idx_f = self.phase * tl_f;
        const idx0: usize = @as(usize, @intFromFloat(@floor(idx_f))) % WaveTable.sample_size;
        const idx1: usize = (idx0 + 1) % WaveTable.sample_size;
        const frac: f32 = idx_f - @floor(idx_f);

        // Linear interpolation within each frame
        const s00 = lerp(f0[idx0], f0[idx1], frac);
        const s11 = lerp(f1[idx0], f1[idx1], frac);

        // Morph between frames
        const out = lerp(s00, s11, frame_mix);

        // --- Advance ---
        self.phase += self.phase_inc;
        self.phase -= @floor(self.phase); // wrap to [0,1)

        self.frame_pos += self.table.frame_inc;
        // wrapping handled next call
        return out;
    }

    inline fn lerp(a: f32, b: f32, t: f32) f32 {
        return a + (b - a) * t;
    }
};
