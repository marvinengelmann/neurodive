const std = @import("std");
const Terminal = @import("terminal.zig").Terminal;
const Color = @import("terminal.zig").Color;
const Player = @import("player.zig").Player;
const PLAYER_CHAR = @import("player.zig").PLAYER_CHAR;
const World = @import("world.zig").World;
const Score = @import("score.zig").Score;

const BUILDING_CHAR = '#';
const WALL_WIDTH = 3;

pub const Renderer = struct {
    play_width: i16,
    play_height: i16,
    offset_x: i16,
    total_cols: u16,
    total_rows: u16,

    pub fn init(cols: u16, rows: u16) Renderer {
        const play_w: i16 = @intCast(@min(cols -| (WALL_WIDTH * 2 + 2), 50));
        const offset: i16 = @intCast((@as(i16, @intCast(cols)) - play_w - WALL_WIDTH * 2) >> 1);
        return .{
            .play_width = play_w,
            .play_height = @intCast(rows -| 3),
            .offset_x = offset,
            .total_cols = cols,
            .total_rows = rows,
        };
    }

    pub fn drawGame(self: *const Renderer, term: *Terminal, player: *const Player, world: *const World, score: *const Score) void {
        term.clearScreen();
        self.drawHud(term, score, world.speed);
        self.drawBuildings(term);
        self.drawEntities(term, world);
        self.drawPlayer(term, player);
        self.clearBelow(term);
        term.flush();
    }

    fn drawHud(self: *const Renderer, term: *Terminal, score: *const Score, speed: f32) void {
        term.moveCursor(1, 1);
        term.setColor(.bright_cyan);

        var buf: [128]u8 = undefined;
        const hud = std.fmt.bufPrint(&buf, "  NEURODIVE  |  SCORE: {d:>8}  |  HIGH: {d:>8}  |  SPEED: {d:.1}  ", .{
            score.current,
            score.highscore,
            speed,
        }) catch "NEURODIVE";
        term.writeStr(hud);
        term.resetColor();

        term.moveCursor(2, 1);
        term.setColor(.dim);
        var i: u16 = 0;
        while (i < self.total_cols) : (i += 1) {
            term.writeChar('-');
        }
        term.resetColor();
    }

    fn drawBuildings(self: *const Renderer, term: *Terminal) void {
        const left_start: u16 = @intCast(self.offset_x + 1);
        const right_start: u16 = @intCast(self.offset_x + WALL_WIDTH + self.play_width + 1);

        var row: u16 = 3;
        while (row <= self.total_rows) : (row += 1) {
            term.setColor(.dim);

            term.moveCursor(row, left_start);
            self.drawWallSegment(term, row);

            term.moveCursor(row, right_start);
            self.drawWallSegment(term, row);

            term.resetColor();
        }
    }

    fn drawWallSegment(_: *const Renderer, term: *Terminal, row: u16) void {
        if (row % 4 == 0) {
            term.writeStr("===");
        } else if (row % 2 == 0) {
            term.writeStr("|.|");
        } else {
            term.writeStr("|#|");
        }
    }

    fn drawEntities(self: *const Renderer, term: *Terminal, world: *const World) void {
        var idx: usize = 0;
        while (idx < world.entity_count) : (idx += 1) {
            const e = &world.entities[idx];
            if (!e.active) continue;

            const screen_y = e.y + 3;
            if (screen_y < 3 or screen_y > self.total_rows) continue;

            const screen_x: i16 = e.x + self.offset_x + WALL_WIDTH + 1;
            if (screen_x < 1) continue;

            term.moveCursor(@intCast(screen_y), @intCast(screen_x));

            switch (e.kind) {
                .window => {
                    term.setColor(.bright_red);
                    term.writeStr(e.visual());
                },
                .eye => {
                    term.setColor(.bright_magenta);
                    term.writeStr(e.visual());
                },
                .diamond => {
                    term.setColor(.bright_cyan);
                    term.writeStr(e.visual());
                },
                .chip => {
                    term.setColor(.bright_yellow);
                    term.writeStr(e.visual());
                },
            }
            term.resetColor();
        }
    }

    fn drawPlayer(self: *const Renderer, term: *Terminal, player: *const Player) void {
        const screen_x: i16 = player.x + self.offset_x + WALL_WIDTH + 1;
        const screen_y: i16 = player.y + 3;

        if (screen_y < 3 or screen_y > self.total_rows) return;

        term.moveCursor(@intCast(screen_y), @intCast(screen_x));
        term.setColor(.bright_green);
        term.writeChar(PLAYER_CHAR);
        term.resetColor();
    }

    fn clearBelow(self: *const Renderer, term: *Terminal) void {
        term.moveCursor(self.total_rows, self.total_cols);
    }

    pub fn drawTitleScreen(self: *const Renderer, term: *Terminal, cols: u16, rows: u16, highscore: u32) void {
        term.clearScreen();

        self.drawBuildings(term);

        const title = [_][]const u8{
            " _   _  _____  _   _  ____    ___   ____   ___ __     __ _____",
            "| \\ | || ____|| | | ||  _ \\  / _ \\ |  _ \\ |_ _|\\ \\   / /| ____|",
            "|  \\| ||  _|  | | | || |_) || | | || | | | | |  \\ \\ / / |  _|",
            "| |\\  || |___ | |_| ||  _ < | |_| || |_| | | |   \\ V /  | |___",
            "|_| \\_||_____| \\___/ |_| \\_\\ \\___/ |____/ |___|   \\_/   |_____|",
        };

        const title_width: u16 = 65;
        const center = cols / 2;
        const start_row = if (rows > 20) rows / 3 else 2;

        term.setColor(.bright_cyan);
        for (title, 0..) |line, i| {
            term.moveCursor(start_row + @as(u16, @intCast(i)), center -| (title_width / 2));
            term.writeStr(line);
        }

        term.setColor(.dim);
        const sub = "< a neural descent into the void >";
        term.moveCursor(start_row + 6, center -| @as(u16, sub.len / 2));
        term.writeStr(sub);

        term.setColor(.bright_white);
        const prompt = "[ PRESS ENTER TO DIVE ]";
        term.moveCursor(start_row + 9, center -| @as(u16, prompt.len / 2));
        term.writeStr(prompt);

        term.setColor(.dim);
        const controls = "\xe2\x86\x90 \xe2\x86\x92  move  |  Q  quit";
        const controls_display_width: u16 = 21;
        term.moveCursor(start_row + 11, center -| (controls_display_width / 2));
        term.writeStr(controls);

        if (highscore > 0) {
            term.setColor(.bright_yellow);
            var buf: [64]u8 = undefined;
            const hs = std.fmt.bufPrint(&buf, "HIGHSCORE: {d}", .{highscore}) catch "HIGHSCORE: ---";
            term.moveCursor(start_row + 13, center -| @as(u16, @intCast(hs.len / 2)));
            term.writeStr(hs);
        }

        term.resetColor();
        term.flush();
    }

    pub fn drawGameOver(_: *const Renderer, term: *Terminal, cols: u16, rows: u16, final_score: u32, highscore: u32, is_new_high: bool) void {
        term.clearScreen();

        const start_row = if (rows > 16) rows / 3 else 2;

        term.setColor(.bright_red);
        const go = "NEURAL LINK SEVERED";
        const go_col = if (cols > go.len) (cols - go.len) / 2 else 1;
        term.moveCursor(start_row, @intCast(go_col));
        term.writeStr(go);

        term.setColor(.bright_white);
        var buf: [64]u8 = undefined;
        const sc = std.fmt.bufPrint(&buf, "FINAL SCORE: {d}", .{final_score}) catch "SCORE: ---";
        const sc_col = if (cols > sc.len) (cols - sc.len) / 2 else 1;
        term.moveCursor(start_row + 2, @intCast(sc_col));
        term.writeStr(sc);

        if (is_new_high) {
            term.setColor(.bright_yellow);
            const nh = "*** NEW HIGHSCORE! ***";
            const nh_col = if (cols > nh.len) (cols - nh.len) / 2 else 1;
            term.moveCursor(start_row + 4, @intCast(nh_col));
            term.writeStr(nh);
        } else {
            term.setColor(.dim);
            const hs = std.fmt.bufPrint(&buf, "HIGHSCORE: {d}", .{highscore}) catch "HIGHSCORE: ---";
            const hs_col = if (cols > hs.len) (cols - hs.len) / 2 else 1;
            term.moveCursor(start_row + 4, @intCast(hs_col));
            term.writeStr(hs);
        }

        term.setColor(.bright_white);
        const prompt = "[ ENTER: RETRY  |  Q: QUIT ]";
        const p_col = if (cols > prompt.len) (cols - prompt.len) / 2 else 1;
        term.moveCursor(start_row + 7, @intCast(p_col));
        term.writeStr(prompt);

        term.resetColor();
        term.flush();
    }
};
