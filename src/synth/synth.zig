const std = @import("std");

const Wavetable = @import("sound_generator/wavetable.zig");
const WavetableVoice = @import("sound_generator/wavetable_voice.zig");
const Envelope = @import("envelope/envelope.zig");
const EnvelopeState = @import("envelope/envelope_state.zig");
const MIDI = @import("../midi/midi.zig");
const RingBuffer = @import("../types/ring_buffer.zig").RingBuffer(MIDI.MidiMessage, 1024);

const Synth = @This();

// TODO: Per Voice LFOs
// TODO: Mixer/Compressor
// TODO: Fix Aliasing
// TODO: Implement sustain pedals
pub const VOICE_COUNT = 16;
const NO_VOICE = 225;

waveTable: Wavetable,
envelope: Envelope,
voices: [VOICE_COUNT]WavetableVoice,
note_to_voice: [128]u8,
midi_events: RingBuffer,
age: u32,

pub fn init(self: *Synth) !void {
    self.* = .{
        .waveTable = Wavetable.init(), // stop collapse
        .envelope = undefined,
        .voices = undefined,
        .note_to_voice = .{NO_VOICE} ** 128,
        .midi_events = undefined,
        .age = 0,
    };

    // _ = try Wavetable.buildSineTable(&self.waveTable);
    //_ = try Wavetable.buildTriangleTable(&self.waveTable);
    _ = try Wavetable.buildSawTable(&self.waveTable);

    self.waveTable.setFrameIncFreq(10);

    self.envelope.setAttack(0.1);
    self.envelope.setDecay(0.3);
    self.envelope.setSustain(0.5);
    self.envelope.setRelease(1);

    for (&self.voices) |*v| {
        v.init(&self.waveTable, &self.envelope);
    }
}

pub fn pushMidiEvent(self: *Synth, msg: MIDI.MidiMessage) void {
    _ = self.midi_events.push(msg);
}

fn onEvent(self: *Synth, msg: MIDI.MidiMessage) void {
    switch (msg) {
        .note_on => |n| {
            self.noteOn(n.note);
        },
        .note_off => |n| {
            self.noteOff(n.note);
        },
        else => {},
    }
}

// Returns the "most" free voice
fn getVoice(self: *Synth, note: u8) usize {
    // If the note is already assigned a voice use it.
    if (self.note_to_voice[note] != NO_VOICE) return self.note_to_voice[note];

    // Get an idle voice
    for (0..VOICE_COUNT) |i| {
        if (self.voices[i].isFree()) return i;
    }

    var best_score: u32 = self.voices[0].getStealScore();
    var best: usize = 0;

    for (1..VOICE_COUNT) |i| {
        const score = self.voices[i].getStealScore();
        if (score < best_score) {
            best = i;
            best_score = score;
        }
    }

    return best;
}

fn noteOn(self: *Synth, note: u8) void {
    const voice = self.getVoice(note);

    self.note_to_voice[note] = NO_VOICE;
    self.note_to_voice[note] = @intCast(voice);
    self.voices[voice].noteOn(note, self.age);
}

fn noteOff(self: *Synth, note: u8) void {
    // voice was already stolen
    if (self.note_to_voice[note] == NO_VOICE) return;

    const voice = self.note_to_voice[note];
    self.voices[voice].noteOff();
}

pub fn next(self: *Synth) f32 {
    self.age += 1;

    var nextMsg: MIDI.MidiMessage = undefined;

    while (!self.midi_events.isEmpty()) {
        _ = self.midi_events.pop(&nextMsg);
        self.onEvent(nextMsg);
    }

    var curVal: f32 = 0;

    for (0..VOICE_COUNT) |i| {
        curVal += self.voices[i].next();
    }

    return curVal;
}
