const std = @import("std");
const Synth = @import("synth/synth.zig");
const Reverb = @import("effects/reverb/reverb.zig");
const MIDI = @import("midi/midi.zig");

const Boomee = @This();

synth: Synth,
reverb: Reverb,
alloc: std.mem.Allocator,
midi: MIDI,

pub fn init(self: *Boomee, alloc: std.mem.Allocator) !void {
    try self.synth.init();
    self.reverb = undefined;
    try self.reverb.init(alloc, 44100);

    self.alloc = alloc;

    try self.midi.init(self);
}

pub fn deinit(self: *Boomee) void {
    self.reverb.deinit();
    self.midi.deinit();
}

pub fn onMidi(self: *Boomee, msg: MIDI.MidiMessage) void {
    self.synth.pushMidiEvent(msg);
}

pub fn next(self: *Boomee) [2]f32 {
    const curSynth = self.synth.next() * 0.1;
    // return .{ curSynth, curSynth };
    return self.reverb.process(curSynth);
}
