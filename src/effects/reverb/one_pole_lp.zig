pub const OnePoleLP = struct {
    a: f32, // smoothing coefficient
    z: f32,

    pub fn init(a: f32) OnePoleLP {
        return .{ .a = 1 - a, .z = 0 };
    }

    pub inline fn process(self: *OnePoleLP, x: f32) f32 {
        self.z = self.a * x + (1.0 - self.a) * self.z;
        return self.z;
    }
};
