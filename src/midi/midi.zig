const std = @import("std");
const rtmidi = @import("rtmidi");
const Boomee = @import("../boomee.zig");

const MIDI = @This();

midi_in: *rtmidi.In,

pub const MidiMessage = union(enum) {
    note_on: struct {
        channel: u8,
        note: u8,
        velocity: u8,
    },
    note_off: struct {
        channel: u8,
        note: u8,
    },
    cc: struct {
        channel: u8,
        cc: u8,
        value: u8,
    },
    pitch_bend: struct {
        channel: u8,
        value: i16, // -8192 .. +8191
    },
    unknown,
};

pub fn init(self: *MIDI, boomee: *Boomee) !void {
    self.midi_in = rtmidi.In.createDefault() orelse {
        std.debug.print("Failed to create RtMidi In device\n", .{});
        return error.DeviceNotStarted;
    };

    const count = self.midi_in.getPortCount();
    std.debug.print("MIDI In ports: {}\n", .{count});

    var buf: [128]u8 = undefined;

    for (0..count) |i| {
        try self.midi_in.getPortName(i, &buf);

        const deviceNameLen = try self.midi_in.getPortNameLength(i);

        std.debug.print("  [{}] {s}\n", .{ i, buf[0..deviceNameLen] });
    }

    // Receive everything (set to true to ignore)
    self.midi_in.ignoreTypes(false, false, false);

    // Open the first port
    self.midi_in.openPort(0, "groovebox-in");

    self.midi_in.setCallback(onMidiThunk, boomee);
}

pub fn deinit(self: *MIDI) void {
    self.midi_in.cancelCallback();
    self.midi_in.closePort();
    self.midi_in.destroy();
}

pub fn onMidiThunk(delta: f64, msg: []const u8, user_data: ?*anyopaque) void {
    const boomee: *Boomee = @ptrCast(@alignCast(user_data.?));

    if (msg.len < 1) return;

    const status = msg[0];
    const msg_type = status & 0xF0;
    const channel = status & 0x0F;
    _ = delta;

    switch (msg_type) {
        0x90 => { // Note On
            if (msg.len < 3) return;

            const note = msg[1];
            const velocity = msg[2];

            if (velocity == 0) {
                // MIDI rule: Note On with vel=0 == Note Off
                //self.noteOff(note);
                boomee.onMidi(.{ .note_off = .{ .channel = channel, .note = note } });
            } else {
                boomee.onMidi(.{ .note_on = .{ .channel = channel, .note = note, .velocity = velocity } });
            }
        },
        0x80 => { // Note Off
            if (msg.len < 3) return;
            const note = msg[1];

            boomee.onMidi(.{ .note_off = .{ .channel = channel, .note = note } });
        },
        else => {},
    }
}

pub fn midiNoteToFreq(note: u8) f32 {
    // A4 (MIDI 69) = 440 Hz
    const n: f32 = @floatFromInt(note);
    return 440.0 * std.math.pow(f32, 2.0, (n - 69.0) / 12.0);
}
