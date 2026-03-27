const std = @import("std");
const builtin = @import("builtin");
const is_windows = builtin.os.tag == .windows;
const windows = if (is_windows) std.os.windows else undefined;
const posix = if (!is_windows) std.posix else undefined;

pub const Key = enum {
    left,
    right,
    up,
    down,
    enter,
    quit,
    restart,
    none,
};

pub const Color = enum(u8) {
    reset = 0,
    bold = 1,
    dim = 2,
    red = 31,
    green = 32,
    yellow = 33,
    blue = 34,
    magenta = 35,
    cyan = 36,
    white = 37,
    bright_red = 91,
    bright_green = 92,
    bright_yellow = 93,
    bright_blue = 94,
    bright_magenta = 95,
    bright_cyan = 96,
    bright_white = 97,
};

pub const Size = struct {
    rows: u16,
    cols: u16,
};

const BUFFER_SIZE = 32768;

const Handle = if (is_windows) windows.HANDLE else posix.fd_t;
const OriginalMode = if (is_windows) WindowsOriginalMode else posix.termios;

const WindowsOriginalMode = struct {
    stdin_mode: u32,
    stdout_mode: u32,
};

const ENABLE_ECHO_INPUT: u32 = 0x0004;
const ENABLE_LINE_INPUT: u32 = 0x0002;
const ENABLE_PROCESSED_INPUT: u32 = 0x0001;
const ENABLE_VIRTUAL_TERMINAL_INPUT: u32 = 0x0200;
const ENABLE_VIRTUAL_TERMINAL_PROCESSING: u32 = 0x0004;
const ENABLE_PROCESSED_OUTPUT: u32 = 0x0001;

