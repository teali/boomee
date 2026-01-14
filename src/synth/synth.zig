const std = @import("std");
const Wavetable = @import("sound_generator/wavetable.zig");
const WavetableVoice = @import("sound_generator/wavetable_voice.zig");
const Envelope = @import("envelope/envelope.zig");
const EnvelopeState = @import("envelope/envelope_state.zig");

// TODO: Voice Manager/ Allocation
// TODO: Per Voice LFOs
// TODO: Mixer/Compressor
pub const Synth = struct {
    pub const voice_count = 16;

    waveTable: Wavetable,
    envelope: Envelope,
    voices: [voice_count]WavetableVoice,

    pub fn init(self: *Synth) !void {
        self.* = .{
            .waveTable = Wavetable.init(),
            .envelope = undefined,
            .voices = undefined,
        };

        _ = try Wavetable.buildSineTable(&self.waveTable);
        _ = try Wavetable.buildTriangleTable(&self.waveTable);
        //   _ = try Wavetable.buildSawTable(&self.waveTable);

        self.waveTable.setFrameIncFreq(10);

        self.envelope.setAttack(0.1);
        self.envelope.setDecay(0.3);
        self.envelope.setSustain(0.5);
        self.envelope.setRelease(1);

        for (&self.voices) |*v| {
            v.init(&self.waveTable, &self.envelope);
        }
    }

    pub fn midiNoteToFreq(note: u8) f32 {
        // A4 (MIDI 69) = 440 Hz
        const n: f32 = @floatFromInt(note);
        return 440.0 * std.math.pow(f32, 2.0, (n - 69.0) / 12.0);
    }

    // TODO: For the same note played twice it should be on the same voice
    pub fn noteOn(self: *Synth, note: u8) void {
        const freq = midiNoteToFreq(note);
        std.debug.print("New Note Freq: {}\n", .{freq});

        for (0..voice_count) |i| {
            if (self.voices[i].envelopeState.curStage == 4) {
                self.voices[i].noteOn(freq);
                return;
            }
        }
    }

    pub fn next(self: *Synth) f32 {
        var curVal: f32 = 0;

        for (0..voice_count) |i| {
            curVal += self.voices[i].next();
        }

        return curVal;
    }
};
