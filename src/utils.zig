const std = @import("std");

pub const IntVec2 = struct {
    x: i32,
    y: i32,

    pub fn init(x: anytype, y: anytype) IntVec2 {
        return IntVec2{ .x = @as(i32, x), .y = @as(i32, y) };
    }

    pub fn addVec(self: IntVec2, other: IntVec2) IntVec2 {
        return self.add(other.x, other.y);
    }

    pub fn add(self: IntVec2, x: anytype, y: anytype) IntVec2 {
        return IntVec2{ .x = self.x + @as(i32, x), .y = self.y + @as(i32, y) };
    }

    pub fn subVec(self: IntVec2, other: IntVec2) IntVec2 {
        return self.sub(other.x, other.y);
    }

    pub fn sub(self: IntVec2, x: anytype, y: anytype) IntVec2 {
        return IntVec2{ .x = self.x - @as(i32, x), .y = self.y - @as(i32, y) };
    }

    pub fn div(self: IntVec2, d: anytype) IntVec2 {
        return IntVec2{ .x = @divTrunc(self.x, @as(i32, d)), .y = @divTrunc(self.y, @as(i32, d)) };
    }

    pub fn eq(self: IntVec2, other: IntVec2) bool {
        return self.x == other.x and self.y == other.y;
    }

    pub fn clamp(self: IntVec2, min: IntVec2, max: IntVec2) IntVec2 {
        return IntVec2{
            .x = std.math.clamp(self.x, min.x, max.x),
            .y = std.math.clamp(self.y, min.y, max.y),
        };
    }

    pub fn lessThan(self: IntVec2, other: IntVec2) bool {
        return self.x < other.x and self.y < other.y;
    }
};
