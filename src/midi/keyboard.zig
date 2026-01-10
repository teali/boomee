const std = @import("std");

pub const Keyboard = struct {
    voices: [8]u7,

    pub fn init() Keyboard {
        return Keyboard{
            .voices = .{0} ** 8,
        };
    }

    pub fn startListen(self: Keyboard) void {
        var stdin_buffer: [1]u8 = undefined;
        var stdin_reader = std.fs.File.stdin().reader(&stdin_buffer);
        const stdin = &stdin_reader.interface;

        if (self.voices.len == 0) return;

        while (stdin.takeByte()) |char| {
            // do something with the char (u8)
            std.debug.print("you typed: {c}\n", .{char});
            if (char == 'q') break;
        } else |_| {}
    }
};
