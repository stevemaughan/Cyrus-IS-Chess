//! The Windows 7 build's I/O layer (`zig build -Dwin7=true`).
//!
//! Zig's standard I/O implementation (`std.Io.Threaded`) imports ntdll
//! functions that first appeared in Windows 8, so an executable that links
//! it does not start on Windows 7. The engine needs very little from
//! `std.Io`: a mutex and a condition variable (both built on the futex
//! calls), a clock and a short sleep. This file provides just those through
//! documented kernel32 functions that Windows Vista and 7 have, together
//! with the worker thread and the panic output. Every other `std.Io`
//! operation fails, as in `std.Io.failing`. Standard input and output are
//! in pipe_io.zig.
//!
//! Platform adaptation only (AGENTS.md §1, class 3): nothing here is read by
//! the search or the evaluation.

const std = @import("std");
const builtin = @import("builtin");
const build_options = @import("build_options");
const pipe_io = @import("pipe_io.zig");
const Io = std.Io;

const is_windows = builtin.os.tag == .windows;

/// Whether this is the Windows 7 build.
pub const enabled = build_options.win7;

comptime {
    if (enabled and !is_windows) @compileError("-Dwin7=true needs a Windows target");
}

const k32 = struct {
    const FileTime = extern struct { low: u32, high: u32 };
    const ThreadStart = *const fn (?*anyopaque) callconv(.winapi) u32;

    extern "kernel32" fn AcquireSRWLockExclusive(lock: *usize) callconv(.winapi) void;
    extern "kernel32" fn ReleaseSRWLockExclusive(lock: *usize) callconv(.winapi) void;
    extern "kernel32" fn SleepConditionVariableSRW(cond: *usize, lock: *usize, ms: u32, flags: u32) callconv(.winapi) c_int;
    extern "kernel32" fn WakeAllConditionVariable(cond: *usize) callconv(.winapi) void;
    extern "kernel32" fn QueryPerformanceCounter(count: *i64) callconv(.winapi) c_int;
    extern "kernel32" fn QueryPerformanceFrequency(frequency: *i64) callconv(.winapi) c_int;
    extern "kernel32" fn GetSystemTimeAsFileTime(time: *FileTime) callconv(.winapi) void;
    extern "kernel32" fn Sleep(ms: u32) callconv(.winapi) void;
    extern "kernel32" fn CreateThread(attr: ?*anyopaque, stack: usize, start: ThreadStart, param: ?*anyopaque, flags: u32, id: ?*u32) callconv(.winapi) ?*anyopaque;
    extern "kernel32" fn WaitForSingleObject(handle: *anyopaque, ms: u32) callconv(.winapi) u32;
    extern "kernel32" fn CloseHandle(handle: *anyopaque) callconv(.winapi) c_int;
    extern "kernel32" fn GetStdHandle(which: u32) callconv(.winapi) ?*anyopaque;
    extern "kernel32" fn ExitProcess(code: u32) callconv(.winapi) noreturn;

    const infinite: u32 = 0xFFFF_FFFF;
    const std_error_handle: u32 = @bitCast(@as(i32, -12));
    const stack_size_param_is_a_reservation: u32 = 0x0001_0000;
};

/// The `std.Io` of the Windows 7 build.
pub const io: Io = .{ .userdata = null, .vtable = &vtable };

const vtable: Io.VTable = blk: {
    var v = Io.failing.vtable.*;
    v.futexWait = futexWait;
    v.futexWaitUncancelable = futexWaitUncancelable;
    v.futexWake = futexWake;
    v.now = now;
    v.sleep = sleep;
    break :blk v;
};

// The futex calls behind `std.Io.Mutex` and `std.Io.Condition`. Every waiter
// shares one slim lock and one condition variable (both Vista and later),
// and every wake wakes them all: `std.Io` allows spurious wake-ups, and the
// engine has two threads. A waiter tests the value under the lock, and a
// waker takes the lock after the value has changed, so a wake-up cannot fall
// between the test and the sleep.
var futex_lock: usize = 0; // SRWLOCK_INIT
var futex_cond: usize = 0; // CONDITION_VARIABLE_INIT

