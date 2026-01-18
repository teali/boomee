const std = @import("std");
const zaudio = @import("zaudio");
const Boomee = @import("boomee.zig");
const MIDI = @import("midi/midi.zig");

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

        const s = st.boomee.next();

        const base = i * channels;
        out[base] = s[0];
        out[base + 1] = s[1];
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
        // Lower white keys (C3..E4)
        'z' => 48, // C3
        'x' => 50, // D3
        'c' => 52, // E3
        'v' => 53, // F3
        'b' => 55, // G3
        'n' => 57, // A3
        'm' => 59, // B3
        ',' => 60, // C4
        '.' => 62, // D4
        '/' => 64, // E4

        // Lower black keys (C#3..D#4)
        's' => 49, // C#3
        'd' => 51, // D#3
        'g' => 54, // F#3
        'h' => 56, // G#3
        'j' => 58, // A#3
        'l' => 61, // C#4
        ';' => 63, // D#4

        // Upper white keys (F4..A5)
        'q' => 65, // F4
        'w' => 67, // G4
        'e' => 69, // A4
        'r' => 71, // B4
        't' => 72, // C5
        'y' => 74, // D5
        'u' => 76, // E5
        'i' => 77, // F5
        'o' => 79, // G5
        'p' => 81, // A5

        // Upper black keys (F#4..A#5)
        '2' => 66, // F#4
        '3' => 68, // G#4
        '4' => 70, // A#4
        '6' => 73, // C#5
        '7' => 75, // D#5
        '9' => 78, // F#5
        '0' => 80, // G#5
        '-' => 82, // A#5

        else => null,
    };
}

fn onMidi(delta_seconds: f64, msg: []const u8, user_data: ?*anyopaque) void {
    _ = delta_seconds;
    _ = user_data;

    // msg is a slice of the raw MIDI bytes for one message
    std.debug.print("MIDI: len={} bytes=", .{msg.len});
    for (msg) |b| std.debug.print("{x:0>2} ", .{b});
    std.debug.print("\n", .{});
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

    try boomee.init(alloc);

    defer alloc.destroy(boomee);
    defer boomee.deinit();

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

    while (true) std.Thread.sleep(200 * std.time.ns_per_ms);

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
        if (keyToMidiNote(char)) |note| {
            state.boomee.synth.noteOn(note);
        }

        if (char == '`') break;
    } else |_| {}
}
