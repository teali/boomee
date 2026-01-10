const std = @import("std");
const WaveTable = @import("sound_generator/wavetable.zig").WaveTable;
const WaveTableOsc = @import("sound_generator/wavetable_osc.zig").WaveTableOsc;
const Envelope = @import("envelope/envelope.zig");
const EnvelopeState = @import("envelope/envelope_state.zig");

pub const Synth = struct {
    pub const voice_count = 16;

    waveTable: WaveTable,
    envelope: Envelope,
    envStates: [voice_count]EnvelopeState,
    voices: [voice_count]WaveTableOsc,

    pub fn init(self: *Synth) !void {
        self.* = .{
            .waveTable = WaveTable.init(),
            .envelope = undefined,
            .envStates = undefined,
            .voices = undefined,
        };

        _ = try WaveTable.buildSineTable(&self.waveTable);
        // _ = try WaveTable.buildSawTable(&self.waveTable);

        for (&self.voices) |*v| {
            v.* = WaveTableOsc.init(&self.waveTable);
        }

        self.waveTable.setFrameIncFreq(20);

        self.envelope.setAttack(0.1);
        self.envelope.setDecay(0.3);
        self.envelope.setSustain(0.5);
        self.envelope.setRelease(1);

        for (&self.envStates) |*e| {
            e.* = EnvelopeState.init(&self.envelope);
        }
    }

    // TODO: For the same note played twice it should be on the same voice
    pub fn noteOn(self: *Synth, freq: f32) void {
        std.debug.print("New Note Freq: {}\n", .{freq});

        for (0..voice_count) |i| {
            std.debug.print("Info for voice {}: {any}\n", .{ i, self.envStates[i] });

            if (self.envStates[i].curStage == 4) {
                self.voices[i].setFreq(freq);
                self.envStates[i].noteOn();
                self.envStates[i].noteOff();
                return;
            }
        }
    }

    pub fn next(self: *Synth) f32 {
        var curVal: f32 = 0;

        for (0..voice_count) |i| {
            curVal += self.voices[i].next() * self.envStates[i].next();
        }

        return curVal;
    }
};
