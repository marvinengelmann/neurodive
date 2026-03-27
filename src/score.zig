const std = @import("std");
const builtin = @import("builtin");
const is_windows = builtin.os.tag == .windows;

const HIGHSCORE_FILENAME = ".neurodive_highscore";
const SEP: u8 = if (is_windows) '\\' else '/';

pub const Score = struct {
    current: u32,
    highscore: u32,
    survival_accumulator: f32,

    pub fn init() Score {
        return .{
            .current = 0,
            .highscore = loadHighscore(),
            .survival_accumulator = 0,
        };
    }

    pub fn addPoints(self: *Score, points: u32) void {
        self.current += points;
    }

    pub fn addSurvival(self: *Score, delta: f32, speed: f32) void {
        self.survival_accumulator += delta * speed * 2.0;
        const points: u32 = @intFromFloat(self.survival_accumulator);
        if (points > 0) {
            self.current += points;
            self.survival_accumulator -= @floatFromInt(points);
        }
    }

    pub fn save(self: *Score) void {
        if (self.current > self.highscore) {
            self.highscore = self.current;
            saveHighscore(self.highscore);
        }
    }

    pub fn reset(self: *Score) void {
        self.current = 0;
        self.survival_accumulator = 0;
    }

    fn getHighscorePath() ?struct { buf: [std.fs.max_path_bytes]u8, len: usize } {
        var path_buf: [std.fs.max_path_bytes]u8 = undefined;
        if (is_windows) {
            const home_w = std.process.getenvW(std.unicode.utf8ToUtf16LeStringLiteral("USERPROFILE")) orelse return null;
            var home_buf: [512]u8 = undefined;
            const home_len = std.unicode.utf16LeToUtf8(&home_buf, home_w) catch return null;
            const home = home_buf[0..home_len];
            const path = std.fmt.bufPrint(&path_buf, "{s}{c}{s}", .{ home, SEP, HIGHSCORE_FILENAME }) catch return null;
            return .{ .buf = path_buf, .len = path.len };
        } else {
            const home = std.posix.getenv("HOME") orelse return null;
            const path = std.fmt.bufPrint(&path_buf, "{s}{c}{s}", .{ home, SEP, HIGHSCORE_FILENAME }) catch return null;
            return .{ .buf = path_buf, .len = path.len };
        }
    }

    fn loadHighscore() u32 {
        const path_info = getHighscorePath() orelse return 0;
        const path = path_info.buf[0..path_info.len];

        const file = std.fs.openFileAbsolute(path, .{}) catch return 0;
        defer file.close();

        var buf: [32]u8 = undefined;
        const n = file.readAll(&buf) catch return 0;
        const trimmed = std.mem.trimRight(u8, buf[0..n], &.{ '\n', '\r', ' ' });
        return std.fmt.parseInt(u32, trimmed, 10) catch 0;
    }

    fn saveHighscore(value: u32) void {
        const path_info = getHighscorePath() orelse return;
        const path = path_info.buf[0..path_info.len];

        const file = std.fs.createFileAbsolute(path, .{}) catch return;
        defer file.close();

        var buf: [32]u8 = undefined;
        const slice = std.fmt.bufPrint(&buf, "{d}\n", .{value}) catch return;
        file.writeAll(slice) catch {};
    }
};
