//! Standard input and output that also work when the GUI gives the engine
//! overlapped (asynchronous) pipe handles, as fastchess does on Windows.
//! Zig's std treats a pending read or write on such a handle as unreachable
//! (a panic at the first read that has to wait). Here every pipe operation on
//! Windows passes an OVERLAPPED with its own event and waits for completion,
//! which is also correct for ordinary synchronous pipes. Consoles, files and
//! other systems use std's streaming reader and writer.

const std = @import("std");
const builtin = @import("builtin");

const is_windows = builtin.os.tag == .windows;

/// A Windows pipe handle used with explicit OVERLAPPED waits.
pub const WinPipe = struct {
    handle: *anyopaque,
    event: *anyopaque,

    const Overlapped = extern struct {
        internal: usize = 0,
        internal_high: usize = 0,
        offset: u32 = 0,
        offset_high: u32 = 0,
        event: ?*anyopaque = null,
    };

    extern "kernel32" fn ReadFile(h: *anyopaque, buf: [*]u8, len: u32, n: ?*u32, ov: ?*Overlapped) callconv(.winapi) c_int;
    extern "kernel32" fn WriteFile(h: *anyopaque, buf: [*]const u8, len: u32, n: ?*u32, ov: ?*Overlapped) callconv(.winapi) c_int;
    extern "kernel32" fn GetOverlappedResult(h: *anyopaque, ov: *Overlapped, n: *u32, wait: c_int) callconv(.winapi) c_int;
    extern "kernel32" fn CreateEventW(attr: ?*anyopaque, manual_reset: c_int, initial: c_int, name: ?[*:0]const u16) callconv(.winapi) ?*anyopaque;
    extern "kernel32" fn GetFileType(h: *anyopaque) callconv(.winapi) u32;
    extern "kernel32" fn GetLastError() callconv(.winapi) u32;

    const file_type_pipe = 3;
    const error_handle_eof = 38;
    const error_broken_pipe = 109;
    const error_no_data = 232;
    const error_io_pending = 997;

    /// The pipe behind `handle`, or null if it is not a pipe.
    pub fn open(handle: *anyopaque) ?WinPipe {
        if (GetFileType(handle) != file_type_pipe) return null;
        const ev = CreateEventW(null, 1, 0, null) orelse return null;
        return .{ .handle = handle, .event = ev };
    }

    /// Bytes read, 0 at the end of input.
    pub fn read(p: WinPipe, buf: []u8) error{ReadFailed}!usize {
        var ov: Overlapped = .{ .event = p.event };
        const len = std.math.lossyCast(u32, buf.len);
        if (ReadFile(p.handle, buf.ptr, len, null, &ov) == 0) switch (GetLastError()) {
            error_io_pending => {},
            error_broken_pipe, error_handle_eof => return 0,
            else => return error.ReadFailed,
        };
        var n: u32 = 0;
        if (GetOverlappedResult(p.handle, &ov, &n, 1) == 0) return switch (GetLastError()) {
            error_broken_pipe, error_handle_eof => 0,
            else => error.ReadFailed,
        };
        return n;
    }

    pub fn writeAll(p: WinPipe, bytes: []const u8) error{WriteFailed}!void {
        var rest = bytes;
        while (rest.len > 0) {
            var ov: Overlapped = .{ .event = p.event };
            const len = std.math.lossyCast(u32, rest.len);
            if (WriteFile(p.handle, rest.ptr, len, null, &ov) == 0) switch (GetLastError()) {
                error_io_pending => {},
                else => return error.WriteFailed,
            };
            var n: u32 = 0;
            if (GetOverlappedResult(p.handle, &ov, &n, 1) == 0 or n == 0) return error.WriteFailed;
            rest = rest[n..];
        }
    }
};

/// Standard input as a `std.Io.Reader`.
pub const Stdin = struct {
    pipe: if (is_windows) ?WinPipe else void,
    pipe_reader: std.Io.Reader,
    file_reader: std.Io.File.Reader,

    /// `s` must stay where it is while its reader is in use.
    pub fn init(s: *Stdin, io: std.Io, buf: []u8) void {
        const file = std.Io.File.stdin();
        s.* = .{
            .pipe = if (is_windows) WinPipe.open(file.handle) else {},
            .pipe_reader = .{ .vtable = &.{ .stream = stream }, .buffer = buf, .seek = 0, .end = 0 },
            .file_reader = file.readerStreaming(io, buf),
        };
    }

    pub fn reader(s: *Stdin) *std.Io.Reader {
        if (is_windows and s.pipe != null) return &s.pipe_reader;
        return &s.file_reader.interface;
    }

    fn stream(r: *std.Io.Reader, w: *std.Io.Writer, limit: std.Io.Limit) std.Io.Reader.StreamError!usize {
        // Only Windows pipes use this reader; elsewhere `pipe` is void.
        if (is_windows) {
            const s: *Stdin = @alignCast(@fieldParentPtr("pipe_reader", r));
            const dest = limit.slice(try w.writableSliceGreedy(1));
            const n = try s.pipe.?.read(dest);
            if (n == 0) return error.EndOfStream;
            w.advance(n);
            return n;
        } else unreachable;
    }
};

/// Standard output, written a whole line at a time.
pub const Stdout = struct {
    pipe: if (is_windows) ?WinPipe else void,
    buf: [16384]u8 = undefined,
    file_writer: std.Io.File.Writer = undefined,

    /// `o` must stay where it is while it is in use.
    pub fn init(o: *Stdout, io: std.Io) void {
        const file = std.Io.File.stdout();
        o.* = .{ .pipe = if (is_windows) WinPipe.open(file.handle) else {} };
        o.file_writer = file.writerStreaming(io, &o.buf);
    }

    /// Writes `text` and a newline, then flushes.
    pub fn line(o: *Stdout, text: []const u8) error{WriteFailed}!void {
        if (is_windows) if (o.pipe) |p| {
            if (text.len < o.buf.len) {
                @memcpy(o.buf[0..text.len], text);
                o.buf[text.len] = '\n';
                return p.writeAll(o.buf[0 .. text.len + 1]);
            }
            try p.writeAll(text);
            return p.writeAll("\n");
        };
        const w = &o.file_writer.interface;
        try w.writeAll(text);
        try w.writeByte('\n');
        try w.flush();
    }
};

test "stdin and stdout set up on this platform" {
    var buf: [64]u8 = undefined;
    var in: Stdin = undefined;
    in.init(std.testing.io, &buf);
    _ = in.reader();
    var out: Stdout = undefined;
    out.init(std.testing.io);
}
