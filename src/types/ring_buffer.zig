const std = @import("std");

pub fn RingBuffer(comptime T: type, comptime N: usize) type {
    return struct {
        const Self = @This();

        buf: [N]T = undefined,
        write: std.atomic.Value(usize) = .init(0),
        read: std.atomic.Value(usize) = .init(0),

        pub inline fn capacity() usize {
            return N;
        }

        pub inline fn isEmpty(self: *Self) bool {
            return self.read.load(.acquire) == self.write.load(.acquire);
        }

        pub inline fn isFull(self: *Self) bool {
            const w = self.write.load(.acquire);
            const r = self.read.load(.acquire);
            return w - r >= N;
        }

        /// Single-producer (MIDI thread)
        pub inline fn push(self: *Self, item: T) bool {
            const w = self.write.load(.monotonic);
            const r = self.read.load(.acquire);

            if (w - r >= N) return false; // full

            self.buf[w % N] = item;
            self.write.store(w + 1, .release);
            return true;
        }

        /// Single-consumer (audio thread)
        pub inline fn pop(self: *Self, out: *T) bool {
            const r = self.read.load(.monotonic);
            const w = self.write.load(.acquire);

            if (r == w) return false; // empty

            out.* = self.buf[r % N];
            self.read.store(r + 1, .release);
            return true;
        }

        /// Optional: drop everything (call only when producer is stopped)
        pub fn clear(self: *Self) void {
            const w = self.write.load(.acquire);
            self.read.store(w, .release);
        }
    };
}
