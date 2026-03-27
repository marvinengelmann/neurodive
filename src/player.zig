const terminal = @import("terminal.zig");

pub const PLAYER_CHAR = '@';
pub const PLAYER_WIDTH: i16 = 1;

pub const Player = struct {
    x: i16,
    y: i16,

    pub fn init(play_width: i16, play_height: i16) Player {
        return .{
            .x = @divFloor(play_width, 2),
            .y = @divFloor(play_height, 4),
        };
    }

    pub fn move(self: *Player, key: terminal.Key, left_bound: i16, right_bound: i16) void {
        switch (key) {
            .left => {
                if (self.x > left_bound) self.x -= 1;
            },
            .right => {
                if (self.x < right_bound - PLAYER_WIDTH) self.x += 1;
            },
            else => {},
        }
    }

    pub fn collidesWidth(self: *const Player, ex: i16, ey: i16, ew: i16, eh: i16) bool {
        const px = self.x;
        const py = self.y;
        return px < ex + ew and px + PLAYER_WIDTH > ex and py < ey + eh and py + 1 > ey;
    }
};
