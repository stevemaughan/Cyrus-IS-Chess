//! Constant data taken from the original binary (never retyped by hand).

const std = @import("std");

/// The canonical 16K code block, loaded at $6000 (reference/extracted).
pub const binary: *const [0x4000]u8 = @embedFile("cyrus_bin");
const origin = 0x6000;

fn slice(comptime addr: u16, comptime len: usize) *const [len]u8 {
    return binary[addr - origin ..][0..len];
}

/// $7800: knight offsets (+14 +18 +31 +33 -14 -18 -31 -33, 8-bit).
pub const knight_offsets = slice(0x7800, 8);
/// $7808: diagonal offsets (+15 +17 -17 -15); with $780C the eight king/queen steps.
pub const diagonal_offsets = slice(0x7808, 4);
/// $780C: orthogonal offsets (+1 -1 +16 -16).
pub const orthogonal_offsets = slice(0x780C, 4);
/// $7808-$780F: all eight directions (king, queen).
pub const all_offsets = slice(0x7808, 8);
/// $9000-$9BCC: opening book, 2,685 nine-bit entries, most significant bit first.
pub const book = slice(0x9000, 0x9BCD - 0x9000);

test "tables match the documented values" {
    try std.testing.expectEqualSlices(u8, &.{ 0x0E, 0x12, 0x1F, 0x21, 0xF2, 0xEE, 0xE1, 0xDF }, knight_offsets);
    try std.testing.expectEqualSlices(u8, &.{ 0x0F, 0x11, 0xEF, 0xF1 }, diagonal_offsets);
    try std.testing.expectEqualSlices(u8, &.{ 0x01, 0xFF, 0x10, 0xF0 }, orthogonal_offsets);
    // first book bytes as seen in the hex dump
    try std.testing.expectEqualSlices(u8, &.{ 0x26, 0x92, 0x69, 0xC4 }, book[0..4]);
}