fn wait(ptr: *const u32, expected: u32, ms: u32) void {
    k32.AcquireSRWLockExclusive(&futex_lock);
    defer k32.ReleaseSRWLockExclusive(&futex_lock);
    if (@atomicLoad(u32, ptr, .seq_cst) != expected) return;
    _ = k32.SleepConditionVariableSRW(&futex_cond, &futex_lock, ms, 0);
}

fn futexWait(_: ?*anyopaque, ptr: *const u32, expected: u32, timeout: Io.Timeout) Io.Cancelable!void {
    wait(ptr, expected, milliseconds(timeout));
}

fn futexWaitUncancelable(_: ?*anyopaque, ptr: *const u32, expected: u32) void {
    wait(ptr, expected, k32.infinite);
}

fn futexWake(_: ?*anyopaque, _: *const u32, _: u32) void {
    k32.AcquireSRWLockExclusive(&futex_lock);
    k32.ReleaseSRWLockExclusive(&futex_lock);
    k32.WakeAllConditionVariable(&futex_cond);
}

/// The time left of `timeout` in whole milliseconds, rounded up.
fn milliseconds(timeout: Io.Timeout) u32 {
    const left = timeout.toDurationFromNow(io) orelse return k32.infinite;
    const ns = left.raw.nanoseconds;
    if (ns <= 0) return 0;
    const ms = @divFloor(ns + std.time.ns_per_ms - 1, std.time.ns_per_ms);
    return @intCast(@min(ms, k32.infinite - 1));
}

fn sleep(_: ?*anyopaque, timeout: Io.Timeout) Io.Cancelable!void {
    k32.Sleep(milliseconds(timeout));
}

/// The awake and boot clocks are the performance counter; the real clock is
/// the system time since 1970. The CPU-time clocks are not provided.
fn now(_: ?*anyopaque, clock: Io.Clock) Io.Timestamp {
    switch (clock) {
        .awake, .boot => {
            var count: i64 = 0;
            var frequency: i64 = 0;
            _ = k32.QueryPerformanceCounter(&count);
            _ = k32.QueryPerformanceFrequency(&frequency);
            if (frequency <= 0) return .zero;
            return .{ .nanoseconds = @divTrunc(@as(i96, count) * std.time.ns_per_s, frequency) };
        },
        .real => {
            var time: k32.FileTime = undefined;
            k32.GetSystemTimeAsFileTime(&time);
            // 100 ns units since 1601-01-01.
            const ticks: i96 = (@as(u64, time.high) << 32) | time.low;
            return .{ .nanoseconds = (ticks - 116_444_736_000_000_000) * 100 };
        },
        else => return .zero,
    }
}

/// The worker thread, started with CreateThread: `std.Thread` goes through
/// NtCreateThreadEx, whose attribute list is undocumented.
pub const Thread = struct {
    handle: *anyopaque,

    /// As much stack as `std.Thread` reserves by default.
    const stack_size = 16 * 1024 * 1024;

    pub fn spawn(comptime T: type, comptime entry: fn (*T) void, arg: *T) error{SystemResources}!Thread {
        const start = struct {
            fn start(param: ?*anyopaque) callconv(.winapi) u32 {
                entry(@ptrCast(@alignCast(param.?)));
                return 0;
            }
        }.start;
        const handle = k32.CreateThread(null, stack_size, start, arg, k32.stack_size_param_is_a_reservation, null) orelse
            return error.SystemResources;
        return .{ .handle = handle };
    }

    pub fn join(t: Thread) void {
        _ = k32.WaitForSingleObject(t.handle, k32.infinite);
        _ = k32.CloseHandle(t.handle);
    }
};

