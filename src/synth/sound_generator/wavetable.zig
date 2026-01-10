const std = @import("std");
const AudioConfig = @import("../../types/audio_config.zig");

pub const WaveTable = struct {
    pub const max_frames: usize = 64;
    pub const sample_size: usize = 2048;

    frames: [max_frames * sample_size]f32, // length = max_frames * table_len
    frame_count: usize, // number of valid frames in [0..max_frames]
    frame_freq: f32,
    frame_inc: f32,

    pub fn init() WaveTable {
        return WaveTable{
            .frame_count = 0,
            .frames = undefined,
            .frame_freq = 0,
            .frame_inc = 0,
        };
    }

    pub fn setFrameIncFreq(self: *WaveTable, freq: f32) void {
        self.frame_freq = freq;
        self.frame_inc = freq / AudioConfig.sample_rate;
    }

    pub fn addFrame(self: *WaveTable) ![]f32 {
        if (self.frame_count >= max_frames) return error.OutOfFrames;

        self.frame_count += 1;
        const start = (self.frame_count - 1) * sample_size;

        return self.frames[start .. start + sample_size];
    }

    pub fn setFrame(self: *WaveTable, frame_index: usize, samples: []const f32) !void {
        if (samples.len != sample_size) return error.InvalidFrameLength;
        if (frame_index >= self.frame_count) return error.FrameIndexOutOfRange;

        const start = frame_index * sample_size;
        @memcpy(self.frames[start .. start + sample_size], samples);
    }

    pub fn framePtr(self: *WaveTable, frame_index: usize) []const f32 {
        std.debug.assert(self.frame_count > 0);

        const fi = frame_index % self.frame_count;
        const start = fi * sample_size;
        return self.frames[start .. start + sample_size];
    }

    /// Example: build a trivial 1-frame sine wavetable (heap allocated for demo).
    pub fn buildSineTable(waveTable: *WaveTable) !void {
        const two_pi: f32 = 6.283185307179586;
        const tl_f = @as(f32, @floatFromInt(sample_size));

        const buf = try waveTable.addFrame();

        for (buf, 0..) |*s, i| {
            const x = two_pi * (@as(f32, @floatFromInt(i)) / tl_f);
            s.* = @sin(x);
        }
    }

    /// Naive single-cycle saw table in range [-1, +1).
    /// Note: This will alias at higher pitches unless you add band-limiting (mipmapped tables, BLEP, etc.).
    pub fn buildSawTable(waveTable: *WaveTable) !void {
        const tl_f = @as(f32, @floatFromInt(sample_size));

        const buf = try waveTable.addFrame();

        for (buf, 0..) |*s, i| {
            const t = @as(f32, @floatFromInt(i)) / tl_f; // [0, 1)
            s.* = (2.0 * t) - 1.0; // [-1, +1)
        }
    }
};
