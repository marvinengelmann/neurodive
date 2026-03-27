const std = @import("std");
const Terminal = @import("terminal.zig").Terminal;
const GameState = @import("game.zig").GameState;

const TARGET_FPS = 30;
const FRAME_TIME_NS: u64 = std.time.ns_per_s / TARGET_FPS;

pub fn main() !void {
    var term = try Terminal.init();
    defer term.deinit();

    const size = Terminal.getSize();
    var state = GameState.init(size.cols, size.rows);

    var timer = try std.time.Timer.start();

    while (true) {
        const delta_ns = timer.lap();
        const delta: f32 = @as(f32, @floatFromInt(delta_ns)) / @as(f32, @floatFromInt(std.time.ns_per_s));

        const key = term.readKey();

        if (!state.update(key, delta)) break;

        state.draw(&term);

        const elapsed = timer.read();
        if (elapsed < FRAME_TIME_NS) {
            std.Thread.sleep(FRAME_TIME_NS - elapsed);
        }
    }
}
