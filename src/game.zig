const terminal = @import("terminal.zig");
const Terminal = terminal.Terminal;
const Key = terminal.Key;
const Player = @import("player.zig").Player;
const World = @import("world.zig").World;
const CollisionResult = @import("world.zig").CollisionResult;
const Score = @import("score.zig").Score;
const Renderer = @import("renderer.zig").Renderer;

pub const Screen = enum {
    title,
    playing,
    game_over,
};

pub const GameState = struct {
    screen: Screen,
    player: Player,
    world: World,
    score: Score,
    renderer: Renderer,
    is_new_highscore: bool,

    pub fn init(cols: u16, rows: u16) GameState {
        const renderer = Renderer.init(cols, rows);
        return .{
            .screen = .title,
            .player = Player.init(renderer.play_width, renderer.play_height),
            .world = World.init(renderer.play_width, renderer.play_height),
            .score = Score.init(),
            .renderer = renderer,
            .is_new_highscore = false,
        };
    }

    pub fn update(self: *GameState, key: Key, delta: f32) bool {
        return switch (self.screen) {
            .title => self.updateTitle(key),
            .playing => self.updatePlaying(key, delta),
            .game_over => self.updateGameOver(key),
        };
    }

    pub fn draw(self: *GameState, term: *Terminal) void {
        switch (self.screen) {
            .title => self.renderer.drawTitleScreen(term, self.renderer.total_cols, self.renderer.total_rows, self.score.highscore),
            .playing => self.renderer.drawGame(term, &self.player, &self.world, &self.score),
            .game_over => self.renderer.drawGameOver(term, self.renderer.total_cols, self.renderer.total_rows, self.score.current, self.score.highscore, self.is_new_highscore),
        }
    }

    fn updateTitle(self: *GameState, key: Key) bool {
        switch (key) {
            .enter => {
                self.screen = .playing;
                self.resetGame();
            },
            .quit => return false,
            else => {},
        }
        return true;
    }

    fn updatePlaying(self: *GameState, key: Key, delta: f32) bool {
        if (key == .quit) return false;

        self.player.move(key, 1, self.renderer.play_width - 1);
        self.world.update(delta);
        self.score.addSurvival(delta, self.world.speed);

        const collision = self.world.checkCollision(&self.player);
        switch (collision) {
            .hit_obstacle => {
                self.is_new_highscore = self.score.current > self.score.highscore;
                self.score.save();
                self.screen = .game_over;
            },
            .collected_diamond => self.score.addPoints(50),
            .collected_chip => self.score.addPoints(25),
            .none => {},
        }

        return true;
    }

    fn updateGameOver(self: *GameState, key: Key) bool {
        switch (key) {
            .quit => return false,
            .restart, .enter => {
                self.resetGame();
                self.screen = .playing;
            },
            else => {},
        }
        return true;
    }

    fn resetGame(self: *GameState) void {
        self.player = Player.init(self.renderer.play_width, self.renderer.play_height);
        self.world = World.init(self.renderer.play_width, self.renderer.play_height);
        self.score.reset();
        self.is_new_highscore = false;
    }
};