pub const Terminal = struct {
    original_mode: OriginalMode,
    stdout_handle: Handle,
    stdin_handle: Handle,
    buf: [BUFFER_SIZE]u8,
    buf_pos: usize,

    pub fn init() !Terminal {
        if (is_windows) {
            return initWindows();
        } else {
            return initPosix();
        }
    }

    fn initPosix() !Terminal {
        const stdout_handle = std.fs.File.stdout().handle;
        const stdin_handle = std.fs.File.stdin().handle;
        const original = try posix.tcgetattr(stdin_handle);
        var raw = original;

        raw.lflag.ECHO = false;
        raw.lflag.ICANON = false;
        raw.lflag.ISIG = false;
        raw.lflag.IEXTEN = false;

        raw.iflag.IXON = false;
        raw.iflag.ICRNL = false;
        raw.iflag.BRKINT = false;
        raw.iflag.INPCK = false;
        raw.iflag.ISTRIP = false;

        raw.oflag.OPOST = false;

        raw.cc[@intFromEnum(std.c.V.MIN)] = 0;
        raw.cc[@intFromEnum(std.c.V.TIME)] = 0;

        try posix.tcsetattr(stdin_handle, .NOW, raw);

        var term = Terminal{
            .original_mode = original,
            .stdout_handle = stdout_handle,
            .stdin_handle = stdin_handle,
            .buf = undefined,
            .buf_pos = 0,
        };

        term.writeStr("\x1b[?25l\x1b[2J\x1b[H");
        term.flush();

        return term;
    }

    fn initWindows() !Terminal {
        const kernel32 = if (is_windows) windows.kernel32 else unreachable;
        const stdin_handle = kernel32.GetStdHandle(windows.STD_INPUT_HANDLE) orelse return error.NoConsole;
        const stdout_handle = kernel32.GetStdHandle(windows.STD_OUTPUT_HANDLE) orelse return error.NoConsole;

        var original_stdin_mode: u32 = 0;
        var original_stdout_mode: u32 = 0;
        if (kernel32.GetConsoleMode(stdin_handle, &original_stdin_mode) == 0) return error.NoConsole;
        if (kernel32.GetConsoleMode(stdout_handle, &original_stdout_mode) == 0) return error.NoConsole;

        const raw_stdin = (original_stdin_mode & ~(ENABLE_ECHO_INPUT | ENABLE_LINE_INPUT | ENABLE_PROCESSED_INPUT)) | ENABLE_VIRTUAL_TERMINAL_INPUT;
        const raw_stdout = original_stdout_mode | ENABLE_VIRTUAL_TERMINAL_PROCESSING | ENABLE_PROCESSED_OUTPUT;

        if (kernel32.SetConsoleMode(stdin_handle, raw_stdin) == 0) return error.NoConsole;
        if (kernel32.SetConsoleMode(stdout_handle, raw_stdout) == 0) return error.NoConsole;

        var term = Terminal{
            .original_mode = .{ .stdin_mode = original_stdin_mode, .stdout_mode = original_stdout_mode },
            .stdout_handle = stdout_handle,
            .stdin_handle = stdin_handle,
            .buf = undefined,
            .buf_pos = 0,
        };

        term.writeStr("\x1b[?25l\x1b[2J\x1b[H");
        term.flush();

        return term;
    }

    pub fn deinit(self: *Terminal) void {
        self.writeStr("\x1b[?25h\x1b[0m\x1b[2J\x1b[H");
        self.flush();

        if (is_windows) {
            const kernel32 = windows.kernel32;
            _ = kernel32.SetConsoleMode(self.stdin_handle, self.original_mode.stdin_mode);
            _ = kernel32.SetConsoleMode(self.stdout_handle, self.original_mode.stdout_mode);
        } else {
            posix.tcsetattr(self.stdin_handle, .NOW, self.original_mode) catch {};
        }
    }

    pub fn readKey(self: *Terminal) Key {
        if (is_windows) {
            return readKeyWindows(self);
        } else {
            return readKeyPosix(self);
        }
    }

    fn readKeyPosix(self: *Terminal) Key {
        _ = self;
        var buf: [8]u8 = undefined;
        const n = posix.read(std.fs.File.stdin().handle, &buf) catch return .none;
        if (n == 0) return .none;
        return parseKeyBuf(&buf, n);
    }

    fn readKeyWindows(self: *Terminal) Key {
        const kernel32 = if (is_windows) windows.kernel32 else unreachable;
        const result = kernel32.WaitForSingleObjectEx(self.stdin_handle, 0, 0);
        if (result != 0) return .none;

        var buf: [8]u8 = undefined;
        var bytes_read: u32 = 0;
        const success = kernel32.ReadFile(self.stdin_handle, &buf, buf.len, &bytes_read, null);
        if (success == 0 or bytes_read == 0) return .none;
        return parseKeyBuf(&buf, bytes_read);
    }

    fn parseKeyBuf(buf: *const [8]u8, n: anytype) Key {
        const len: usize = @intCast(n);
        if (len == 0) return .none;

        if (buf[0] == 'q' or buf[0] == 'Q') return .quit;
        if (buf[0] == 'r' or buf[0] == 'R') return .restart;
        if (buf[0] == '\r' or buf[0] == '\n') return .enter;

        if (len >= 3 and buf[0] == '\x1b' and buf[1] == '[') {
            return switch (buf[2]) {
                'A' => .up,
                'B' => .down,
                'C' => .right,
                'D' => .left,
                else => .none,
            };
        }

        if (buf[0] == '\x1b') return .quit;

        return .none;
    }

    pub fn getSize() Size {
        if (is_windows) {
            return getSizeWindows();
        } else {
            return getSizePosix();
        }
    }

    fn getSizePosix() Size {
        var wsz: posix.winsize = .{ .row = 0, .col = 0, .xpixel = 0, .ypixel = 0 };
        const TIOCGWINSZ = std.c.T.IOCGWINSZ;
        const result = std.c.ioctl(std.fs.File.stdout().handle, @intCast(TIOCGWINSZ), @intFromPtr(&wsz));
        if (result == 0 and wsz.row > 0 and wsz.col > 0) {
            return .{ .rows = wsz.row, .cols = wsz.col };
        }
        return .{ .rows = 24, .cols = 80 };
    }

    fn getSizeWindows() Size {
        const kernel32 = if (is_windows) windows.kernel32 else unreachable;
        const handle = kernel32.GetStdHandle(windows.STD_OUTPUT_HANDLE) orelse return .{ .rows = 24, .cols = 80 };
        var info: windows.CONSOLE_SCREEN_BUFFER_INFO = undefined;
        if (kernel32.GetConsoleScreenBufferInfo(handle, &info) != 0) {
            const cols: u16 = @intCast(info.srWindow.Right - info.srWindow.Left + 1);
            const rows: u16 = @intCast(info.srWindow.Bottom - info.srWindow.Top + 1);
            if (rows > 0 and cols > 0) return .{ .rows = rows, .cols = cols };
        }
        return .{ .rows = 24, .cols = 80 };
    }

    pub fn moveCursor(self: *Terminal, row: u16, col: u16) void {
        var tmp: [32]u8 = undefined;
        const slice = std.fmt.bufPrint(&tmp, "\x1b[{d};{d}H", .{ row, col }) catch return;
        self.writeStr(slice);
    }

    pub fn setColor(self: *Terminal, color: Color) void {
        var tmp: [16]u8 = undefined;
        const slice = std.fmt.bufPrint(&tmp, "\x1b[{d}m", .{@intFromEnum(color)}) catch return;
        self.writeStr(slice);
    }

    pub fn resetColor(self: *Terminal) void {
        self.writeStr("\x1b[0m");
    }

    pub fn clearScreen(self: *Terminal) void {
        self.writeStr("\x1b[H\x1b[J");
    }

    pub fn writeStr(self: *Terminal, str: []const u8) void {
        const remaining = BUFFER_SIZE - self.buf_pos;
        if (str.len > remaining) {
            self.flush();
        }
        if (str.len > BUFFER_SIZE) {
            self.rawWrite(str);
            return;
        }
        @memcpy(self.buf[self.buf_pos..][0..str.len], str);
        self.buf_pos += str.len;
    }

    pub fn writeChar(self: *Terminal, char: u8) void {
        if (self.buf_pos >= BUFFER_SIZE) {
            self.flush();
        }
        self.buf[self.buf_pos] = char;
        self.buf_pos += 1;
    }

    pub fn flush(self: *Terminal) void {
        if (self.buf_pos == 0) return;
        self.rawWrite(self.buf[0..self.buf_pos]);
        self.buf_pos = 0;
    }

    fn rawWrite(self: *Terminal, data: []const u8) void {
        if (is_windows) {
            var written: u32 = 0;
            _ = windows.kernel32.WriteFile(self.stdout_handle, data.ptr, @intCast(data.len), &written, null);
        } else {
            _ = posix.write(self.stdout_handle, data) catch {};
        }
    }
};
