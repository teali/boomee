const std = @import("std");
const zaudio = @import("zaudio");
const Boomee = @import("boomee.zig").Boomee;

const c = @cImport({
    @cInclude("termios.h");
    @cInclude("unistd.h");
});

const SAMPLE_RATE: u32 = 48_000;
const CHANNELS: u32 = 2;

const State = struct { boomee: *Boomee };

fn dataCallback(
    device: *zaudio.Device,
    pOutput: ?*anyopaque,
    _: ?*const anyopaque,
    frame_count: u32,
) callconv(.c) void {
    const out_ptr = pOutput orelse return;

    // zaudio stores the user data pointer in the device.
    const st_any = device.getUserData() orelse return;
    const st: *State = @ptrCast(@alignCast(st_any));

    const frames: usize = @as(usize, @intCast(frame_count));
    const channels: usize = @as(usize, @intCast(device.getPlaybackChannels()));

    // Interleaved f32 output: [L R L R ...]
    const out: [*]f32 = @ptrCast(@alignCast(out_ptr));

    var i: usize = 0;
    while (i < frames) : (i += 1) {
        // Generate mono sample from the wavetable oscillator

        const s: f32 = st.boomee.next() * 0.1;

        const base = i * channels;
        var ch: usize = 0;
        while (ch < channels) : (ch += 1) {
            out[base + ch] = s;
        }
    }
}

fn enableRawMode() !c.termios {
    var orig: c.termios = undefined;
    if (c.tcgetattr(0, &orig) != 0) return error.TermiosFail;

    var raw = orig;
    raw.c_lflag &= ~(@as(c.tcflag_t, c.ICANON) | @as(c.tcflag_t, c.ECHO));
    raw.c_cc[c.VMIN] = 1;
    raw.c_cc[c.VTIME] = 0;

    if (c.tcsetattr(0, c.TCSAFLUSH, &raw) != 0)
        return error.TermiosFail;

    return orig;
}

fn restoreMode(orig: *const c.termios) void {
    _ = c.tcsetattr(0, c.TCSAFLUSH, orig);
}

pub fn keyToMidiNote(ch: u8) ?u8 {
    return switch (ch) {
        // White keys (home row), starting at F3
        'a' => 53, // F3
        's' => 55, // G3
        'd' => 57, // A3
        'f' => 59, // B3
        'g' => 60, // C4 (middle C)
        'h' => 62, // D4
        'j' => 64, // E4
        'k' => 65, // F4
        'l' => 67, // G4
        ';' => 69, // A4
        '\'' => 71, // B4 (end at quote)

        // Black keys (top row), including your requirement: 'y' => C#4
        'w' => 54, // F#3
        'e' => 56, // G#3
        'r' => 58, // A#3
        'y' => 61, // C#4
        'u' => 63, // D#4
        'o' => 66, // F#4
        'p' => 68, // G#4

        else => null,
    };
}

pub fn midiNoteToFreq(note: u8) f32 {
    // A4 (MIDI 69) = 440 Hz
    const n: f32 = @floatFromInt(note);
    return 440.0 * std.math.pow(f32, 2.0, (n - 69.0) / 12.0);
}

pub fn keyToFreq(ch: u8) ?f32 {
    const note = keyToMidiNote(ch) orelse return null;
    return midiNoteToFreq(note);
}

pub fn main() !void {
    // zaudio requires init/deinit.
    zaudio.init(std.heap.c_allocator);
    defer zaudio.deinit();

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const alloc = gpa.allocator();

    var boomee = try alloc.create(Boomee);
    errdefer alloc.destroy(boomee);

    try boomee.init();

    defer alloc.destroy(boomee);

    //boomee.synth.voices.setFreq(440.0);
    var state = State{ .boomee = boomee };

    // std.debug.print("Before the next calls in main: {}\n", .{state.boomee.synth.voices.table.frame_count});
    // _ = boomee.next();

    var cfg = zaudio.Device.Config.init(.playback);
    cfg.playback.format = zaudio.Format.float32;
    cfg.playback.channels = CHANNELS;
    cfg.sample_rate = SAMPLE_RATE;
    cfg.data_callback = dataCallback;
    cfg.user_data = &state;

    const device = try zaudio.Device.create(null, cfg);
    defer device.destroy();

    try zaudio.Device.start(device);

    std.debug.print("Press Ctrl-C to quit.\n", .{});

    const orig = try enableRawMode();
    defer restoreMode(&orig);

    std.debug.print("Press keys (q to quit)\n", .{});

    var stdin_buffer: [1]u8 = undefined;
    var stdin_reader = std.fs.File.stdin().reader(&stdin_buffer);
    const stdin = &stdin_reader.interface;

    while (stdin.takeByte()) |char| {
        // do something with the char (u8)
        //        std.debug.print("you typed: {c}\n", .{char});
        if (keyToFreq(char)) |freq| {
            state.boomee.synth.noteOn(freq);
        }

        if (char == 'q') break;
    } else |_| {}
}