/// Writes `text` to standard error, as far as that is possible.
pub fn stderrWrite(text: []const u8) void {
    const handle = k32.GetStdHandle(k32.std_error_handle) orelse return;
    const out = pipe_io.WinPipe.open(handle) orelse return;
    out.writeAll(text) catch {};
}

/// The panic handler of the Windows 7 build: the message on standard error,
/// then exit status 3. (std's handler prints through `std.Io.Threaded`.)
pub fn panic(msg: []const u8, _: ?usize) noreturn {
    stderrWrite("panic: ");
    stderrWrite(msg);
    stderrWrite("\n");
    k32.ExitProcess(3);
}

const Handoff = struct {
    mutex: Io.Mutex = .init,
    cond: Io.Condition = .init,
    jobs: u32 = 0,
    done: u32 = 0,
    quitting: bool = false,

    fn worker(h: *Handoff) void {
        while (true) {
            h.mutex.lockUncancelable(io);
            while (h.jobs == 0 and !h.quitting) h.cond.waitUncancelable(io, &h.mutex);
            if (h.jobs == 0) {
                h.mutex.unlock(io);
                return;
            }
            h.jobs -= 1;
            h.done += 1;
            h.mutex.unlock(io);
        }
    }
};

test "mutex and condition hand every job to the worker thread" {
    if (!is_windows) return error.SkipZigTest;
    var h: Handoff = .{};
    const thread = try Thread.spawn(Handoff, Handoff.worker, &h);
    const jobs = 100_000;
    for (0..jobs) |_| {
        h.mutex.lockUncancelable(io);
        h.jobs += 1;
        h.mutex.unlock(io);
        h.cond.signal(io);
    }
    h.mutex.lockUncancelable(io);
    h.quitting = true;
    h.mutex.unlock(io);
    h.cond.signal(io);
    thread.join();
    try std.testing.expectEqual(@as(u32, jobs), h.done);
    try std.testing.expectEqual(@as(u32, 0), h.jobs);
}

test "the awake clock advances across a sleep" {
    if (!is_windows) return error.SkipZigTest;
    const t0 = Io.Clock.awake.now(io).nanoseconds;
    try io.sleep(.fromMilliseconds(30), .awake);
    const ms = @divTrunc(Io.Clock.awake.now(io).nanoseconds - t0, std.time.ns_per_ms);
    try std.testing.expect(ms >= 25 and ms < 5000);
}

test "a futex wait with a timeout returns without a wake" {
    if (!is_windows) return error.SkipZigTest;
    var value: u32 = 7;
    const t0 = Io.Clock.awake.now(io).nanoseconds;
    try io.futexWaitTimeout(u32, &value, 7, .{ .duration = .{ .raw = .fromMilliseconds(30), .clock = .awake } });
    const ms = @divTrunc(Io.Clock.awake.now(io).nanoseconds - t0, std.time.ns_per_ms);
    try std.testing.expect(ms < 5000);
    // A value that has already changed does not wait at all.
    io.futexWaitUncancelable(u32, &value, 8);
}

test "the real clock is the time since 1970" {
    if (!is_windows) return error.SkipZigTest;
    const s = @divTrunc(Io.Clock.real.now(io).nanoseconds, std.time.ns_per_s);
    // Between 2020 and 2100.
    try std.testing.expect(s > 1_577_836_800 and s < 4_102_444_800);
}

test "timeouts round up to whole milliseconds" {
    if (!is_windows) return error.SkipZigTest;
    try std.testing.expectEqual(k32.infinite, milliseconds(.none));
    try std.testing.expectEqual(@as(u32, 1), milliseconds(.{ .duration = .{ .raw = .fromNanoseconds(1), .clock = .awake } }));
    try std.testing.expectEqual(@as(u32, 2), milliseconds(.{ .duration = .{ .raw = .fromNanoseconds(1_000_001), .clock = .awake } }));
    try std.testing.expectEqual(@as(u32, 0), milliseconds(.{ .duration = .{ .raw = .fromMilliseconds(-5), .clock = .awake } }));
}
